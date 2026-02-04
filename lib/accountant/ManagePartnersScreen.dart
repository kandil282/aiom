import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagePartnersScreen extends StatefulWidget {
  const ManagePartnersScreen({super.key, required String type});

  @override
  State<ManagePartnersScreen> createState() => _ManagePartnersScreenState();
}

class _ManagePartnersScreenState extends State<ManagePartnersScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  String _partnerType = 'customer'; // عميل أو مورد

  void _addPartner() async {
    if (_nameController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('partners').add({
      'name': _nameController.text,
      'taxId': _taxIdController.text,
      'type': _partnerType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _nameController.clear();
    _taxIdController.clear();
    Navigator.pop(context); // إغلاق النافذة بعد الحفظ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة العملاء والموردين")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('partners').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var partner = snapshot.data!.docs[index];
              return ListTile(
                leading: Icon(partner['type'] == 'customer' ? Icons.person : Icons.business),
                title: Text(partner['name'])?? Text("بدون اسم"),
                subtitle: Text("الرقم الضريبي: ${partner['taxId']}"),
                trailing: Text(partner['type'] == 'customer' ? "عميل" : "مورد"),
              );
            },
          );
        },
      ),
    );
  }

  // نافذة إضافة شريك جديد
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة عميل / مورد"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "الاسم")),
            TextField(controller: _taxIdController, decoration: const InputDecoration(labelText: "الرقم الضريبي")),
            DropdownButtonFormField<String>(
              initialValue: _partnerType,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text("عميل")),
                DropdownMenuItem(value: 'supplier', child: Text("مورد")),
              ],
              onChanged: (val) => setState(() => _partnerType = val!),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: _addPartner, child: const Text("حفظ")),
        ],
      ),
    );
  }
}
