import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ستحتاج لإضافة intl في pubspec.yaml لتنسيق الوقت

class AccountantStockPage extends StatefulWidget {
  const AccountantStockPage({super.key});

  @override
  State<AccountantStockPage> createState() => _AccountantStockPageState();
}

class _AccountantStockPageState extends State<AccountantStockPage> {
  String _searchText = "";

  // دالة تحديث الكمية مع تسجيل "اللوج"
  Future<void> _updateQuantity(String docId, String productName, num currentQty, int change) async {
    num newQty = currentQty + change;
    if (newQty < 0) return;

    // 1. تحديث الكمية في المخزن
    await FirebaseFirestore.instance.collection('warehouses').doc(docId).update({
      'quantity': newQty,
    });

    // 2. تسجيل الحركة في مجموعة "logs"
    await FirebaseFirestore.instance.collection('inventory_logs').add({
      'productId': docId,
      'productName': productName,
      'change': change, // +1 أو -1
      'newQuantity': newQty,
      'timestamp': FieldValue.serverTimestamp(),
      'action': change > 0 ? "إضافة" : "صرف",
      'user': "المحاسب الحالي", // يمكن ربطها بـ Auth لاحقاً
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("التحكم والرقابة المالية"),
        backgroundColor: const Color(0xFF102A43),
        elevation: 0,
      ),
      body: Column(
        children: [
          // شريط البحث
          _buildSearchBar(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('warehouses').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs.where((doc) {
                  String name = (doc['productName'] ?? "").toString().toLowerCase();
                  String barcode = (doc['barcode'] ?? "").toString().toLowerCase();
                  return name.contains(_searchText) || barcode.contains(_searchText);
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var item = docs[index];
                    var data = item.data() as Map<String, dynamic>;
                    num qty = data['quantity'] ?? 0;

                    return _buildAccountantCard(item.id, data['productName'], qty, data['barcode']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF102A43),
      child: TextField(
        onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "بحث بالباركود للتحكم...",
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.amber),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildAccountantCard(String id, String name, num qty, String barcode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("الرصيد الحالي: $qty"),
          trailing: Container(
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                  onPressed: () => _updateQuantity(id, name, qty, -1),
                ),
                Text("$qty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () => _updateQuantity(id, name, qty, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}