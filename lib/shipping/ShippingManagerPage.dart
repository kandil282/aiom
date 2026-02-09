import 'package:aiom/configer/settingPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ShippingManagementPage extends StatefulWidget {
  const ShippingManagementPage({super.key});

  @override
  State<ShippingManagementPage> createState() => _ShippingManagementPageState();
}

class _ShippingManagementPageState extends State<ShippingManagementPage> {
  String? selectedCourierId;
  String? selectedCourierName;
  String? selectedCourierToken; // لحفظ التوكن الخاص بالمندوب لإرسال التنبيه

  // دالة الاتصال أو الواتساب
  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translate.text(context, "لوحة تحكم الشحن", "Shipping Management Dashboard"), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('shippingStatus', isEqualTo: 'ready')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var order = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              return _buildOrderCard(context, docId, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String docId, Map<String, dynamic> order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    List items = order['items'] ?? [];
    String phone = order['customerPhone'] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(order['customerName'] ?? Translate.text(context, "عميل جديد", "New Customer"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _launchURL("tel:$phone"),
                  child: Row(children: [const Icon(Icons.phone, size: 14, color: Colors.green), Text(" $phone", style: const TextStyle(fontSize: 13))]),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _launchURL("https://wa.me/2$phone"),
                  child: const Icon(Icons.message, size: 18, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          ...items.map((item) => _buildItemDetail(context, item)),
          _buildCourierActionSection(docId, order),
        ],
      ),
    );
  }

  Widget _buildItemDetail(BuildContext context, Map<String, dynamic> item) {
    List sources = item['deductionSources'] ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Translate.text(context, "${item['productName']} (الكمية: ${item['qty']})", "${item['productName']} (Quantity: ${item['qty']})"), style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 5,
            children: sources.map((src) => Chip(
              label: Text(Translate.text(context, "مخزن ${src['whName']}: ${src['qtyTaken']}", "Warehouse ${src['whName']}: ${src['qtyTaken']}"), style: const TextStyle(fontSize: 10)),
              backgroundColor: Colors.blue.withOpacity(0.1),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierActionSection(String orderId, Map<String, dynamic> orderData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('is_courier', isEqualTo: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              return DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: Translate.text(context, "توجيه لمندوب شحن", "Assign to Courier"), border: OutlineInputBorder()),
                items: snap.data!.docs.map((c) => DropdownMenuItem(value: c.id, child: Text(c['username'] ?? Translate.text(context, "مندوب", "Courier")))).toList(),
                onChanged: (id) {
                  var doc = snap.data!.docs.firstWhere((d) => d.id == id);
                  selectedCourierId = id;
                  selectedCourierName = doc['username'];
                  selectedCourierToken = (doc.data() as Map<String, dynamic>)['fcmToken']; // التوكن لإرسال الإشعار
                },
              );
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], minimumSize: const Size(double.infinity, 48)),
            onPressed: (

              
            ) => _assignOrder(orderId, orderData),
            icon: const Icon(Icons.send, color: Colors.white),
            label: Text(Translate.text(context, "إرسال المهمة وتنبيه المندوب", "Send Task and Notify Courier"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignOrder(String orderId, Map<String, dynamic> data) async {
    if (selectedCourierId == null) return;
    
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // 1. تحديث الفاتورة
    batch.update(FirebaseFirestore.instance.collection('invoices').doc(orderId), {
      'shippingStatus': 'shipped',
      'courierId': selectedCourierId,
      'courierName': selectedCourierName,
    });

    // 2. إرسال لصفحة المندوب
    batch.set(FirebaseFirestore.instance.collection('agent_orders').doc(orderId), {
      ...data,
      'shippingStatus': 'shipped',
      'courierId': selectedCourierId,
      'courierName': selectedCourierName,
    });

    await batch.commit();

    // 3. إرسال Push Notification (استدعاء دالة التنبيه)
    if (selectedCourierToken != null) {
      _sendNotification(selectedCourierToken!, data['customerName']);
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "تم التوجيه بنجاح ✅", "Assignment completed successfully ✅"))));
  }

  void _sendNotification(String token, String customer) {
    // هنا تضع كود الـ API الخاص بـ Firebase Messaging 
    // أو تستخدم Cloud Function لارسال الإشعار للمندوب
    print("Sending Notification to: $token for customer: $customer");
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(Translate.text(context, "لا توجد طلبات بانتظار الشحن حالياً", "No orders are waiting for shipping currently"), style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}