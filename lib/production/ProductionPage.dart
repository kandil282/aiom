import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({super.key});

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  Null get productName => null;

  // دالة إنهاء الإنتاج وتحديث المخزن وإرسال تنبيه
// استبدل دالة _finalizeProduction بهذا الكود
// استبدل دالة _finalizeProduction في صفحة ProductionDashboard بهذا الكود:

Future<void> _finalizeProduction(String docId, Map<String, dynamic> data, num finalQty, String whId, String whName) async {
  String pId = data['productId']; 
  // حماية ضد البيانات الناقصة
  if (pId.isEmpty) { _showError(Translate.text(context, "خطأ: معرف المنتج مفقود", "Error: Product ID is missing")); return; }

  try {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    DocumentReference productRef = FirebaseFirestore.instance.collection('products').doc(pId);
    DocumentReference invRef = productRef.collection('inventory').doc(whId);
    DocumentReference orderRef = FirebaseFirestore.instance.collection('production_orders').doc(docId);

    // 1. زيادة رصيد المخزن الفرعي (مثلاً: مخزن القاهرة)
    batch.set(invRef, {
      'quantity': FieldValue.increment(finalQty),
      'warehouseName': whName,
      'warehouseId': whId,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. زيادة الإجمالي العام للمنتج (ليظهر للمندوب فوراً)
    batch.update(productRef, {
      'totalQuantity': FieldValue.increment(finalQty),
      'lastProductionDate': FieldValue.serverTimestamp(),
    });

    // 3. إغلاق أمر التصنيع
    batch.update(orderRef, {
      'status': 'completed',
      'actualQuantity': finalQty,
      'completedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    _showSuccess(Translate.text(context, "تم التوريد وتحديث جميع الأرصدة بنجاح ✅", "Production completed and all balances updated successfully ✅"));
  } catch (e) {
    _showError(Translate.text(context, "حدث خطأ أثناء التوريد: $e", "An error occurred during production: $e"));
  }
}
 
 
 void _showSuccess(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text(message),
        ],
      ),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
 

void _showError(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}
  // نافذة تأكيد الكمية واختيار المخزن
  void _showCompleteDialog(String docId, Map<String, dynamic> data) {
    TextEditingController qtyController = TextEditingController(text: (data['quantity'] ?? 0).toString());
    String? selectedWhId = data['warehouseId'];
    String selectedWhName = data['warehouseName'] ?? Translate.text(context, "المخزن الرئيسي", "Main Warehouse");

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(Translate.text(context, "تأكيد توريد: ${data['productName'] ?? 'منتج'}", "Confirm Production: ${data['productName'] ?? 'Product'}")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration:  InputDecoration(labelText: Translate.text(context, "الكمية الفعلية المنتجة", "Actual Produced Quantity"), prefixIcon: Icon(Icons.numbers)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('storage_locations').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    initialValue: selectedWhId,
                    decoration: InputDecoration(labelText: Translate.text(context, "إيداع في مخزن...", "Deposit in Warehouse"), prefixIcon: Icon(Icons.warehouse)),
                    items: snap.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedWhId = val;
                        selectedWhName = snap.data!.docs.firstWhere((d) => d.id == val)['name'];
                      });
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (selectedWhId != null) {
                  _finalizeProduction(docId, data, num.parse(qtyController.text), selectedWhId!, selectedWhName);
                  Navigator.pop(context);
                }
              },
              child: Text(Translate.text(context, "تأكيد وتوريد", "Confirm and Produce")),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(Translate.text(context, "مراقبة خط الإنتاج", "Production Line Monitoring"), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF334155),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('production_orders')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return  Center(child: Text(Translate.text(context, "خطأ في تحميل البيانات", "Error loading data")));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // الترتيب اليدوي لتجنب خطأ الـ Index
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            var aT = (a.data() as Map)['requestedAt'] as Timestamp?;
            var bT = (b.data() as Map)['requestedAt'] as Timestamp?;
            return (bT ?? Timestamp.now()).compareTo(aT ?? Timestamp.now());
          });

          if (docs.isEmpty) return  Center(child: Text(Translate.text(context, "لا توجد طلبات تصنيع حالية", "No pending production orders")));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
// داخل itemBuilder في صفحة ProductionDashboard
return Card(
  elevation: 3,
  margin: const EdgeInsets.only(bottom: 15),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  child: ListTile(
    contentPadding: const EdgeInsets.all(15),
    title: Text(Translate.text(context, data['productName'] ?? "منتج غير معروف", "Unknown Product"), 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        // عرض التصنيف الرئيسي والفرعي هنا
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(5)),
              child: Text(Translate.text(context, data['category'] ?? "تصنيف عام", "General Category"), style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
              child: Text(Translate.text(context, data['subCategory'] ?? "فرعي", "Sub Category"), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(Translate.text(context, "الكمية المطلوبة: ${data['quantity'] ?? 0}", "Required Quantity: ${data['quantity'] ?? 0}"), 
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    ),
    trailing: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
      onPressed: () => _showCompleteDialog(docs[index].id, data),
      child: Text(Translate.text(context, "تم التنفيذ", "Completed"), style: const TextStyle(color: Colors.white)),
    ),
  ),
);
            
            },
          );
        },
      ),
    );
  }
}