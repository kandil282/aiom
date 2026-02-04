import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ستحتاجين لإضافة مكتبة intl في pubspec لتنسيق التاريخ

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("كشف حساب العمليات")),
      body: StreamBuilder<QuerySnapshot>(
        // جلب البيانات مرتبة حسب التاريخ (الأحدث أولاً)
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              bool isIncome = doc['type'] == 'income'; // التأكد من النوع

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  // أيقونة خضراء للداخل وحمراء للخارج
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
title: Text(doc.data().toString().contains('partnerName') ? doc['partnerName'] : "بدون اسم"),

                  subtitle: Text(doc['description'] ?? ""),
                  // عرض المبلغ وتلوينه
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isIncome ? '+' : '-'}${doc['amount']} ج.م",
                        style: TextStyle(
                          color: isIncome ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      // عرض التاريخ بشكل مبسط
                      Text(
                        doc['date'] != null 
                            ? DateFormat('yyyy-MM-dd').format(doc['date'].toDate())
                            : "",
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
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
