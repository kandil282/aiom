import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

class CourierDashboard extends StatefulWidget {
  const CourierDashboard({super.key});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();
}

class _CourierDashboardState extends State<CourierDashboard> {
  final Location location = Location();
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _setupLocation(); // تم إزالة async من هنا للإصلاح
  }

  Future<void> _setupLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // تحديث الموقع في Firestore داخل كوليكشن users بناءً على صورتك
  // داخل دالة _setupLocation في صفحة المندوب
location.onLocationChanged.listen((LocationData currentLocation) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'latitude': currentLocation.latitude,
      'longitude': currentLocation.longitude,
      // الحقل الجديد الذي ستستخدمه الخريطة
      'lastLocation': GeoPoint(currentLocation.latitude!, currentLocation.longitude!), 
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
});
    if (mounted) setState(() => _isTracking = true);
  }

  @override
  Widget build(BuildContext context) {
    // جلب الـ UID الحالي لضمان دقة جلب الأوردرات
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("مهامي اليومية 📦"),
        backgroundColor: Colors.orange[800],
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.gps_fixed, color: _isTracking ? Colors.greenAccent : Colors.white60),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // البحث عن الأوردرات الموجهة لهذا المندوب (بناءً على الـ ID لضمان الدقة)
        stream: FirebaseFirestore.instance
            .collection('agent_orders')
            .where('courierId', isEqualTo: myUid)
            .where('shippingStatus', isEqualTo: 'shipped')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد أوردرات بانتظارك"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var order = snapshot.data!.docs[index];
              var data = order.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['customerName'] ?? "بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${data['totalAmount']} ج.م", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("📞 ${data['customerPhone'] ?? 'غير مسجل'}"),
                      const Divider(),
                      // تفاصيل الأصناف والمخازن (كما طلبت في البداية)
                      ...(data['items'] as List).map((item) => Text("• ${item['productName']} (الكمية: ${item['qty']})")),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () => _confirmDelivery(order.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        child: const Text("تم التسليم للعميل ✅", style: TextStyle(color: Colors.white)),
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

  Future<void> _confirmDelivery(String orderId) async {
    await FirebaseFirestore.instance.collection('agent_orders').doc(orderId).update({
      'shippingStatus': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }
}