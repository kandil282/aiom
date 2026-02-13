import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiom/configer/settingPage.dart';

class FleetRadarPage extends StatefulWidget {
  const FleetRadarPage({super.key});

  @override
  State<FleetRadarPage> createState() => _FleetRadarPageState();
}

class _FleetRadarPageState extends State<FleetRadarPage> {
  // 1. تعريف المتحكم
  final MapController _mapController = MapController();
  bool _isSatellite = false; // خيار تبديل نوع الخريطة

  // إحداثيات مركز مصر
  final LatLng _egyptCenter = const LatLng(26.8206, 30.8025);

  void _animatedMove(LatLng destLocation, double destZoom) {
    // يمكنك هنا إضافة Animation لو حابب، لكن حالياً سنستخدم الانتقال المباشر
    _mapController.move(destLocation, destZoom);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // خيارات الطبقات (Layers)
    String mapUrl = _isSatellite 
        ? "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}" // قمر صناعي
        : (isDark 
            ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" 
            : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png");

    return Scaffold(
      appBar: AppBar(
        title: Text(Translate.text(context, "رادار المناديب", "Live Fleet")),
        actions: [
          // 2. خيار التبديل لوضع القمر الصناعي
          IconButton(
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt),
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('is_courier', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              List<Marker> markers = snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return Marker(
                  point: LatLng(data['latitude'] ?? 0, data['longitude'] ?? 0),
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () {
                      // 3. خيار: عند الضغط على المندوب، الخريطة تعمل زووم عليه
                      _animatedMove(LatLng(data['latitude'], data['longitude']), 12.0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("المندوب: ${data['username']}")),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.orange)),
                          child: Text(data['username'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.black)),
                        ),
                        const Icon(Icons.delivery_dining, color: Colors.red, size: 30),
                      ],
                    ),
                  ),
                );
              }).toList();

              return FlutterMap(
                mapController: _mapController, // ربط المتحكم
                options: MapOptions(
                  initialCenter: _egyptCenter,
                  initialZoom: 6.0,
                  minZoom: 5.0, // 4. منع المستخدم من الخروج بعيداً عن الخريطة
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // 5. منع تدوير الخريطة للحفاظ على الاتجاهات
                  ),
                ),
                children: [
                  TileLayer(urlTemplate: mapUrl, userAgentPackageName: 'com.aiom.app'),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),
          
          // 6. أزرار تحكم عائمة (Control Panel)
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "reCenter",
                  onPressed: () => _animatedMove(_egyptCenter, 6.0),
                  child: const Icon(Icons.home_work),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}