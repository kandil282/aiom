import 'package:aiom/accountant/SpecificWarehouseInventoryPage.dart';
import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageWarehousesPage extends StatefulWidget {
  const ManageWarehousesPage({super.key});

  @override
  State<ManageWarehousesPage> createState() => _ManageWarehousesPageState();
}

class _ManageWarehousesPageState extends State<ManageWarehousesPage> {
  final TextEditingController _warehouseNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createWarehouse() async {
    if (_warehouseNameController.text.isEmpty) {
      _showSnackBar("برجاء كتابة اسم المخزن", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('storage_locations').add({
        'name': _warehouseNameController.text.trim(),
        'location': _locationController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _warehouseNameController.clear();
      _locationController.clear();
      _showSnackBar(Translate.text(context, "تم إنشاء المخزن بنجاح ✅", "Warehouse created successfully ✅"), Colors.green);
    } catch (e) {
      _showSnackBar(Translate.text(context, "حدث خطأ أثناء الإنشاء", "An error occurred while creating the warehouse"), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    // تعريف متغيرات الـ Theme
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(Translate.text(context, "إدارة مواقع التخزين", "Manage Storage Locations"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? theme.cardColor : const Color(0xFF102A43),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // القسم العلوي
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? theme.cardColor : const Color(0xFF102A43),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Card(
              elevation: isDark ? 0 : 8,
              color: isDark ? theme.scaffoldBackgroundColor : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                     Translate.text(context, "إنشاء مخزن جديد", "Create New Warehouse"),
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : const Color(0xFF102A43)
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _warehouseNameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: Translate.text(context, "اسم المخزن", "Warehouse Name"),
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.indigo),
                        prefixIcon: Icon(Icons.storefront, color: isDark ? Colors.amber : Colors.indigo),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: Translate.text(context, "الموقع/العنوان (اختياري)", "Location/Address (Optional)"),
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.indigo),
                        prefixIcon: Icon(Icons.location_on_outlined, color: isDark ? Colors.amber : Colors.indigo),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _createWarehouse,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          :  Text(Translate.text(context, "إضافة المخزن للقائمة", "Add Warehouse to List"), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: isDark ? Colors.amber : const Color(0xFF102A43)),
                const SizedBox(width: 10),
                Text(
                 Translate.text(context, "المخازن الحالية", "Current Warehouses"), 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white : const Color(0xFF102A43)
                  )
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('storage_locations').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var warehouse = snapshot.data!.docs[index];
                    return _buildWarehouseCard(warehouse, theme, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCard(DocumentSnapshot doc, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.indigo[50], 
            borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(Icons.warehouse, color: isDark ? Colors.amber : Colors.indigo),
        ),
        title: Text(
          doc['name'], 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)
        ),
        subtitle: Text(
          doc['location'] ?? Translate.text(context, "لا يوجد عنوان محدد", "No Address Specified"), 
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600])
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpecificWarehouseInventoryPage(
                warehouseId: doc.id,
                warehouseName: doc['name'],
              ),
            ),
          );
        },
      ),
    );
  }
}