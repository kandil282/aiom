import 'package:aiom/configer/settingPage.dart';
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
          title: Text(widget.userData['username'] ?? Translate.text(context, "ملف الموظف", "Employee Profile")),
          backgroundColor: const Color(0xff134e4a),
          bottom:  TabBar(
            indicatorColor: Colors.orangeAccent,
            tabs: [
              Tab(icon: Icon(Icons.calendar_month), text:  Translate.text(context, "الحضور", "Attendance")),
              Tab(icon: Icon(Icons.payments_outlined), text: Translate.text(context, "المرتبات", "Salaries")),
              Tab(icon: Icon(Icons.gavel_rounded), text: Translate.text(context, "الجزاءات", "Penalties")),
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
  // 1. تحديد أول يوم في الشهر الحالي عشان نفلتر بيه
  DateTime now = DateTime.now();
  DateTime startOfMonth = DateTime(now.year, now.month, 1);

  return StreamBuilder<QuerySnapshot>(
    // 2. تعديل الكويري لإضافة فلتر التاريخ
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('attendance')
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth) // يجيب مبيعات الشهر ده بس
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      // 3. حساب عدد الأيام ديناميكياً من البيانات اللي رجعت
      int attendanceCount = snapshot.data!.docs.length;
      String attendanceText = Translate.text (context,"$attendanceCount يوم" , "$attendanceCount Days");

      return Column(
        children: [
          // الهيدر دلوقتي بياخد القيمة الحقيقية
          _buildSummaryHeader(
            Translate.text(context, "أيام الحضور هذا الشهر", "Attendance This Month"),
            attendanceText,
            Icons.timer,
            Colors.blue,
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var log = snapshot.data!.docs[index];
                var data = log.data() as Map<String, dynamic>;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading:  CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1), // استبدلها بـ Colors.green.withOpacity(0.1)
                      child: Icon(Icons.login, color: Colors.green, size: 20),
                    ),
                    title: Text(
                      data['date'] ?? "",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      Translate.text(
                        context, 
                        "الحضور: ${data['checkIn']} | الانصراف: ${data['checkOut'] ?? '---'}", 
                        "In: ${data['checkIn']} | Out: ${data['checkOut'] ?? '---'}"
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
  // --- 2. واجهة الجزاءات والمكافآت ---
  Widget _buildPenaltiesView(bool isDark) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActionDialog(),
        label: Text(Translate.text(context, "إضافة جزاء/مكافأة", "Add Penalty/Bonus")),
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
                trailing: Text(Translate.text(context, "${isBonus ? '+' : '-'}${action['amount']}  ج.م", "${isBonus ? '+' : '-'}${action['amount']} EGP"), 
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
  // استخدام Stream لمراقبة وثيقة المستخدم (عشان المرتب الأساسي يظهر فور تعديله)
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(widget.docId).snapshots(),
    builder: (context, userSnap) {
      if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

      // قراءة المرتب الأساسي من الـ Stream الحالي وليس من الـ widget القديم
      var userData = userSnap.data!.data() as Map<String, dynamic>;
      double basicSalary = (userData['basicSalary'] ?? 0).toDouble();

      // Stream داخلي لجلب التعديلات (Bonus/Penalty)
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.docId)
            .collection('actions')
            .snapshots(),
        builder: (context, actionSnap) {
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
                _buildSalaryCard(Translate.text(context, "المرتب الأساسي", "Basic Salary"), basicSalary, Colors.grey),
                _buildSalaryCard(
                  Translate.text(context, "صافي التعديلات (جزاءات/حوافز)", "Net Adjustments (Penalties/Bonuses)"),
                  totalActions,
                  totalActions >= 0 ? Colors.green : Colors.red,
                ),
                const Divider(height: 40),
                _buildSalaryCard(
                  Translate.text(context, "إجمالي المستحق صرفه", "Total Payable Amount"),
                  basicSalary + totalActions,
                  Colors.blue,
                  isMain: true,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    // استدعاء الدالة وانتظار الانتهاء
                    _setBasicSalary();
                    // تحديث الحالة لضمان إعادة البناء (رغم أن الـ Stream سيتكفل بالأمر)
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit_note),
                  label: Text(Translate.text(context, "تعديل المرتب الأساسي", "Edit Basic Salary")),
                ),
              ],
            ),
          );
        },
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
          title: Text(Translate.text(context, "إضافة إجراء مالي", "Add Financial Action")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                onChanged: (v) => setDialogState(() => type = v!),
                items:  [
                  DropdownMenuItem(value: 'penalty', child: Text(Translate.text(context, "جزاء (خصم)", "Penalty (Deduction)"))),
                  DropdownMenuItem(value: 'bonus', child: Text(Translate.text(context, "مكافأة (إضافة)", "Bonus (Addition)"))),
                ],
              ),
              TextField(controller: amountCtrl, decoration: InputDecoration(labelText: Translate.text(context, "المبلغ", "Amount")), keyboardType: TextInputType.number),
              TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: Translate.text(context, "السبب", "Reason"))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(Translate.text(context, "إلغاء", "Cancel"))),
            ElevatedButton(onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(widget.docId).collection('actions').add({
                'type': type,
                'amount': double.parse(amountCtrl.text),
                'reason': reasonCtrl.text,
                'date': DateTime.now(),
              });
              Navigator.pop(context);
            }, child: Text(Translate.text(context, "حفظ", "Save"))),
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
        title:  Text(Translate.text(context, "تعديل المرتب الأساسي", "Edit Basic Salary")),
        content: TextField(controller: c, keyboardType: TextInputType.number),
        actions: [
          ElevatedButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(widget.docId).update({
              'basicSalary': double.parse(c.text),
            });
            Navigator.pop(context);
          }, child: Text(Translate.text(context, "تحديث", "Update"))),
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
          Text(Translate.text(context, "${value.toStringAsFixed(0)} ج.م", "${value.toStringAsFixed(0)} EGP"), style: TextStyle(fontSize: isMain ? 22 : 16, fontWeight: FontWeight.bold, color: isMain ? Colors.white : color)),
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