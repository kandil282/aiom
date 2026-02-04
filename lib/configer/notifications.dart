import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationBell extends StatelessWidget {
  final String currentUserId; // الـ ID الخاص بالمستخدم الحالي (المندوب أو المحاسب)


 
  const NotificationBell(set, {super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        int count = snap.hasData ? snap.data!.docs.length : 0;
        return IconButton(
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications),
          ),
          onPressed: () => _showNotificationsDialog(context, snap.data?.docs ?? []),
        );
      },
    );
  }

  void _showNotificationsDialog(BuildContext context, List<DocumentSnapshot> docs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("التنبيهات الجديدة"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, i) {
              var data = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title']),
                subtitle: Text(data['body']),
                onTap: () {
                  // تحديث التنبيه كمقروء
                  docs[i].reference.update({'isRead': true});
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
Future<void> sendPushNotification({
  required String receiverId,
  required String title,
  required String body,
}) async {
  // 1. جلب التوكين الخاص بالمستلم من قاعدة البيانات
  var userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
  String? token = userDoc.data()?['fcmToken'];

  if (token == null) return;

  try {
    // 2. إرسال الطلب لـ FCM API (V1)
    // ملاحظة: يتطلب هذا إعداد "Service Account Key" في مشروعك
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=YOUR_SERVER_KEY', // مفتاح الخادم من إعدادات مشروع فايربيز
      },
      body: jsonEncode({
        'to': token,
        'notification': {'title': title, 'body': body},
        'priority': 'high',
        'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
      }),
    );
  } catch (e) {
    print("Error sending push notification: $e");
  }
}
 
Future<void> sendInternalNotification({
  required String receiverId,   // الـ ID الخاص بالمستلم (المندوب مثلاً)
  required String title,        // عنوان التنبيه
  required String body,         // نص التنبيه
  String? orderId,              // رقم الطلب المرتبط (اختياري)
}) async {
  await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': receiverId,
    'title': title,
    'body': body,
    'orderId': orderId,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': false,
  });
}