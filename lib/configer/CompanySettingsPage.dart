import 'dart:io' show File;
import 'package:flutter/foundation.dart'; // ضرورية للتعرف على kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  // 1. تعريف وحدات التحكم
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _commercialController = TextEditingController();
  final TextEditingController _industrialController = TextEditingController();
  final TextEditingController _importController = TextEditingController();

  // 2. المتغيرات التي كانت تسبب الخطأ
  XFile? _pickedFile;     // لتخزين الملف المختار (متوافق مع الويب والموبايل)
  Uint8List? _webImage;   // لعرض الصورة فوراً على الويب
  String? _logoUrl;       // رابط الصورة المخزن في السيرفر
  bool _isSaving = false; // حالة التحميل

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  // تحميل البيانات عند فتح الصفحة
  void _loadCompanyData() async {
    var doc = await FirebaseFirestore.instance.collection('settings').doc('company_info').get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? "";
        _addressController.text = data['address'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _taxController.text = data['taxNumber'] ?? "";
        _commercialController.text = data['commercialRegister'] ?? "";
        _industrialController.text = data['industrialRegister'] ?? "";
        _importController.text = data['importCard'] ?? "";
        _logoUrl = data['logoUrl'];
      });
    }
  }

  // اختيار الصورة
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        setState(() {
          _webImage = bytes;
          _pickedFile = image;
        });
      } else {
        setState(() {
          _pickedFile = image;
        });
      }
    }
  }

  // حفظ البيانات
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    String? finalLogoUrl = _logoUrl;

    try {
      if (_pickedFile != null) {
        var ref = FirebaseStorage.instance.ref().child('company_logos/logo.jpg');
        if (kIsWeb) {
          await ref.putData(await _pickedFile!.readAsBytes());
        } else {
          await ref.putFile(File(_pickedFile!.path));
        }
        finalLogoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('settings').doc('company_info').set({
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'taxNumber': _taxController.text,
        'commercialRegister': _commercialController.text,
        'industrialRegister': _industrialController.text,
        'importCard': _importController.text,
        'logoUrl': finalLogoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _logoUrl = finalLogoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ البيانات بنجاح ✅"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("هوية الشركة"), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // عرض اللوجو مع معالجة الويب والموبايل
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _webImage != null 
                    ? MemoryImage(_webImage!) 
                    : (_pickedFile != null 
                        ? FileImage(File(_pickedFile!.path)) 
                        : (_logoUrl != null ? NetworkImage(_logoUrl!) : null)) as ImageProvider?,
                child: (_logoUrl == null && _pickedFile == null) 
                    ? const Icon(Icons.add_a_photo, size: 40) : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(_nameController, "اسم الشركة", Icons.business),
            _buildTextField(_addressController, "العنوان", Icons.location_on),
            _buildTextField(_phoneController, "الهاتف", Icons.phone),
            const Divider(),
            _buildTextField(_taxController, "الرقم الضريبي", Icons.assignment),
            _buildTextField(_commercialController, "السجل التجاري", Icons.store),
            const SizedBox(height: 20),
            _isSaving 
                ? const CircularProgressIndicator() 
                : ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text("حفظ البيانات"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}