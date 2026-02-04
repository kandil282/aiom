// ... (الإستيرادات كما هي)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WarehouseDispatchPage extends StatelessWidget {
  const WarehouseDispatchPage({super.key});






  // دالة الصرف (نفس المنطق السابق مع التأكد من أسماء الحقول)
Future<void> _processDispatch(BuildContext context, String docId, List items) async {
  DocumentReference requestRef = FirebaseFirestore.instance.collection('material_requests').doc(docId);
  // 1. تخزين الـ Navigator قبل أي عمليات انتظار لضمان الوصول إليه لاحقاً
  final navigator = Navigator.of(context, rootNavigator: true);
  final scaffoldMessenger = ScaffoldMessenger.of(context);
// أضف هذا الجزء داخل دالة _processDispatch قبل الـ batch.commit
final uid = FirebaseAuth.instance.currentUser?.uid;
// جلب بيانات الموظف من كوليكشن المستخدمين
final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
final dispatcherName = userDoc.data()?['username'] ?? "أمين المخزن"; // اسم الموظف
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (c) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();

    for (var item in items) {
      String mId = item['materialId'] ?? '';
      double requestedQty = double.tryParse(item['qty'].toString()) ?? 0.0;

      if (mId.isNotEmpty) {
        // فحص الرصيد لمنع السالب
        DocumentSnapshot matSnapshot = await firestore.collection('raw_materials').doc(mId).get();
        
        if (!matSnapshot.exists) throw "الخامة ${item['materialName']} غير موجودة!";

        double currentStock = double.tryParse(matSnapshot.get('stock').toString()) ?? 0.0;

        if (currentStock < requestedQty) {
          throw "الرصيد غير كافٍ لـ: ${item['materialName']}\nالمتاح: $currentStock";
        }

        // إضافة الخصم للـ Batch
        batch.update(matSnapshot.reference, {
          'stock': FieldValue.increment(-requestedQty),
          'quantity': FieldValue.increment(-requestedQty),
        });
      }
    }

    // تحديث حالة الطلب
batch.update(requestRef, {
  'status': 'issued',
  'dispatchedBy': dispatcherName, // هنا يتم حفظ الاسم لكي يظهر في الأرشيف
  'dispatchedAt': FieldValue.serverTimestamp(),
    });

    // تنفيذ العملية
    await batch.commit();

    // 2. الحل السحري: إغلاق اللودنج باستخدام المتغير المحفوظ navigator
    if (navigator.canPop()) {
      navigator.pop(); 
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text("تم الصرف بنجاح ✅"), backgroundColor: Colors.green)
    );

  } catch (e) {
    // إغلاق اللودنج في حالة الخطأ أيضاً
    if (navigator.canPop()) {
      navigator.pop();
    }
    _showErrorDialog(context, e.toString());
  }
}


Future<void> _deleteRequest(BuildContext context, String docId) async {
  bool confirm = await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("حذف الطلب"),
      content: const Text("هل أنت متأكد من حذف هذا الطلب نهائياً؟ لن يتم خصم أي خامات."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true), 
          child: const Text("حذف", style: TextStyle(color: Colors.red))
        ),
      ],
    ),
  ) ?? false;

  if (confirm) {
    await FirebaseFirestore.instance.collection('material_requests').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الطلب بنجاح")));
  }
}
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("تنبيه"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("أذونات صرف الخامات"),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // التعديل الجوهري هنا:
        // تأكد أن الحالة مكتوبة بالضبط "waiting_warehouse" كما في الصورة
        stream: FirebaseFirestore.instance
            .collection('material_requests')
            .where('status', isEqualTo: 'waiting_warehouse')
            // ملاحظة: قمنا بإزالة orderBy مؤقتاً لتجنب مشكلة الـ Index
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("خطأ في جلب البيانات: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // إذا لم تكن هناك بيانات في الفلتر الحالي
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all, size: 80, color: Colors.teal[200]),
                  const SizedBox(height: 10),
                  const Text("كل الطلبات تم صرفها", style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              List items = data['items'] ?? [];

return Card(
  elevation: 3,
  margin: const EdgeInsets.only(bottom: 12),
  child: ExpansionTile(
    leading: const Icon(Icons.pending_actions, color: Colors.orange),
    title: Text("طلب: ${data['requestedBy'] ?? 'إنتاج'}"),
    subtitle: Text("المخزن: ${data['warehouseName'] ?? 'عام'}"),
    
    // --- إضافة زرار الحذف هنا ---
    trailing: IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
      onPressed: () => _deleteRequest(context, doc.id),
    ),

    children: [
      const Divider(),
      ...items.map((it) => ListTile(
        title: Text(it['materialName'] ?? 'خامة'),
        trailing: Text("الكمية: ${it['qty']}"),
      )),
      Padding(
        padding: const EdgeInsets.all(15),
        child: ElevatedButton.icon(
          onPressed: () => _processDispatch(context, doc.id, items),
          icon: const Icon(Icons.check_circle),
          label: const Text("تأكيد خروج الأصناف"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            minimumSize: const Size(double.infinity, 45)
          ),
        ),
      )
    ],
  ),
);
            
            
            },
          );
        },
      ),
    );
  }
}