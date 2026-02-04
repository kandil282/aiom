import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateQuotationScreen extends StatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  String? _selectedPartner;
  String? _selectedWarehouseId;
  String? _selectedProductId;
  Map<String, dynamic>? _tempProductData;
  final List<Map<String, dynamic>> _items = [];
  double _total = 0;

  final _qtyController = TextEditingController(text: "1");
  final _priceController = TextEditingController();

  void _calculateTotal() {
    setState(() {
      _total = _items.fold(0, (sum, item) => sum + item['total']);
    });
  }

  void _addItem() {
    if (_tempProductData == null || _selectedProductId == null) return;
    double qty = double.tryParse(_qtyController.text) ?? 1.0;
    double price = double.tryParse(_priceController.text) ?? 0.0;

    setState(() {
      _items.add({
        'productId': _selectedProductId,
        'name': _tempProductData!['name'] ?? 'منتج بدون اسم',
        'category': _tempProductData!['category'] ?? 'عام',
        'qty': qty,
        'price': price,
        'total': qty * price,
      });
      _calculateTotal();
    });
    
    // تصغير الاختيارات بعد الإضافة
    _selectedProductId = null;
    _tempProductData = null;
    _priceController.clear();
    _qtyController.text = "1";
  }

  Future<void> _processInvoice() async {
    if (_selectedPartner == null || _selectedWarehouseId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إكمال كافة البيانات")));
      return;
    }

    try {
      bool isStockAvailable = true;
      List<String> missingItems = [];

      // التحقق من المخزون
      for (var item in _items) {
        var stockSnapshot = await FirebaseFirestore.instance
            .collection('warehouses')
            .doc(_selectedWarehouseId)
            .collection('stock')
            .doc(item['productId'])
            .get();

        double currentQty = 0;
        if (stockSnapshot.exists) {
          currentQty = (stockSnapshot.data()?['quantity'] ?? 0).toDouble();
        }

        if (currentQty < item['qty']) {
          isStockAvailable = false;
          missingItems.add(item['name']);
        }
      }

      String finalStatus = isStockAvailable ? 'completed' : 'on_hold';

      // حفظ الفاتورة
      await FirebaseFirestore.instance.collection('quotations').add({
        'partnerName': _selectedPartner,
        'warehouseId': _selectedWarehouseId,
        'items': _items,
        'finalTotal': _total,
        'date': FieldValue.serverTimestamp(),
        'status': finalStatus,
      });

      if (isStockAvailable) {
        // خصم المخزن
        for (var item in _items) {
          await FirebaseFirestore.instance
              .collection('warehouses')
              .doc(_selectedWarehouseId)
              .collection('stock')
              .doc(item['productId'])
              .update({'quantity': FieldValue.increment(-item['qty'])});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحفظ وخصم الكميات بنجاح")));
      } else {
        // إنشاء تنبيه للمحاسب (أمر عمل)
        await FirebaseFirestore.instance.collection('work_orders').add({
          'client': _selectedPartner,
          'items': missingItems,
          'status': 'pending_production',
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المخزن غير كافٍ.. تم تحويلها لفاتورة معلقة")));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ برمجى: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال فاتورة ذكية 2026")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. اختيار العميل
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('partners').where('type', isEqualTo: 'customer').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "اختر العميل", border: OutlineInputBorder()),
                  items: snap.data!.docs.map((d) => DropdownMenuItem(value: d['name'] as String, child: Text(d['name']))).toList(),
                  onChanged: (v) => setState(() => _selectedPartner = v),
                );
              },
            ),
            const SizedBox(height: 10),

            // 2. اختيار المخزن (تمت معالجة خطأ الحقل المفقود هنا)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('warehouses').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "اختر المخزن", border: OutlineInputBorder()),
                  items: snap.data!.docs.map((d) {
                    Map<String, dynamic> data = d.data() as Map<String, dynamic>;
                    // حماية فى حالة عدم وجود اسم للمخزن
                    String name = data.containsKey('name') ? data['name'] : "مخزن غير مسمى (${d.id.substring(0, 5)})";
                    return DropdownMenuItem(value: d.id, child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                );
              },
            ),
            const Divider(height: 30),

            // 3. اختيار المنتج
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(labelText: "اختر الصنف", border: OutlineInputBorder()),
                  items: snap.data!.docs.map((d) {
                    Map<String, dynamic> data = d.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: d.id, child: Text(data['name'] ?? 'بدون اسم'));
                  }).toList(),
                  onChanged: (v) {
                    var doc = snap.data!.docs.firstWhere((d) => d.id == v);
                    setState(() {
                      _selectedProductId = v;
                      _tempProductData = doc.data() as Map<String, dynamic>;
                      _priceController.text = (_tempProductData!['price'] ?? 0).toString();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _qtyController, decoration: const InputDecoration(labelText: "الكمية", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: "السعر", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                IconButton(onPressed: _addItem, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 40)),
              ],
            ),
            const SizedBox(height: 20),

            // عرض المنتجات المضافة
            Container(
              height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(_items[i]['name']),
                  subtitle: Text("الكمية: ${_items[i]['qty']} x ${_items[i]['price']}"),
                  trailing: Text("${_items[i]['total']} \$"),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text("إجمالي الفاتورة: $_total \$", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _processInvoice,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("حفظ ومعالجة الطلب", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}