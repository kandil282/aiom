import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecificWarehouseInventoryPage extends StatefulWidget {
  final String warehouseId;
  final String warehouseName;

  const SpecificWarehouseInventoryPage({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  State<SpecificWarehouseInventoryPage> createState() => _SpecificWarehouseInventoryPageState();
}

class _SpecificWarehouseInventoryPageState extends State<SpecificWarehouseInventoryPage> {
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF102A43), Color(0xFF244A5F)]),
          ),
        ),
        title: Text("جرد: ${widget.warehouseName}", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // شريط البحث الفخم
          _buildSearchBar(),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // بنجيب كل المنتجات
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var productDoc = snapshot.data!.docs[index];
                    var productData = productDoc.data() as Map<String, dynamic>;
                    
                    // هنا السحر: بنجيب "الكمية" من الكولكشن الفرعي للمخزن ده بس
                    return StreamBuilder<DocumentSnapshot>(
                      stream: productDoc.reference
                          .collection('inventory')
                          .doc(widget.warehouseId)
                          .snapshots(),
                      builder: (context, invSnapshot) {
                        if (!invSnapshot.hasData) return const SizedBox();

                        var invData = invSnapshot.data!.data() as Map<String, dynamic>?;
                        num qty = invData?['quantity'] ?? 0;

                        // تصفية البحث بالاسم أو الباركود
                        String name = (productData['productName'] ?? "").toString().toLowerCase();
                        String barcode = (productData['barcode'] ?? "").toString().toLowerCase();
                        if (!name.contains(_searchText) && !barcode.contains(_searchText)) {
                          return const SizedBox();
                        }

                        return _buildInventoryCard(productData, qty);
                      },
                    );
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
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "بحث في هذا المخزن...",
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.amber),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> product, num qty) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: qty > 0 ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$qty",
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: qty > 0 ? Colors.green[800] : Colors.red[800]
            ),
          ),
        ),
        title: Text(product['productName'] ?? "بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("التصنيف: ${product['subCategory'] ?? 'عام'}"),
            Text("الباركود: ${product['barcode'] ?? '---'}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Icon(
          Icons.inventory, 
          color: qty > 0 ? Colors.indigo : Colors.grey
        ),
      ),
    );
  }
}