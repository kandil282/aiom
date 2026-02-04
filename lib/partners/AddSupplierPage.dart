import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final balanceCtrl = TextEditingController(text: "0.0"); // الرصيد الافتتاحي
  bool _isLoading = false;

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('suppliers').add({
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'balance': double.tryParse(balanceCtrl.text) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تسجيل المورد بنجاح ✅"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ في الحفظ: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إضافة مورد جديد"),
        backgroundColor: const Color(0xff692960),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.business_center, size: 80, color: Color(0xff692960)),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "اسم الشركة / المورد", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? "يجب إدخال الاسم" : null,
                  ),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: "رقم الهاتف", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: "العنوان", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                  ),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    controller: balanceCtrl,
                    decoration: const InputDecoration(labelText: "الرصيد الافتتاحي (له عندنا)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.money), suffixText: "ج.م"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 30),
                  
                  ElevatedButton(
                    onPressed: _saveSupplier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff692960),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("حفظ المورد", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}