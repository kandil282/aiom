import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PartnerDetailsPage extends StatelessWidget {
  final Map<String, dynamic> partnerData;
  final String partnerId;

  const PartnerDetailsPage({super.key, required this.partnerData, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    double balance = (partnerData['balance'] ?? 0).toDouble();
    double limit = (partnerData['creditLimit'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text("بيانات العميل")),
      body: Column(
        children: [
          _buildHeader(),
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.green),
            title: Text(partnerData['phone'] ?? "لا يوجد رقم"),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => launchUrl(Uri.parse("tel:${partnerData['phone']}")),
            ),
          ),
          const Divider(),
          _buildInfoTile("العنوان", partnerData['address'] ?? "", Icons.location_on),
          _buildInfoTile("الرصيد الحالي", "$balance ج.م", Icons.account_balance_wallet, 
              color: balance > limit ? Colors.red : Colors.green),
          _buildInfoTile("الحد الائتماني", "$limit ج.م", Icons.lock_clock),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      color: Colors.blueGrey[50],
      child: Column(
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 10),
          Text(partnerData['name'] ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {Color color = Colors.black}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }
}