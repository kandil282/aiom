import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierTrackingPage extends StatelessWidget {
  final String courierId; // معرف المندوب الذي نريد تتبعه
  final String courierName;

  const CourierTrackingPage({
    required this.courierId, 
    required this.courierName, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تتبع المندوب: $courierName"),
        backgroundColor: Colors.orange[800],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // الاستماع لمستند المندوب في كوليكشن users
        stream: FirebaseFirestore.instance.collection('users').doc(courierId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          // جلب الإحداثيات (التي يرسلها كود المندوب الذي أرسلته أنت سابقاً)
          double lat = userData['latitude'] ?? 30.0444; // افتراضي القاهرة
          double lng = userData['longitude'] ?? 31.2357;
          LatLng courierPos = LatLng(lat, lng);

          return FlutterMap(
            options: MapOptions(
              initialCenter: courierPos,
              initialZoom: 15.0,
            ),
            children: [
              // تحميل طبقة الخريطة من OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.your.app',
              ),
              // وضع علامة (Marker) على موقع المندوب
              MarkerLayer(
                markers: [
                  Marker(
                    point: courierPos,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Text(courierName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.delivery_dining, color: Colors.red, size: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}