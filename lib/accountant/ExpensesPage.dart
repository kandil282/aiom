import 'package:aiom/accountant/DetailedVaultReport.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? selectedDateRange;
  final bool _isProcessing = false;
  String? selectedCustomerId;
String? selectedCustomerName;
String? selectedEmployeeId;
String? selectedEmployeeName;
  // متغيرات الجرد
  final TextEditingController _physicalCountController = TextEditingController();
  
  // متغيرات الحركات
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة الخزنة والشيكات"),
        backgroundColor: isDark ? theme.cardColor : const Color(0xff1e3a8a), // لون أزرق بنكي
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: "الخزنة والحركة"),
            Tab(icon: Icon(Icons.receipt_long), text: "الشيكات"),
            Tab(icon: Icon(Icons.fact_check), text: "جرد العهدة"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVaultOverview(theme), // التبويب الأول: الخزنة
          _buildChecksManager(theme), // التبويب الثاني: الشيكات
          _buildAuditSection(theme),  // التبويب الثالث: الجرد
        ],
      ),
    );
  }

  // ==========================================
  // 1. تبويب الخزنة (الرصيد والحركات)
  // ==========================================
  
Widget _buildVaultOverview(ThemeData theme) {
  // تعريف الألوان للدارك مود
  const Color darkCard = Color(0xFF1E293B);
  const Color darkBackground = Color(0xFF0F172A);

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // كارت الرصيد الحالي (تم تحديثه للدارك مود)
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('vault').doc('main_vault').snapshots(),
          builder: (context, snap) {
            double balance = 0.0;
            if (snap.hasData && snap.data!.exists) {
              balance = (snap.data!['balance'] ?? 0).toDouble();
            }
            return Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                
                children: [
                  // أضف هذا الزر قبل الـ StreamBuilder الخاص بالسجل

                  const Text("الرصيد الحالي في الخزنة", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    "${intl.NumberFormat('#,##0.00').format(balance)} ج.م",
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                                      Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("آخر الحركات", style: TextStyle(fontSize: 18, color: Colors.white)),
                        TextButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DetailedVaultReport())),
                          icon: const Icon(Icons.analytics, color: Colors.amber),
                          label: const Text("فتح السجل الكامل / كشف حساب", style: TextStyle(color: Colors.amber)),
                        ),
                      ],
                    ),
                ],
                
              ),
            );
          },
          
        ),

        const SizedBox(height: 25),

        // أزرار العمليات السريعة
        Row(
          children: [
            Expanded(child: _buildActionButton(theme, "تسجيل مصروف", Icons.upload_rounded, Colors.redAccent, () => _showTransactionDialog(false))),
            const SizedBox(width: 15),
            Expanded(child: _buildActionButton(theme, "إيداع نقدية", Icons.download_rounded, Colors.greenAccent, () => _showTransactionDialog(true))),
          ],
        ),

        const SizedBox(height: 30),
        const Text("سجل الحركات المالية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 15),

        // سجل الحركات المطور
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('vault_transactions')
              .orderBy('date', descending: true).limit(15).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            
            return ListView.builder( // استخدام builder أفضل للتحكم في التصميم
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snap.data!.docs.length,
              itemBuilder: (context, index) {
                var data = snap.data!.docs[index].data() as Map<String, dynamic>;
                bool isIncome = data['type'] == 'income';
                
                // هنا تعديل البيانات التي تظهر في الكارت السفلي
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Icon(
                        isIncome ? Icons.add_chart_rounded : Icons.pie_chart_outline_rounded, 
                        color: isIncome ? Colors.greenAccent : Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    // 1. العنوان الرئيسي: الوصف أو اسم العميل/الموظف
                    title: Text(
                      data['description'] ?? "بدون وصف",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    // 2. العنوان الفرعي: التاريخ + (إضافة اسم المندوب إذا وجد)
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${intl.DateFormat('yyyy-MM-dd | hh:mm a').format(data['date'].toDate())}\n${data['agentName'] ?? 'الإدارة'}",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ),
                    // 3. الجانب الأيسر: المبلغ بتنسيق واضح
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isIncome ? '+' : '-'} ${intl.NumberFormat('#,###').format(data['amount'])}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: isIncome ? Colors.greenAccent : Colors.redAccent
                          ),
                        ),
                        Text(
                          isIncome ? "إيداع" : "سحب",
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        )
      ],
    ),
  );
}
 
 
 
  // ==========================================
  // 2. تبويب الشيكات
  // ==========================================
Widget _buildChecksManager(ThemeData theme) {
  return Stack(
    children: [
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('checks')
            .orderBy('dueDate')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد شيكات مسجلة"));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snap.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isCashed = data['status'] == 'cashed';

              // هنا التعديل: عرض اسم العميل ورقم الشيك في العنوان
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCashed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    child: Icon(Icons.person, color: isCashed ? Colors.green : Colors.orange),
                  ),
                  // عرض اسم العميل بشكل واضح في البداية
                  title: Text(
                    data['customerName'] ?? "عميل غير معروف", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("رقم الشيك: ${data['checkNumber']}"),
                      Text("المبلغ: ${data['amount']} ج.م", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                      Text("تاريخ الاستحقاق: ${intl.DateFormat('yyyy-MM-dd').format(data['dueDate'].toDate())}"),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCashed ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isCashed ? 'تم التحصيل' : 'تحت التحصيل',
                          style: TextStyle(color: isCashed ? Colors.green[700] : Colors.orange[700], fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                                      ),
                    trailing: !isCashed 
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 35),
                          tooltip: "ترحيل للحسابات والخزنة",
                          onPressed: () async {
                            // إظهار رسالة تأكيد قبل الترحيل (أمان إضافي)
                            bool? confirm = await _showConfirmDialog();
                            if (confirm == true) {
                              await _processCheckCashing(doc.id, data);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("تم ترحيل الشيك للحسابات والخزنة بنجاح"))
                              );
                            }
                          },
                        )
                      : const Icon(Icons.verified, color: Colors.green, size: 30),
                ),
              );
            },
          );
        },
      ),
      
      Positioned(
        bottom: 20,
        left: 20,
        child: FloatingActionButton.extended(
          onPressed: _showAddCheckDialog,
          backgroundColor: Colors.orange[800],
          icon: const Icon(Icons.add_card),
          label: const Text("إضافة شيك"),
        ),
      ),
    ],
  );
}
  
  Future<bool?> _showConfirmDialog() {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("تأكيد التحصيل"),
      content: const Text("هل أنت متأكد من تحصيل هذا الشيك؟ سيتم ترحيل المبلغ فوراً للخزنة وحساب العميل."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
      ],
    ),
  );
}
  // ==========================================
  // 3. تبويب جرد العهدة
  // ==========================================
  Widget _buildAuditSection(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: theme.hintColor),
          const SizedBox(height: 20),
          const Text("جرد الخزنة الفعلي", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "أدخل المبلغ الموجود فعلياً في الدرج لمقارنته برصيد النظام.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // عرض رصيد النظام (للمقارنة)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('vault').doc('main_vault').snapshots(),
            builder: (context, snap) {
              double sysBalance = 0.0;
              if (snap.hasData) sysBalance = (snap.data!['balance'] ?? 0).toDouble();

              return Column(
                children: [
                  Card(
                    child: ListTile(
                      title: const Text("رصيد النظام (الدفتري)"),
                      trailing: Text("$sysBalance ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _physicalCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "الرصيد الفعلي (عد النقدية)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      prefixIcon: const Icon(Icons.money),
                      filled: true,
                      fillColor: theme.cardColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _performAudit(sysBalance),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("اعتماد الجرد وتسوية الفروقات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // Helper Widgets & Functions
  // ---------------------------------------------------

  Widget _buildActionButton(ThemeData theme, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // نافذة إضافة حركة (إيراد أو مصروف)
  void _showTransactionDialog(bool isIncome) {
    _descController.clear();
    _amountController.clear();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIncome ? "إيداع نقدية" : "تسجيل مصروف"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "البيان")),
            const SizedBox(height: 10),
            TextField(controller: _amountController, decoration: const InputDecoration(labelText: "المبلغ"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              double val = double.tryParse(_amountController.text) ?? 0;
              if (val > 0) {
                _processTransaction(val, _descController.text, isIncome ? 'income' : 'expense');
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isIncome ? Colors.green : Colors.red),
            child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // نافذة إضافة شيك جديد
void _showAddCheckDialog() {
  final numController = TextEditingController();
  final amountController = TextEditingController();
  String? selectedCustomerId;
  String selectedCustomerName = "";
  String? selectedEmployeeId; // هذا المتغير سيحمل الـ agentId الخاص بالعميل
  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تسجيل شيك جديد"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // اختيار العميل
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "اختر العميل", border: OutlineInputBorder()),
                      items: snap.data!.docs.map((doc) {
                        var customerData = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(customerData['name'] ?? ""),
                          onTap: () {
                            // هنا التعديل الجوهري: نسحب الاسم والـ agentId معاً
                            selectedCustomerName = customerData['name'] ?? "";
                            selectedEmployeeId = customerData['agentId']; // سحب المندوب المرتبط بالعميل
                          },
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedCustomerId = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: numController, 
                  decoration: const InputDecoration(labelText: "رقم الشيك", border: OutlineInputBorder())
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "قيمة الشيك", border: OutlineInputBorder())
                ),
                const SizedBox(height: 15),
                ListTile(
                  title: Text("تاريخ الاستحقاق: ${intl.DateFormat('yyyy-MM-dd').format(selectedDate)}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, 
                      initialDate: selectedDate, 
                      firstDate: DateTime(2025), 
                      lastDate: DateTime(2030)
                    );
                    if (picked != null) setStateDialog(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedCustomerId == null || amountController.text.isEmpty) return;
                double amount = double.tryParse(amountController.text) ?? 0;
                
                Navigator.pop(context);

                // حفظ الشيك وربطه بالمندوب (agentId) الذي سحبناه تلقائياً من بيانات العميل
                await FirebaseFirestore.instance.collection('checks').add({
                  'customerId': selectedCustomerId,
                  'customerName': selectedCustomerName,
                  'employeeId': selectedEmployeeId, // تم الربط تلقائياً هنا
                  'checkNumber': numController.text,
                  'amount': amount,
                  'dueDate': Timestamp.fromDate(selectedDate),
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
              child: const Text("حفظ الشيك"),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _processCheckCashing(String checkId, Map<String, dynamic> checkData) async {
  final firestore = FirebaseFirestore.instance;
  WriteBatch batch = firestore.batch();

  String customerId = checkData['customerId'];
  String? employeeId = checkData['employeeId'];
  double amount = (checkData['amount'] as num).toDouble();
  String checkNum = checkData['checkNumber'] ?? "000";

  // 1. إضافة الحركة في كشف حساب العميل (Sub-collection)
  DocumentReference customerTransRef = firestore
      .collection('customers')
      .doc(customerId)
      .collection('transactions')
      .doc();

  batch.set(customerTransRef, {
    'agentId': employeeId,
    'amount': amount,
    'date': FieldValue.serverTimestamp(),
    'details': "تحصيل شيك رقم: $checkNum",
    'receiptNo': "CH-$checkNum",
    'type': "payment", // عشان يطرح من المديونية في نظامك
  });

  // 2. خصم المبلغ من رصيد العميل الإجمالي
  batch.update(firestore.collection('customers').doc(customerId), {
    'balance': FieldValue.increment(-amount)
  });

  // 3. زيادة رصيد الخزنة وسجل العمليات
  batch.update(firestore.collection('vault').doc('main_vault'), {
    'balance': FieldValue.increment(amount)
  });

  batch.set(firestore.collection('vault_transactions').doc(), {
    'amount': amount,
    'type': 'income',
    'description': "تحصيل شيك عميل: ${checkData['customerName']}",
    'date': FieldValue.serverTimestamp(),
  });

  // 4. تحديث حالة الشيك
  batch.update(firestore.collection('checks').doc(checkId), {
    'status': 'cashed',
    'cashedAt': FieldValue.serverTimestamp(),
  });

  await batch.commit();
}
  // --- دوال المنطق (Backend Logic) ---

  // 1. تنفيذ حركة وتحديث الرصيد
  Future<void> _processTransaction(double amount, String desc, String type) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // سجل الحركة
    DocumentReference transRef = FirebaseFirestore.instance.collection('vault_transactions').doc();
    batch.set(transRef, {
      'amount': amount,
      'description': desc,
      'type': type, // 'income' or 'expense' or 'audit_adjustment'
      'date': FieldValue.serverTimestamp(),
    });

    // تحديث الرصيد
    DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
    batch.set(vaultRef, {
      'balance': FieldValue.increment(type == 'income' ? amount : -amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // 2. تحصيل شيك (يغير حالة الشيك + يضيف المبلغ للخزنة)
Future<void> _cashCheck(String checkId, double amount, String checkNum, String customerId, String employeeId) async {
  try {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // 1. تحديث حالة الشيك إلى "تم التحصيل" (Cashed)
    DocumentReference checkRef = FirebaseFirestore.instance.collection('checks').doc(checkId);
    batch.update(checkRef, {
      'status': 'cashed',
      'cashedAt': FieldValue.serverTimestamp(),
    });

    // 2. تحديث رصيد الخزنة الرئيسي (إضافة المبلغ)
    DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
    batch.update(vaultRef, {'balance': FieldValue.increment(amount)});

    // 3. إضافة حركة في سجل الخزينة (Transaction Log)
    DocumentReference vaultTransRef = FirebaseFirestore.instance.collection('vault_transactions').doc();
    batch.set(vaultTransRef, {
      'amount': amount,
      'type': 'income', // إيداع
      'description': "تحصيل شيك رقم: $checkNum",
      'date': FieldValue.serverTimestamp(),
    });

    // 4. تنزيل المبلغ من مديونية العميل (نفس منطق التحصيل المباشر)
    if (customerId.isNotEmpty) {
      DocumentReference customerRef = FirebaseFirestore.instance.collection('customers').doc(customerId);
      batch.update(customerRef, {'balance': FieldValue.increment(-amount)}); // خصم من المديونية
    }

    // 5. إضافة المبلغ لعمولات أو تحصيلات المندوب (حساب المندوب)
    if (employeeId.isNotEmpty) {
      DocumentReference empRef = FirebaseFirestore.instance.collection('employees').doc(employeeId);
      // نفرض أن الحقل اسمه currentMonthCollection أو balance
      batch.update(empRef, {'totalCollected': FieldValue.increment(amount)});
    }

    // تنفيذ كل العمليات دفعة واحدة
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تحصيل الشيك وتحديث حسابات العميل والمندوب بنجاح")),
    );
  } catch (e) {
    print("خطأ في التحصيل: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("فشل التحصيل: $e")),
    );
  }
}
  // 3. منطق الجرد (تسوية العجز أو الزيادة)
  Future<void> _performAudit(double systemBalance) async {
    double physical = double.tryParse(_physicalCountController.text) ?? 0;
    double diff = physical - systemBalance; // لو موجب يبقى زيادة، لو سالب يبقى عجز

    if (diff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرصيد مطابق تماماً، ممتاز! 👌")));
      return;
    }

    String type = diff > 0 ? 'income' : 'expense'; // الزيادة إيراد، العجز مصروف
    String desc = diff > 0 
        ? "تسوية جرد (زيادة نقدية)" 
        : "تسوية جرد (عجز نقدية)";

    // نقوم بعمل حركة بقيمة الفرق فقط لتظبيط الرصيد
    await _processTransaction(diff.abs(), desc, type); // نرسل القيمة المطلقة لأن النوع سيحدد الجمع أو الطرح

    _physicalCountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("تمت التسوية: ${diff > 0 ? 'زيادة' : 'عجز'} بقيمة ${diff.abs()}"),
      backgroundColor: diff > 0 ? Colors.green : Colors.red,
    ));
  }
}