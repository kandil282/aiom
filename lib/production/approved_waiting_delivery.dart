import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountantApprovalPageproduction extends StatelessWidget {
  const AccountantApprovalPageproduction({super.key});

  Future<void> _processApproval(BuildContext context, String docId) async {
    // 1. إظهار لودنج
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final accountantName = userDoc.data()?['username'] ?? "محاسب";

      await FirebaseFirestore.instance.collection('material_requests').doc(docId).update({
        'status': 'approved_waiting_delivery',
        'approvedBy': accountantName,
        'accountantApprovalAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) Navigator.pop(context); // إغلاق اللودنج
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    return Scaffold(
      appBar: AppBar(title: const Text("اعتمادات الحسابات"), backgroundColor: Colors.indigo),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('material_requests').where('status', isEqualTo: 'pending_approval').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة"));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("طلب من: ${data['requestedBy']}"),
                  subtitle: Text("تاريخ: ${data['requestedAt']?.toDate().toString().split('.')[0] ?? ''}"),
                  trailing: ElevatedButton(
                    onPressed: () => _processApproval(context, docs[index].id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("اعتماد مالي", style: TextStyle(color: Colors.white)),
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