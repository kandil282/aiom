import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'PartnerDetailsPage.dart'; // استيراد صفحة التفاصيل

class PartnersListPage extends StatelessWidget {
  const PartnersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("قائمة العملاء"),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('partners')
            .where('type', isEqualTo: 'customer')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['name'] ?? ""),
                  subtitle: Text("الرصيد: ${data['balance'] ?? 0} ج.م"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // الانتقال لصفحة التفاصيل وتمرير البيانات والـ ID
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => PartnerDetailsPage(partnerData: data, partnerId: doc.id)
                      )
                    );
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