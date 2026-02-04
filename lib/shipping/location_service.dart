import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourierLocationService {
  Location location = Location();

  // هذه الدالة تبدأ عملية التتبع
  Future<void> startRealtimeTracking() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // 1. التأكد من أن خدمة الـ GPS مفعلة في الجهاز
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return; // لو المندوب رفض تشغيله نخرج
    }

    // 2. التأكد من الحصول على صلاحيات الموقع من المندوب
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // 3. ضبط إعدادات التتبع (تحديث كل 10 أمتار لتقليل استهلاك البطارية)
    location.changeSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // التحديث يتم لو تحرك 10 متر
      interval: 30000,    // أو كل 30 ثانية
    );

    // 4. البدء في إرسال الموقع لفايربيس
    location.onLocationChanged.listen((LocationData currentLocation) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print("تم تحديث موقع المندوب: ${currentLocation.latitude}");
      }
    });
  }
}