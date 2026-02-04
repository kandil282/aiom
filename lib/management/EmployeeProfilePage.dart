import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmployeeControlPanel extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String docId;

  const EmployeeControlPanel({super.key, required this.userData, required this.docId});

  @override
  State<EmployeeControlPanel> createState() => _EmployeeControlPanelState();
}

class _EmployeeControlPanelState extends State<EmployeeControlPanel> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xff0f172a) : const Color(0xfff8fafc),
        appBar: AppBar(
          title: Text(widget.userData['username'] ?? "ملف الموظف"),
          backgroundColor: const Color(0xff134e4a),
          bottom: const TabBar(
            indicatorColor: Colors.orangeAccent,
            tabs: [
              Tab(icon: Icon(Icons.calendar_month), text: "الحضور"),
              Tab(icon: Icon(Icons.payments_outlined), text: "المرتبات"),
              Tab(icon: Icon(Icons.gavel_rounded), text: "الجزاءات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAttendanceView(isDark),
            _buildSalaryView(isDark),
            _buildPenaltiesView(isDark),
          ],
        ),
      ),
    );
  }

  // --- 1. واجهة الحضور والانصراف ---
  Widget _buildAttendanceView(bool isDark) {
    return Column(
      children: [
        _buildSummaryHeader("أيام الحضور هذا الشهر", "22 يوم", Icons.timer, Colors.blue),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users').doc(widget.docId).collection('attendance')
                .orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var log = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: ListTile(
                      leading: const Icon(Icons.login, color: Colors.green),
                      title: Text(log['date'] ?? ""),
                      subtitle: Text("الحضور: ${log['checkIn']} | الانصراف: ${log['checkOut'] ?? '---'}"),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 2. واجهة الجزاءات والمكافآت ---
  Widget _buildPenaltiesView(bool isDark) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActionDialog(),
        label: const Text("إضافة جزاء/مكافأة"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(widget.docId).collection('actions')
            .orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var action = snapshot.data!.docs[index];
              bool isBonus = action['type'] == 'bonus';
              return ListTile(
                leading: Icon(isBonus ? Icons.add_circle : Icons.remove_circle, 
                           color: isBonus ? Colors.green : Colors.red),
                title: Text(action['reason']),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(action['date'].toDate())),
                trailing: Text("${isBonus ? '+' : '-'}${action['amount']} ج.م", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: isBonus ? Colors.green : Colors.red)),
              );
            },
          );
        },
      ),
    );
  }

  // --- 3. واجهة المرتب (Salary Logic) ---
  Widget _buildSalaryView(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.docId).collection('actions').snapshots(),
      builder: (context, actionSnap) {
        double basicSalary = (widget.userData['basicSalary'] ?? 0).toDouble();
        double totalActions = 0;
        
        if (actionSnap.hasData) {
          for (var doc in actionSnap.data!.docs) {
            double amt = (doc['amount'] ?? 0).toDouble();
            totalActions += (doc['type'] == 'bonus' ? amt : -amt);
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSalaryCard("المرتب الأساسي", basicSalary, Colors.grey),
              _buildSalaryCard("صافي التعديلات (جزاءات/حوافز)", totalActions, totalActions >= 0 ? Colors.green : Colors.red),
              const Divider(height: 40),
              _buildSalaryCard("إجمالي المستحق صرفه", basicSalary + totalActions, Colors.blue, isMain: true),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _setBasicSalary(),
                icon: const Icon(Icons.edit_note),
                label: const Text("تعديل المرتب الأساسي"),
              )
            ],
          ),
        );
      },
    );
  }

  // --- دوال مساعدة (Dialogs) ---

  void _showAddActionDialog() {
    String type = 'penalty';
    TextEditingController amountCtrl = TextEditingController();
    TextEditingController reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("إضافة إجراء مالي"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                onChanged: (v) => setDialogState(() => type = v!),
                items: const [
                  DropdownMenuItem(value: 'penalty', child: Text("جزاء (خصم)")),
                  DropdownMenuItem(value: 'bonus', child: Text("مكافأة (إضافة)")),
                ],
              ),
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: "المبلغ"), keyboardType: TextInputType.number),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: "السبب")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(widget.docId).collection('actions').add({
                'type': type,
                'amount': double.parse(amountCtrl.text),
                'reason': reasonCtrl.text,
                'date': DateTime.now(),
              });
              Navigator.pop(context);
            }, child: const Text("حفظ")),
          ],
        ),
      ),
    );
  }

  void _setBasicSalary() {
    TextEditingController c = TextEditingController(text: widget.userData['basicSalary']?.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تعديل المرتب الأساسي"),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          ElevatedButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(widget.docId).update({
              'basicSalary': double.parse(c.text),
            });
            Navigator.pop(context);
          }, child: const Text("تحديث")),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(String title, double value, Color color, {bool isMain = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMain ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isMain ? Colors.white : Colors.black, fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
          Text("${value.toStringAsFixed(0)} ج.م", style: TextStyle(fontSize: isMain ? 22 : 16, fontWeight: FontWeight.bold, color: isMain ? Colors.white : color)),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Text(title),
          const Spacer(),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}