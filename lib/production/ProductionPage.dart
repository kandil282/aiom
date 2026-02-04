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
  if (pId.isEmpty) { _showError("خطأ: معرف المنتج مفقود"); return; }

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
    _showSuccess("تم التوريد وتحديث جميع الأرصدة بنجاح ✅");
  } catch (e) {
    _showError("حدث خطأ أثناء التوريد: $e");
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
 
//  Future<void> _notifyAgent(Map<String, dynamic> data, String docId) async {
//   try {
//     // في كوليكشن الإنتاج، الحقول تسمى agentId و productName
//     String? agentId = data['agentId'];
//     String pName = data['productName'] ?? 'منتج';
    
//     if (agentId != null && agentId.isNotEmpty) {
//       await sendInternalNotification(
//         receiverId: agentId,
//         title: 'تحديث إنتاج وفاتورة 🧾',
//         body: 'تم تجهيز $pName وإصدار الفاتورة الخاصة بها بنجاح.',
//         // يمكنك إضافة orderId إذا كنت قمت بتخزينه في طلب الإنتاج
//       );
//       print("تم إرسال الإشعار للمندوب");
//     }
//   } catch (e) {
//     print("خطأ في الإشعار: $e");
//   }
// }

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
    String selectedWhName = data['warehouseName'] ?? "المخزن الرئيسي";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("تأكيد توريد: ${data['productName'] ?? 'منتج'}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: "الكمية الفعلية المنتجة", prefixIcon: Icon(Icons.numbers)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('storage_locations').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    initialValue: selectedWhId,
                    decoration: const InputDecoration(labelText: "إيداع في مخزن...", prefixIcon: Icon(Icons.warehouse)),
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
              child: const Text("تأكيد وتوريد"),
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
        title: const Text("مراقبة خط الإنتاج", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF334155),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('production_orders')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("خطأ في تحميل البيانات"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // الترتيب اليدوي لتجنب خطأ الـ Index
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            var aT = (a.data() as Map)['requestedAt'] as Timestamp?;
            var bT = (b.data() as Map)['requestedAt'] as Timestamp?;
            return (bT ?? Timestamp.now()).compareTo(aT ?? Timestamp.now());
          });

          if (docs.isEmpty) return const Center(child: Text("لا توجد طلبات تصنيع حالية"));

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
    title: Text(data['productName'] ?? "منتج غير معروف", 
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
              child: Text(data['category'] ?? "تصنيف عام", style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
              child: Text(data['subCategory'] ?? "فرعي", style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text("الكمية المطلوبة: ${data['quantity'] ?? 0}", 
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    ),
    trailing: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
      onPressed: () => _showCompleteDialog(docs[index].id, data),
      child: const Text("تم التنفيذ", style: TextStyle(color: Colors.white)),
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