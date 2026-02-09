import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCustomersPage extends StatefulWidget {
  const ManageCustomersPage({super.key});

  @override
  State<ManageCustomersPage> createState() => _ManageCustomersPageState();
}

class _ManageCustomersPageState extends State<ManageCustomersPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  String? _selectedAgentId;
  String? _selectedAgentName;
  bool _isLoading = false;

  // دالة الحفظ
  Future<void> _saveCustomer() async {
    if (_nameController.text.isEmpty || _selectedAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(Translate.text(context, "برجاء إدخال الاسم واختيار البائع", "Please enter the customer name and select an agent"))));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('customers').add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'agentId': _selectedAgentId,
        'addedByAgent': _selectedAgentName,
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      _phoneController.clear();
      setState(() { _selectedAgentId = null; _selectedAgentName = null; });
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(Translate.text(context, "تمت إضافة العميل بنجاح ✅", "Customer added successfully ✅"))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(Translate.text(context, "حدث خطأ أثناء الحفظ", "An error occurred while saving"))));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // تحديد هل الجهاز في وضع الدارك أم لا
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Colors.blueAccent;

    return Scaffold(
      // اللون يتغير تلقائياً حسب الثيم
      backgroundColor: isDark ? const Color(0xff0f172a) : Colors.grey[50],
      appBar: AppBar(
        title:  Text(Translate.text(context, "إدارة العملاء", "Manage Customers"), style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF102A43) : primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildQuickAddForm(isDark),
          _buildSearchBar(isDark),
          Expanded(child: _buildCustomersList(isDark)),
        ],
      ),
    );
  }

  Widget _buildQuickAddForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _inputStyle(Translate.text(context, "اسم العميل الجديد", "New Customer Name"), Icons.person_add, isDark),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            keyboardType: TextInputType.phone,
            decoration: _inputStyle(Translate.text(context, "رقم التليفون", "Phone Number"), Icons.phone, isDark),
          ),
          const SizedBox(height: 12),
          _buildAgentDropdown(isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _saveCustomer,
              child: _isLoading
                  ?  CircularProgressIndicator(color: Colors.white)
                  :  Text(Translate.text(context, "إضافة العميل للنظام", "Add Customer to System"), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: Translate.text(context, "بحث بالاسم أو رقم التليفون...", "Search by name or phone number"),
          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomersList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return  Center(child: Text(Translate.text(context, "خطأ في تحميل البيانات", "Error loading data")));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var filteredDocs = snapshot.data!.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String name = data['name']?.toString().toLowerCase() ?? "";
          String phone = data['phone']?.toString() ?? "";
          return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            return Card(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              elevation: isDark ? 0 : 2,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.blueGrey : Colors.blueAccent.withOpacity(0.1),
                  child: Text(data['name']?[0].toUpperCase() ?? "?", 
                    style: TextStyle(color: isDark ? Colors.white : Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
                title: Text(data['name'] ?? Translate.text(context, "بدون اسم", "Unnamed Customer"), 
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: Text(Translate.text(context, "ت: ${data['phone'] ?? 'لا يوجد'} \nالمندوب: ${data['addedByAgent'] ?? 'غير محدد'}", "Phone: ${data['phone'] ?? 'No phone number'} \nAgent: ${data['addedByAgent'] ?? 'Not specified'}"),
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12)),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: -5,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_note, color: Colors.blueAccent), onPressed: () => _showEditDialog(filteredDocs[index], isDark)),
                    IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => _confirmDelete(filteredDocs[index], isDark)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgentDropdown(bool isDark, {String? initialId}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', arrayContains: 'sales').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var agents = snapshot.data!.docs;
        String? currentValue = _selectedAgentId ?? initialId;
        if (!agents.any((doc) => doc.id == currentValue)) currentValue = null;

        return DropdownButtonFormField<String>(
          dropdownColor: isDark ? const Color(0xff1e293b) : Colors.white,
          initialValue: currentValue,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          items: agents.map((agent) {
            Map<String, dynamic> d = agent.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: agent.id,
              child: Text(d['username'] ?? Translate.text(context, "مجهول", "Unknown")),
              onTap: () => _selectedAgentName = d['username'],
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedAgentId = v),
          decoration: _inputStyle(Translate.text(context, "البائع المسؤول", "Responsible Sales Agent"), Icons.badge, isDark),
        );
      },
    );
  }

  void _showEditDialog(DocumentSnapshot doc, bool isDark) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    TextEditingController editName = TextEditingController(text: data['name']);
    TextEditingController editPhone = TextEditingController(text: data['phone']);
    setState(() { _selectedAgentId = data['agentId']; _selectedAgentName = data['addedByAgent']; });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
        title: Text(Translate.text(context, "تعديل بيانات العميل", "Edit Partner Details"), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editName, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputStyle(Translate.text(context, "الاسم", "Name"), Icons.person, isDark)),
            const SizedBox(height: 10),
            TextField(controller: editPhone, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: _inputStyle(Translate.text(context, "التليفون", "Phone"), Icons.phone, isDark)),
            const SizedBox(height: 10),
            _buildAgentDropdown(isDark, initialId: _selectedAgentId),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child:  Text(Translate.text(context, "إلغاء", "Cancel"))),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.update({'name': editName.text.trim(), 'phone': editPhone.text.trim(), 'agentId': _selectedAgentId, 'addedByAgent': _selectedAgentName});
              Navigator.pop(context);
            },
            child: Text(Translate.text(context, "تحديث", "Update"))
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
        title:  Text(Translate.text(context, "تأكيد الحذف", "Confirm Deletion")),
        content:  Text(Translate.text(context, "هل أنت متأكد من حذف العميل؟", "Are you sure you want to delete this partner?")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child:  Text(Translate.text(context, "إلغاء", "Cancel"))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () async { await doc.reference.delete(); Navigator.pop(context); }, 
            child:  Text(Translate.text(context, "حذف", "Delete"), style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[700]),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
    );
  }
}