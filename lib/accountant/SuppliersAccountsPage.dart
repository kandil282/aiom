import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supplier_statement_page.dart';

class SuppliersDashboard extends StatelessWidget {
  const SuppliersDashboard({super.key});

  // 1. هذه الدالة هي المسؤولة عن إظهار نافذة الإضافة
  void _showAddSupplierSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // لجعل النافذة ترتفع عند فتح الكيبورد
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          // هذا الهامش يضمن عدم تغطية الكيبورد للحقول
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("إضافة مورد جديد",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "اسم المورد",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "رقم الهاتف",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff134e4a),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      // حفظ البيانات في فايربيس
                      await FirebaseFirestore.instance.collection('suppliers').add({
                        'name': nameController.text,
                        'phone': phoneController.text,
                        'balance': 0.0, // الرصيد الافتتاحي صفر
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      
                      // إغلاق النافذة بعد الحفظ
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("حفظ المورد", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
              stream: FirebaseFirestore.instance.collection('suppliers').orderBy('createdAt', descending: true).snapshots(), // تم إضافة الترتيب
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                if (snap.data!.docs.isEmpty) {
                   return const Center(child: Text("لا يوجد موردين، أضف أول مورد"));
                }

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
      // 3. تفعيل زر الإضافة لاستدعاء النافذة
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff134e4a),
        child: const Icon(Icons.add_business, color: Colors.white),
        onPressed: () {
           // استدعاء دالة النافذة المنبثقة
           _showAddSupplierSheet(context);
        },
      ),
    );
  }
}