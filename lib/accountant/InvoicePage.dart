import 'package:aiom/configer/settingPage.dart';
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
      _showMsg(Translate.text(context, "برجاء إدخال بيانات صحيحة", "Please enter correct data"), Colors.orange);
      return;
    }

    if (req > totalAvailableStock) {
      _showMsg(Translate.text(context, "الكمية المطلوبة أكبر من المتاح!", "Requested quantity exceeds available stock!"), Colors.red);
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
    _showMsg(Translate.text(context, "البيانات ناقصة!", "Missing Data!"), Colors.orange);
    return;
  }

  setState(() => isSaving = true);
  try {
    // 🔥 خطوة إضافية: جلب بيانات المندوب المسؤول عن العميل
    var customerSnap = await _db.collection('customers').doc(selectedCustomerId).get();
    var customerData = customerSnap.data() as Map<String, dynamic>;

    // سحب الـ ID والاسم (لو مش موجودين بيحط قيمة احتياطية)
    String ownerAgentId = customerData['agentId'] ?? 'ADMIN_OFFICE';
    String ownerAgentName = customerData['addedByAgent'] ?? Translate.text(context, "إدارة المكتب", "Office Management");

    WriteBatch batch = _db.batch();
    double finalInvoiceTotal = 0;

    // 1. معالجة الأصناف وتجهيز البيانات
    for (var item in itemsList) {
      String pId = item['productId'];
      int remainingToDeduct = item['qty'];
      double itemPrice = item['price'];
      double itemTotal = itemPrice * remainingToDeduct;
      finalInvoiceTotal += itemTotal;
      item['totalPrice'] = itemTotal;

      // منطق خصم المخازن
      var invSnap = await _db.collection('products').doc(pId).collection('inventory').get();
      for (var doc in invSnap.docs) {
        if (remainingToDeduct <= 0) break;
        int stockInWh = (doc.data()['quantity'] ?? 0) as int;
        if (stockInWh > 0) {
          int taken = (stockInWh >= remainingToDeduct) ? remainingToDeduct : stockInWh;
          batch.update(doc.reference, {'quantity': stockInWh - taken});
          remainingToDeduct -= taken;
        }
      }
      batch.update(_db.collection('products').doc(pId), {'totalQuantity': FieldValue.increment(-item['qty'])});
    }

    // 2. إنشاء مستند الفاتورة (لأغراض الشحن والطباعة)
    DocumentReference invDoc = _db.collection('invoices').doc();
    batch.set(invDoc, {
      'invoiceId': invDoc.id,
      'customerId': selectedCustomerId,
      'customerName': selectedCustomerName,
      'customerPhone': selectedCustomerPhone,
      'items': itemsList,
      'totalAmount': finalInvoiceTotal,
      'date': FieldValue.serverTimestamp(),
      'shippingStatus': 'ready',
      'source': 'direct_office',
      'agentId': ownerAgentId, // ربط الفاتورة بالمندوب
    });

    // 3. الكوليكشن الجديد الموحد (المصدر الوحيد للتقارير)
    DocumentReference globalTransDoc = _db.collection('global_transactions').doc();
    batch.set(globalTransDoc, {
      'transactionId': globalTransDoc.id,
      'type': 'invoice',
      'source': 'office',
      'amount': finalInvoiceTotal,
      'date': FieldValue.serverTimestamp(),
      'customerId': selectedCustomerId,
      'customerName': selectedCustomerName,
      // ✅ تم التعديل هنا ليأخذ مندوب العميل الفعلي
      'agentId': ownerAgentId, 
      'agentName': ownerAgentName,
      'items': itemsList, 
      'invoiceRef': invDoc.id,
    });

    // 4. تحديث سجل العميل التاريخي
    DocumentReference transDoc = _db.collection('customers').doc(selectedCustomerId).collection('transactions').doc();
    batch.set(transDoc, {
      'type': 'invoice',
      'amount': finalInvoiceTotal,
      'date': FieldValue.serverTimestamp(),
      'items': itemsList,
      // ✅ تم التعديل هنا أيضاً لتوحيد البيانات
      'addedByAgent': ownerAgentName, 
      'agentId': ownerAgentId,
    });

    // 5. تحديث رصيد مديونية العميل
    DocumentReference customerDocRef = _db.collection('customers').doc(selectedCustomerId);
    batch.update(customerDocRef, {
      'balance': FieldValue.increment(finalInvoiceTotal),
    });

    await batch.commit();
    _showMsg(Translate.text(context, "تم حفظ الفاتورة وتحديث تقارير المندوب ✅", "Invoice saved and agent reports updated ✅"), Colors.green);
    if (mounted) Navigator.pop(context);
  } catch (e) {
    _showMsg(Translate.text(context, "خطأ في النظام: $e", "System Error: $e"), Colors.red);
  } finally {
    if (mounted) setState(() => isSaving = false);
  }
}
  
  
  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translate.text(context, "فاتورة مبيعات ذكية", "Smart Sales Invoice")), backgroundColor: const Color(0xff692960)),
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
          decoration: InputDecoration(labelText: Translate.text(context, "اختر العميل", "Select Customer"), border: OutlineInputBorder()),
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
              decoration: InputDecoration(labelText: Translate.text(context, "التصنيف الرئيسي", "Main Category"), border: OutlineInputBorder()),
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
              decoration: InputDecoration(labelText: Translate.text(context, "التصنيف الفرعي", "Sub Category"), border: OutlineInputBorder()),
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
            decoration: InputDecoration(labelText: Translate.text(context, "اختر المنتج", "Select Product"), border: OutlineInputBorder()),
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
                Text(Translate.text(context, "المخزون: $totalAvailableStock قطعة", "Stock: $totalAvailableStock pieces")  , style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Text(Translate.text(context, "السعر الرسمي: $currentProductPrice ج.م", "Official Price: $currentProductPrice EGP"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: qtyCtrl, decoration: InputDecoration(labelText: Translate.text(context, "الكمية", "Quantity"), border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: priceCtrl, decoration: InputDecoration(labelText: Translate.text(context, "سعر البيع", "Selling Price"), border: OutlineInputBorder()), keyboardType: TextInputType.number)),
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
          subtitle: Text(Translate.text(context, "الكمية: ${itemsList[i]['qty']} | السعر: ${itemsList[i]['price']} | الإجمالي: ${itemsList[i]['qty'] * itemsList[i]['price']}", "Quantity: ${itemsList[i]['qty']} | Price: ${itemsList[i]['price']} | Total: ${itemsList[i]['qty'] * itemsList[i]['price']}")),
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
              Text(Translate.text(context, "إجمالي الفاتورة:", "Total Invoice"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(Translate.text(context, "$total ج.م", "$total EGP"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff692960), minimumSize: const Size(double.infinity, 50)),
            onPressed: isSaving ? null : _processInvoice,
            child: Text(Translate.text(context, "حفظ واعتماد الشحن", "Save and Approve Shipment"), style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}