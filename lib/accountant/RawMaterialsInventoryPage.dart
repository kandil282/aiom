import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RawMaterialsInventoryPage extends StatelessWidget {
  const RawMaterialsInventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("جرد مخزن الخامات"),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('raw_materials').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              var data = snap.data!.docs[i].data() as Map<String, dynamic>;
              double stock = (data['stock'] ?? 0).toDouble();

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: stock < 10 ? Colors.red[100] : Colors.blueGrey[100],
                    child: Icon(Icons.inventory_2, color: stock < 10 ? Colors.red : Colors.blueGrey),
                  ),
                  title: Text(data['materialName'] ?? Translate.text(context, "خامة غير معروفة", "Unknown Material"), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(Translate.text(context, "آخر سعر شراء: ${data['unitPrice'] ?? 0} ج.م", "Last Purchase Price: ${data['unitPrice'] ?? 0} EGP")),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(Translate.text(context, "الكمية المتاحة", "Available Quantity"), style: TextStyle(fontSize: 10)),
                      Text(
                        "$stock",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: stock < 10 ? Colors.red : Colors.black
                        ),
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
}