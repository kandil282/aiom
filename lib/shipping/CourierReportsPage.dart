import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FleetRadarPage extends StatelessWidget {
  const FleetRadarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // روابط الخريطة (مجانية تماماً ولا تحتاج API Key)
    String mapUrl = isDark
        ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
        : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";

    return Scaffold(
      appBar: AppBar(
        title: const Text("رادار المتابعة اللحظية"),
        backgroundColor: isDark ? const Color(0xff1e1b4b) : Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب كل المناديب (تأكد أن role هو التسمية الصحيحة عندك في Firestore)
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          List<Marker> markers = [];
          
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            
            // قراءة الإحداثيات بناءً على أسماء الحقول في كود المندوب الخاص بك
            double? lat = data['latitude']?.toDouble();
            double? lng = data['longitude']?.toDouble();
            String name = data['username'] ?? "مندوب";

            if (lat != null && lng != null) {
              markers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 120,
                  height: 120,
                  child: Column(
                    children: [
                      // ملصق اسم المندوب
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.indigo[700] : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                          border: Border.all(color: Colors.orange, width: 1)
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black
                          ),
                        ),
                      ),
                      const Icon(Icons.delivery_dining, color: Colors.redAccent, size: 40),
                    ],
                  ),
                ),
              );
            }
          }

          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(30.0444, 31.2357), // القاهرة كبداية
              initialZoom: 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: mapUrl,
                userAgentPackageName: 'com.your.app',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}