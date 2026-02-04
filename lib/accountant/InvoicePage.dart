import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmartInvoicePage extends StatefulWidget {
  const SmartInvoicePage({super.key});

  @override
  State<SmartInvoicePage> createState() => _SmartInvoicePageState();
}

class _SmartInvoicePageState extends State<SmartInvoicePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? selectedCustomerId, selectedCustomerName, selectedCustomerPhone;
  String? selectedCategory, selectedSubCategory, selectedProductId;
  String currentProductName = "";
  int totalAvailableStock = 0;
  double currentProductPrice = 0.0; // متغير جديد لحفظ السعر القادم من الداتابيز

  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController(); // سيتم ملؤه تلقائياً
  
  List<Map<String, dynamic>> itemsList = [];
  bool isSaving = false;

  // جلب المخزون والسعر عند اختيار المنتج
  Future<void> _loadProductData(String pid) async {
    // 1. جلب بيانات المنتج الأساسية (السعر)
    var prodDoc = await _db.collection('products').doc(pid).get();
    if (prodDoc.exists) {
      setState(() {
        // تأكد أن اسم الحقل في الفايربيز هو 'price' أو 'sellingPrice'
        currentProductPrice = (prodDoc.data()?['price'] ?? 0.0).toDouble();
        priceCtrl.text = currentProductPrice.toString(); // وضع السعر في الخانة تلقائياً
      });
    }

    // 2. جلب إجمالي المخزون
    var invSnap = await _db.collection('products').doc(pid).collection('inventory').get();
    int total = 0;
    for (var doc in invSnap.docs) {
      total += (doc.data()['quantity'] ?? 0) as int;
    }
    setState(() {
      totalAvailableStock = total;
    });
  }

  void _addItem() {
    int req = int.tryParse(qtyCtrl.text) ?? 0;
    double price = double.tryParse(priceCtrl.text) ?? 0.0;

    if (req <= 0 || selectedProductId == null) {
      _showMsg("برجاء إدخال بيانات صحيحة", Colors.orange);
      return;
    }

    if (req > totalAvailableStock) {
      _showMsg("الكمية المطلوبة أكبر من المتاح!", Colors.red);
      return;
    }

    setState(() {
      itemsList.add({
        'productId': selectedProductId,
        'productName': currentProductName,
        'qty': req,
        'price': price, // السعر الذي تم جلبه أو تعديله
        'category': selectedCategory,
        'subCategory': selectedSubCategory,
      });
      qtyCtrl.clear();
      priceCtrl.clear();
      selectedProductId = null;
      totalAvailableStock = 0;
    });
  }

  // دالة الحفظ (تظل كما هي في النسخة السابقة مع توزيع المخازن)
  Future<void> _processInvoice() async {
    if (selectedCustomerId == null || itemsList.isEmpty) {
      _showMsg("البيانات ناقصة!", Colors.orange);
      return;
    }

    setState(() => isSaving = true);
    try {
      WriteBatch batch = _db.batch();
      double finalInvoiceTotal = 0;

      for (var item in itemsList) {
        String pId = item['productId'];
        int remainingToDeduct = item['qty'];
        double itemPrice = item['price'];
        double itemTotal = itemPrice * remainingToDeduct;
        finalInvoiceTotal += itemTotal;
        item['totalPrice'] = itemTotal;

        List<Map<String, dynamic>> deductionSources = [];
        var invSnap = await _db.collection('products').doc(pId).collection('inventory').get();

        for (var doc in invSnap.docs) {
          if (remainingToDeduct <= 0) break;
          int stockInWh = (doc.data()['quantity'] ?? 0) as int;
          String whName = doc.data()['warehouseName'] ?? "مخزن";

          if (stockInWh > 0) {
            int taken = (stockInWh >= remainingToDeduct) ? remainingToDeduct : stockInWh;
            batch.update(doc.reference, {'quantity': stockInWh - taken});
            deductionSources.add({'whName': whName, 'qtyTaken': taken});
            remainingToDeduct -= taken;
          }
        }
        item['deductionSources'] = deductionSources;
        batch.update(_db.collection('products').doc(pId), {'totalQuantity': FieldValue.increment(-item['qty'])});
      }

      DocumentReference invDoc = _db.collection('invoices').doc();
      batch.set(invDoc, {
        'customerId': selectedCustomerId,
        'customerName': selectedCustomerName,
        'customerPhone': selectedCustomerPhone,
        'items': itemsList,
        'totalAmount': finalInvoiceTotal,
        'date': FieldValue.serverTimestamp(),
        'shippingStatus': 'ready',
      });
      DocumentReference transDoc = _db
        .collection('customers')
        .doc(selectedCustomerId)
        .collection('transactions')
        .doc();

        batch.set(transDoc, {
      'amount': finalInvoiceTotal,
      'date': FieldValue.serverTimestamp(),
      'type': 'invoice', // نوع المعاملة فاتورة
      'items': itemsList, // تفاصيل الأصناف لكشف الحساب
      'addedByAgent': 'admin', // أو اسم المستخدم الحالي
      // الحقول الإضافية التي ظهرت في صورتك
      'price': itemsList.isNotEmpty ? itemsList[0]['price'] : 0, 
      'productName': itemsList.isNotEmpty ? itemsList[0]['productName'] : '',
    });

    // 4. تحديث رصيد العميل (Balance) بالزيادة
    DocumentReference customerDoc = _db.collection('customers').doc(selectedCustomerId);
    batch.update(customerDoc, {
      'balance': FieldValue.increment(finalInvoiceTotal), // زيادة المديونية
    });





      await batch.commit();
      _showMsg("تمت العملية بنجاح ✅", Colors.green);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg("خطأ: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("فاتورة مبيعات ذكية"), backgroundColor: const Color(0xff692960)),
      body: isSaving 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCustomerSelector(),
                const SizedBox(height: 20),
                _buildCategorySelectors(),
                if (selectedSubCategory != null) _buildProductSelector(),
                if (selectedProductId != null) _buildQtyAndPriceInput(),
                const Divider(height: 40),
                _buildItemsList(),
              ],
            ),
          ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCustomerSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('customers').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: "اختر العميل", border: OutlineInputBorder()),
          items: snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(),
          onChanged: (id) {
            var doc = snap.data!.docs.firstWhere((d) => d.id == id);
            selectedCustomerId = id;
            selectedCustomerName = doc['name'];
            selectedCustomerPhone = doc['phone'];
          },
        );
      },
    );
  }

  Widget _buildCategorySelectors() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('categories').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "التصنيف الرئيسي", border: OutlineInputBorder()),
              items: snap.data!.docs.map((d) => DropdownMenuItem(value: d['name'].toString(), child: Text(d['name']))).toList(),
              onChanged: (val) => setState(() { selectedCategory = val; selectedSubCategory = null; selectedProductId = null; }),
            );
          },
        ),
        const SizedBox(height: 10),
        if (selectedCategory != null)
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('products').where('category', isEqualTo: selectedCategory).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            final subs = snap.data!.docs.map((d) => d['subCategory'].toString()).toSet().toList();
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "التصنيف الفرعي", border: OutlineInputBorder()),
              items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() { selectedSubCategory = val; selectedProductId = null; }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('products')
            .where('category', isEqualTo: selectedCategory)
            .where('subCategory', isEqualTo: selectedSubCategory)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          return DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "اختر المنتج", border: OutlineInputBorder()),
            items: snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['productName']))).toList(),
            onChanged: (id) {
              var doc = snap.data!.docs.firstWhere((d) => d.id == id);
              setState(() {
                selectedProductId = id;
                currentProductName = doc['productName'];
              });
              _loadProductData(selectedProductId!); // جلب السعر والمخزون معاً
            },
          );
        },
      ),
    );
  }

  Widget _buildQtyAndPriceInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("المخزون: $totalAvailableStock قطعة", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Text("السعر الرسمي: $currentProductPrice ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "الكمية", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "سعر البيع", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 5),
              IconButton(onPressed: _addItem, icon: const Icon(Icons.add_circle, color: Colors.green, size: 45)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemsList.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text(itemsList[i]['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("الكمية: ${itemsList[i]['qty']} | السعر: ${itemsList[i]['price']} | الإجمالي: ${itemsList[i]['qty'] * itemsList[i]['price']}"),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => itemsList.removeAt(i))),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    double total = itemsList.fold(0, (sum, item) => sum + (item['qty'] * item['price']));
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("إجمالي الفاتورة:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("$total ج.م", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff692960), minimumSize: const Size(double.infinity, 50)),
            onPressed: isSaving ? null : _processInvoice,
            child: const Text("حفظ واعتماد الشحن", style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}