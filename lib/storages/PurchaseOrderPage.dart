import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseInvoicePage extends StatefulWidget {
  const PurchaseInvoicePage({super.key});

  @override
  State<PurchaseInvoicePage> createState() => _PurchaseInvoicePageState();
}

class _PurchaseInvoicePageState extends State<PurchaseInvoicePage> {
  String? selectedSupplierId;
  String? selectedSupplierName;
  List<Map<String, dynamic>> invoiceItems = [];
  double totalInvoiceAmount = 0.0;
  bool _isSaving = false;

  // دالة لإضافة صنف للفاتورة (تظهر في Dialog)
void _addItemDialog() {
  String? prodId;
  String? prodName;
  final customNameCtrl = TextEditingController(); // لإدخال اسم جديد يدوياً
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title:  Text(Translate.text(context, "إضافة خامة / مادة أولية", "Add Raw Material / Component")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. اختيار من الخامات الموجودة مسبقاً
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('raw_materials').snapshots(),
                builder: (context, snap) {
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: Translate.text(context, "اختر خامة موجودة", "Select Existing Raw Material")),
                    items: snap.hasData 
                      ? snap.data!.docs.map((doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['materialName']),
                        )).toList()
                      : [],
                    onChanged: (val) {
                      setDialogState(() {
                        prodId = val;
                        prodName = snap.data!.docs.firstWhere((d) => d.id == val)['materialName'];
                        customNameCtrl.clear(); // مسح النص اليدوي لو اختار من القائمة
                      });
                    },
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("أو"),
              ),
              // 2. كتابة اسم خامة جديدة يدوياً
              TextField(
                controller: customNameCtrl,
                decoration: InputDecoration(
                  labelText: Translate.text(context, "اكتب اسم خامة جديدة", "Write New Raw Material Name"),
                  border: OutlineInputBorder(),
                  hintText: Translate.text(context, "مثلاً: خشب زان، قماش مخمل...", "E.g.: Zan Wood, Wool Fabric...")
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    setDialogState(() {
                      prodId = null; // نلغي الاختيار من القائمة
                      prodName = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: qtyCtrl, decoration: InputDecoration(labelText: Translate.text(context, "الكمية", "Quantity")), keyboardType: TextInputType.number),
              TextField(controller: priceCtrl, decoration: InputDecoration(labelText: Translate.text(context, "سعر الشراء", "Purchase Price")), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(Translate.text(context, "إلغاء", "Cancel"))),
          ElevatedButton(
            onPressed: () {
              if (prodName != null && qtyCtrl.text.isNotEmpty) {
                double subTotal = double.parse(qtyCtrl.text) * double.parse(priceCtrl.text);
                setState(() {
                  invoiceItems.add({
                    'materialId': prodId, // سيكون null لو كانت مادة جديدة
                    'materialName': prodName,
                    'qty': double.parse(qtyCtrl.text),
                    'buyPrice': double.parse(priceCtrl.text),
                    'subTotal': subTotal,
                  });
                  totalInvoiceAmount += subTotal;
                });
                Navigator.pop(context);
              }
            },
            child: Text(Translate.text(context, "إضافة للجدول", "Add to Table")),
          ),
        ],
      ),
    ),
  );
}
  // دالة حفظ الفاتورة النهائية
  Future<void> _saveInvoice() async {
    if (selectedSupplierId == null || invoiceItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. تسجيل الفاتورة في كوليكشن purchases
      DocumentReference invRef = FirebaseFirestore.instance.collection('purchases').doc();
      batch.set(invRef, {
        'supplierId': selectedSupplierId,
        'supplierName': selectedSupplierName,
        'items': invoiceItems,
        'totalAmount': totalInvoiceAmount,
        'date': FieldValue.serverTimestamp(),
      });

      // 2. تحديث المخزن (Inventory) لكل منتج في الفاتورة
  // داخل دالة _saveInvoice
// الجزء المسؤول عن تحديث الخامات داخل دالة الحفظ
for (var item in invoiceItems) {
  if (item['materialId'] != null && item['materialId'].toString().isNotEmpty) {
    // تحديث خامة موجودة (استخدام .toString() للتأكد من النوع)
    DocumentReference matRef = FirebaseFirestore.instance
        .collection('raw_materials')
        .doc(item['materialId'].toString()); // تأمين النوع هنا
    batch.update(matRef, {'stock': FieldValue.increment(item['qty'])});
  } else {
    // إنشاء خامة جديدة لأن المعرف null (المستخدم كتب اسماً جديداً)
    DocumentReference newMatRef = FirebaseFirestore.instance.collection('raw_materials').doc();
    batch.set(newMatRef, {
      'materialName': item['materialName'] ?? Translate.text(context, "خامة بدون إسم", "Raw Material Without Name"), // تأمين ضد الـ null
      'stock': item['qty'] ?? 0,
      'unitPrice': item['buyPrice'] ?? 0,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }
}
      
      // 3. تحديث مديونية المورد (زيادة الرصيد المديون به له)
      DocumentReference supRef = FirebaseFirestore.instance.collection('suppliers').doc(selectedSupplierId);
      batch.update(supRef, {'balance': FieldValue.increment(totalInvoiceAmount)});

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "تم تسجيل المشتريات وتحديث المخزن ✅", "Purchase order registered and inventory updated ✅"))));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text(Translate.text(context,"فاتورة مشتريات جديدة","new purchase order") ), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // اختيار المورد
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration:  InputDecoration(labelText: Translate.text(context, "اختر المورد", "Select Supplier"), border: OutlineInputBorder()),
                  items: snap.data!.docs.map((doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name']),
                  )).toList(),
                  onChanged: (val) {
                    selectedSupplierId = val;
                    selectedSupplierName = snap.data!.docs.firstWhere((d) => d.id == val)['name'];
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _addItemDialog, icon: const Icon(Icons.add), label:  Text(Translate.text(context, "إضافة صنف للفاتورة", "Add Item to Invoice"))),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: invoiceItems.length,
                itemBuilder: (context, i) => // داخل itemBuilder في ListView
                      ListTile(
                        title: Text(invoiceItems[i]['productName'] ?? invoiceItems[i]['materialName'] ?? Translate.text(context, "صنف غير معروف", "Unknown Item")),
                        subtitle: Text("الكمية: ${invoiceItems[i]['qty'] ?? 0}"),
                        trailing: Text("${invoiceItems[i]['subTotal'] ?? 0} ج.م"),
                      )
              ),
            ),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(Translate.text(context, "إجمالي الفاتورة:", 'Total'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(Translate.text(context, "$totalInvoiceAmount ج.م", "$totalInvoiceAmount EGP"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _isSaving 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
                  child:  Text(Translate.text(context,"حفظ الفاتورة وتحديث المخازن","Save invoice"), style: TextStyle(color: Colors.white)),
                ),
          ],
        ),
      ),
    );
  }
}