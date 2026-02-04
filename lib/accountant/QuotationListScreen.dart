import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuotationListScreen extends StatelessWidget {
  const QuotationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("قائمة بيانات الأسعار")),
      body: StreamBuilder<QuerySnapshot>(
        // نراقب مجموعة quotations الجديدة
        stream: FirebaseFirestore.instance
            .collection('quotations')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var quotation = snapshot.data!.docs[index];
              var status = quotation['status'] ?? 'pending';
              Color statusColor = Colors.orange; // Default color for pending

              if (status == 'accepted') statusColor = Colors.green;
              if (status == 'rejected') statusColor = Colors.red;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(Icons.description, color: statusColor),
                  title: Text("بيان سعر لـ: ${quotation['partnerName'] ?? 'عميل عام'}"),
                  subtitle: Text("الإجمالي: ${quotation['finalTotal']} ج.م"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    // هنا يمكنك فتح شاشة عرض بيان السعر الكامل (مثل الفاتورة الضريبية لكن بدون ضريبة)
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
