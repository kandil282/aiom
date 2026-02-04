import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountantPage extends StatefulWidget {
  const AccountantPage({super.key});

  @override
  State<AccountantPage> createState() => _AccountantPageState();
}

class _AccountantPageState extends State<AccountantPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("لوحة تحكم مدير الحسابات"),
          backgroundColor: Colors.teal[800],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: "طلبات الموافقة", icon: Icon(Icons.notification_important)),
              Tab(text: "إدارة صلاحيات الموظفين", icon: Icon(Icons.security)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildApprovalTab(), // الطلبات التي تحتاج موافقة لتجاوز الحد الائتماني
            _buildRolesTab(),    // توزيع الأدوار على المحاسبين
          ],
        ),
      ),
    );
  }

  // 1. تبويب الموافقات على تجاوز الحد الائتماني
  Widget _buildApprovalTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders')
          .where('status', isEqualTo: 'waiting_manager_approval').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var orders = snapshot.data!.docs;

        if (orders.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة حالياً"));

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            var order = orders[index];
            return Card(
              margin: const EdgeInsets.all(10),
              color: Colors.red[50],
              child: ListTile(
                title: Text("العميل: ${order['customerName']}"),
                subtitle: Text("المبلغ: ${order['totalPrice']} ج.م\nتنبيه: هذا العميل متجاوز للحد الائتماني!"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                      onPressed: () => _approveOrder(order.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                      onPressed: () => _rejectOrder(order.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. تبويب توزيع الصلاحيات للموظفين
  Widget _buildRolesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index];
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user['username']),
              subtitle: Text("الصلاحيات: ${user['rolls']}"),
              trailing: const Icon(Icons.edit),
              onTap: () => _showRolesEditor(user.id, List.from(user['rolls'])),
            );
          },
        );
      },
    );
  }

  // نافذة تعديل الصلاحيات (لتنفيذ فكرة إعطاء الموظف أكثر من Role)
  void _showRolesEditor(String userId, List<dynamic> currentRolls) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("تعديل صلاحيات الموظف"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roleSwitch("حسابات عملاء", "customers_acc", currentRolls, setDialogState),
                _roleSwitch("حسابات موردين", "suppliers_acc", currentRolls, setDialogState),
                _roleSwitch("مصاريف", "expenses_acc", currentRolls, setDialogState),
                _roleSwitch("مدير حسابات", "manager_acc", currentRolls, setDialogState),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({'rolls': currentRolls});
                  Navigator.pop(context);
                },
                child: const Text("حفظ التغييرات"),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _roleSwitch(String label, String value, List rolls, Function setState) {
    return CheckboxListTile(
      title: Text(label),
      value: rolls.contains(value),
      onChanged: (val) {
        setState(() {
          val! ? rolls.add(value) : rolls.remove(value);
        });
      },
    );
  }

  void _approveOrder(String id) => FirebaseFirestore.instance.collection('orders').doc(id).update({'status': 'approved'});
  void _rejectOrder(String id) => FirebaseFirestore.instance.collection('orders').doc(id).update({'status': 'rejected'});
}