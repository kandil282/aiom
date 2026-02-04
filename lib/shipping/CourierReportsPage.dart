import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'FleetTrackingPage.dart'; // تأكد من المسار الصحيح

class CourierReportsPage extends StatelessWidget {
  const CourierReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("متابعة حركة المناديب"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agent_orders')
            .where('shippingStatus', isEqualTo: 'shipped')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("حدث خطأ في جلب البيانات"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("لا توجد شحنات نشطة حالياً"));

          // --- تعديل: تجميع البيانات مع حماية ضد الحقول المفقودة ---
          Map<String, List<DocumentSnapshot>> courierGroups = {};
          
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            
            // حماية حقل اسم المندوب
            String courier = "غير معرف";
            if (data.containsKey('courierName') && data['courierName'] != null) {
              courier = data['courierName'];
            }

            if (!courierGroups.containsKey(courier)) {
              courierGroups[courier] = [];
            }
            courierGroups[courier]!.add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courierGroups.keys.length,
            itemBuilder: (context, index) {
              String name = courierGroups.keys.elementAt(index);
              List<DocumentSnapshot> orders = courierGroups[name]!;
              
              // حماية حساب الإجمالي
              double totalValue = orders.fold(0, (sum, doc) {
                var d = doc.data() as Map<String, dynamic>;
                return sum + (d['totalAmount'] ?? 0).toDouble();
              });

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.delivery_dining, color: Colors.white),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("معه ${orders.length} طلبية | عهدة: $totalValue ج.م"),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CourierTrackingPage(courierName: name, courierId: '',)),
                      );
                    },
                    icon: const Icon(Icons.map, size: 16, color: Colors.white),
                    label: const Text("تتبع", style: TextStyle(color: Colors.white)),
                  ),
                  children: [
                    const Divider(),
                    ...orders.map((orderDoc) {
                      var order = orderDoc.data() as Map<String, dynamic>;
                      
                      // حماية حقل اسم العميل (سبب الخطأ الثاني في صورتك)
                      String customer = order.containsKey('customerName') 
                          ? order['customerName'] 
                          : "عميل بدون اسم";

                      return ListTile(
                        title: Text(customer),
                        subtitle: Text("القيمة: ${order['totalAmount'] ?? 0} ج.م"),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          onPressed: () => _markAsDelivered(orderDoc.id),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAsDelivered(String orderId) async {
    await FirebaseFirestore.instance.collection('agent_orders').doc(orderId).update({
      'shippingStatus': 'delivered',
      'deliveryDate': FieldValue.serverTimestamp(),
    });
  }
}