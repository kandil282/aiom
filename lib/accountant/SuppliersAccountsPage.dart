import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// استيراد صفحة كشف الحساب التي عملناها
import 'supplier_statement_page.dart'; 

class SuppliersDashboard extends StatelessWidget {
  const SuppliersDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الموردين والمشتريات"),
        backgroundColor: const Color(0xff134e4a),
      ),
      body: Column(
        children: [
          // 1. ملخص سريع لإجمالي المديونيات
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              double totalDebt = 0;
              for (var doc in snap.data!.docs) {
                totalDebt += (doc['balance'] ?? 0);
              }
              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("إجمالي مديونية الموردين:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("$totalDebt ج.م", style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),

          // 2. قائمة الموردين
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.builder(
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (context, i) {
                    var doc = snap.data!.docs[i];
                    var data = doc.data() as Map<String, dynamic>;
                    double balance = (data['balance'] ?? 0).toDouble();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xff134e4a), child: Icon(Icons.business, color: Colors.white)),
                        title: Text(data['name'] ?? "مورد بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("رقم الهاتف: ${data['phone'] ?? 'غير مسجل'}"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("الرصيد", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text("$balance ج.م", style: TextStyle(
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold
                            )),
                          ],
                        ),
                        onTap: () {
                          // الانتقال لكشف حساب المورد
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SupplierStatementPage(
                                supplierId: doc.id,
                                supplierName: data['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // زر سريع لإضافة مورد جديد
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff134e4a),
        child: const Icon(Icons.add_business, color: Colors.white),
        onPressed: () {
          // هنا نفتح صفحة إضافة مورد التي برمجناها سابقاً
          // Navigator.push(context, MaterialPageRoute(builder: (context) => AddSupplierPage()));
        },
      ),
    );
  }
}