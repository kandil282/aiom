import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';

class ProfessionalAccountsPage extends StatefulWidget {
  const ProfessionalAccountsPage({super.key});

  @override
  State<ProfessionalAccountsPage> createState() => _ProfessionalAccountsPageState();
}

class _ProfessionalAccountsPageState extends State<ProfessionalAccountsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? selectedAgentFilter;
  bool _isProcessing = false; // لمتابعة حالة الضغط على الزرار

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null);
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- دالة التأكيد (بقت أسرع وأقوى) ---
// استبدل دالة _confirmSettlement الموجودة عندك بهذه النسخة المعدلة
Future<void> _confirmSettlement(String docId, Map<String, dynamic> data) async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  try {
    final batch = FirebaseFirestore.instance.batch();
    double amount = (data['amount'] ?? 0).toDouble();

    // 1. تسجيل العملية في سجل المدفوعات
    DocumentReference payRef = FirebaseFirestore.instance.collection('payments').doc();
    batch.set(payRef, {
      'agentId': data['agentId'] ?? 'N/A',
      'agentName': data['agentName'] ?? 'N/A',
      'amount': amount,
      'customerId': data['customerId'] ?? '',
      'customerName': data['customerName'] ?? 'غير معروف',
      'date': FieldValue.serverTimestamp(),
      'receiptNo': data['receiptNo'] ?? 'Auto',
      'type': 'agent_collection', // نوع الحركة
    });

    // 2. تحديث حالة الطلب المعلق
    DocumentReference pendingRef = FirebaseFirestore.instance.collection('pending_collections').doc(docId);
    batch.update(pendingRef, {'status': 'confirmed', 'settledAt': FieldValue.serverTimestamp()});

    // 3. تحديث حساب العميل
    if (data['customerId'] != null && data['customerId'] != "") {
      DocumentReference custRef = FirebaseFirestore.instance.collection('customers').doc(data['customerId']);
      
      // خصم من الرصيد
      batch.update(custRef, {'balance': FieldValue.increment(-amount)});

      // إضافة حركة في كشف حساب العميل
      DocumentReference transRef = custRef.collection('transactions').doc();
      batch.set(transRef, {
        'agentName': data['agentName'] ?? 'N/A',
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'details': Translate.text(context, "سند قبض نقدي (عن طريق المندوب) رقم :${data['receiptNo']}", "Cash Receipt (via Agent) No: ${data['receiptNo']}"),
        'receiptNo': data['receiptNo'] ?? 'N/A',
        'type': "payment",
      });
      DocumentReference globalTransRef = custRef.collection('global_transactions').doc();
      batch.set(globalTransRef, {
        'agentName': data['agentName'] ?? 'N/A',
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'details': Translate.text(context, "سند قبض نقدي (عن طريق المندوب) رقم :${data['receiptNo']}", "Cash Receipt (via Agent) No: ${data['receiptNo']}"),
        'receiptNo': data['receiptNo'] ?? 'N/A',
        'type': "payment",
      }
      
      
      
      
      );
    }

    // ============================================================
    // 4. (جديد) إضافة المبلغ للخزنة الرئيسية (Vault Integration)
    // ============================================================
    
    // أ- زيادة رصيد الخزنة الفعلي
    DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
    batch.set(vaultRef, {
      'balance': FieldValue.increment(amount), // تزويد الرصيد
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // إنشاء المستند لو مش موجود

    // ب- تسجيل حركة واردة في سجل الخزنة
    DocumentReference vaultTransRef = FirebaseFirestore.instance.collection('vault_transactions').doc();
    batch.set(vaultTransRef, {
      'type': 'income', // وارد
      'amount': amount,
      'description': Translate.text(context, "تأكيد تحصيل مندوب: ${data['agentName']} - ${data['customerName']}", "Confirmed Collection by Agent: ${data['agentName']} - ${data['customerName']}"),
      'date': FieldValue.serverTimestamp(),
      'sourceDoc': docId,
    });

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "تم الاعتماد، الترحيل للخزنة، وتحديث حساب العميل ✅", "Settled, transferred to vault, and customer account updated ✅")) ,backgroundColor: Colors.green));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
  } finally {
    setState(() => _isProcessing = false);
  }
}

// دالة جديدة كلياً للتحصيل المباشر
void _showDirectCollectionDialog() {
  final amountController = TextEditingController();
  final receiptController = TextEditingController();
  String? selectedCustomerId;
  String selectedCustomerName = "";

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(Translate.text(context, "تحصيل مباشر من عميل (للخزنة)", "Direct Collection from Customer (to Vault)")),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // اختيار العميل
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    
                    var items = snap.data!.docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc['name']),
                        onTap: () => selectedCustomerName = doc['name'],
                      );
                    }).toList();

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: Translate.text(context, "اختر العميل", "Select Customer"), border: OutlineInputBorder()),
                      items: items,
                      onChanged: (val) => setStateDialog(() => selectedCustomerId = val),
                    );
                  },
                ),
                const SizedBox(height: 15),
                // المبلغ
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: Translate.text(context, "المبلغ المحصل", "Amount Collected"), suffixText: "ج.م", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                // رقم الإيصال (اختياري)
                TextField(
                  controller: receiptController,
                  decoration: InputDecoration(labelText: Translate.text(context, "رقم الإيصال الورقي (إن وجد)", "Paper Receipt Number (if any)"), border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(Translate.text(context, "إلغاء", "Cancel"))),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(Translate.text(context, "حفظ وترحيل للخزنة", "Save and Transfer to Vault")),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedCustomerId == null || amountController.text.isEmpty) return;

                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) return;

                Navigator.pop(context); // إغلاق النافذة
                await _processDirectCollection(selectedCustomerId!, selectedCustomerName, amount, receiptController.text);
              },
            ),
          ],
        );
      },
    ),
  );
}

// دالة المعالجة الفعلية للتحصيل المباشر
// دالة التحصيل المباشر المصلحة
Future<void> _processDirectCollection(String custId, String custName, double amount, String receiptNo) async {
  // تعريف متغير حالة التحميل محلياً لتجنب خطأ التعريف
  bool isLocalProcessing = true; 
  
  try {
    // 1. جلب وثيقة العميل للتأكد من المندوب المرتبط به
    DocumentSnapshot custDoc = await FirebaseFirestore.instance.collection('customers').doc(custId).get();
    
    if (!custDoc.exists) throw Translate.text(context, "العميل غير موجود", "Customer does not exist");
    
    // استخراج بيانات المندوب من وثيقة العميل (كما تظهر في الصورة image_c658db.jpg)
    Map<String, dynamic> custData = custDoc.data() as Map<String, dynamic>;
    String linkedAgentId = custData['agentId'] ?? ''; // هذا هو الحقل السحري
    String linkedAgentName = custData['addedByAgent'] ?? 'Admin'; // استخدام اسم المندوب المسجل

    WriteBatch batch = FirebaseFirestore.instance.batch();

    // 2. تسجيل العملية في كولكشن payments العام (ليظهر في كارت المندوب)
    // لاحظ استخدام batch.set بدلاً من batch.add لتجنب الخطأ في الصورة d4dd78
    DocumentReference paymentRef = FirebaseFirestore.instance.collection('payments').doc();
    batch.set(paymentRef, {
      'amount': amount,
      'agentId': linkedAgentId, // <--- الحل: ربط العملية بهوية المندوب
      'agentName': linkedAgentName,
      'customerId': custId,
      'customerName': custName,
      'date': FieldValue.serverTimestamp(),
      'type': 'direct_collection',
    });

    // 3. تحديث حساب العميل وسجل حركاته (transactions)
    DocumentReference custRef = FirebaseFirestore.instance.collection('customers').doc(custId);
    batch.update(custRef, {'balance': FieldValue.increment(-amount)});

    DocumentReference transRef = custRef.collection('transactions').doc();
    batch.set(transRef, {
      'agentName': 'تحصيل مباشر (الإدارة)',
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'details': "سند قبض مباشر رقم: $receiptNo",
      'type': 'payment',
    });

    await batch.commit();
    if (!mounted) return; // تأكد أن الصفحة لا تزال موجودة
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "✅ تم التحصيل وربطه بالمندوب بنجاح", "✅ Collection completed and linked to agent successfully"))));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
  }
}
@override
  Widget build(BuildContext context) {
    // تعريف درجات الألوان للدارك مود
    const Color darkBackground = Color(0xFF0F172A); // كحلي غامق جداً للخلفية
    const Color darkCard = Color(0xFF1E293B);       // كحلي فاتح قليلاً للكروت والبار
    const Color accentColor = Color(0xFF6366F1);    // اللون البنفسجي/الأزرق المميز

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(Translate.text(context, "لوحة تحكم الخزينة", "Vault Control Panel"), 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        centerTitle: true,
        backgroundColor: darkCard,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          tabs: [
            Tab(icon: const Icon(Icons.account_balance_wallet), text:Translate.text(context, "تحصيلات المناديب", "Agent Collections")),
            Tab(icon: const Icon(Icons.outbound), text: Translate.text(context, "عهد الموظفين", "Staff Advances")),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCollectionsTab(), // تأكد أن هذه الدوال تستخدم نصوص بيضاء أيضاً
          _buildStaffExpensesTab(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // زر التحصيل المباشر
          FloatingActionButton.extended(
            heroTag: "btn1",
            onPressed: _showDirectCollectionDialog,
            backgroundColor: Colors.greenAccent[700], // أخضر زاهي للدارك مود
            icon: const Icon(Icons.add_card, color: Colors.white),
            label: Text(Translate.text(context, "تحصيل مباشر", "Direct Collection"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          // زر صرف العهدة
          FloatingActionButton.extended(
            heroTag: "btn2",
            onPressed: _openIssueExpenseSheet,
            backgroundColor: accentColor,
            icon: const Icon(Icons.outbound, color: Colors.white),
            label: Text(Translate.text(context, "صرف عهدة", "Issue Advance"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  // --- واجهة التحصيلات (المناديب) ---
  Widget _buildCollectionsTab() {
    return Column(
      children: [
        _buildStatHeader(), // الكروت العلوية
        _buildAgentFilter(), // الفلتر
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: selectedAgentFilter == null
                ? FirebaseFirestore.instance.collection('pending_collections').where('status', isEqualTo: 'pending').orderBy('date', descending: true).snapshots()
                : FirebaseFirestore.instance.collection('pending_collections').where('status', isEqualTo: 'pending').where('agentName', isEqualTo: selectedAgentFilter).orderBy('date', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildModernCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- كارت التصميم الجديد (شيك جداً) ---
Widget _buildModernCard(String id, Map<String, dynamic> data) {
  // تعريف الألوان الخاصة بالدارك مود للكارت
  const Color cardBackground = Color(0xFF1E293B); // كحلي فاتح
  const Color accentIndigo = Color(0xFF6366F1); // بنفسجي فاتح للأيقونات
  const Color textWhite = Colors.white;
  const Color textGrey = Colors.white70;

  return Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(20),
      // إضافة ظل خفيف جداً أو حدود ليبدو الكارت بارزاً
      border: Border.all(color: Colors.white10), 
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2), 
          blurRadius: 10, 
          offset: const Offset(0, 4)
        )
      ],
    ),
    child: Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: CircleAvatar(
            backgroundColor: accentIndigo.withOpacity(0.1),
            child: const Icon(Icons.person, color: accentIndigo),
          ),
          title: Text(
            data['customerName'] ?? "بدون اسم", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textWhite)
          ),
          subtitle: Text(
            "بواسطة: ${data['agentName'] ?? Translate.text(context, "غير معروف", "Unknown")}", 
            style: const TextStyle(fontSize: 12, color: textGrey)
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${data['amount']} ج.م", 
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              Text(
                data['receiptNo'] ?? "", 
                style: const TextStyle(fontSize: 10, color: Colors.white38)
              ),
            ],
          ),
        ),
        
        // الأزرار
        Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
          child: Row(
            children: [
              // زر الرفض
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectCollection(id),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  child: const Text("رفض", style: TextStyle(color: Colors.redAccent)),
                ),
              ),
              const SizedBox(width: 10),
              // زر التأكيد
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _confirmSettlement(id, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentIndigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isProcessing 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        Translate.text(context, "تأكيد واستلام النقدية", "Confirm and Receive Cash"),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                ),
              ),
            ],
          ),
        )
      ],
    ),
  );
}
  // --- كروت الإحصائيات العلوية ---
  Widget _buildStatHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pending_collections').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) { total += (d['amount'] ?? 0); }
        }
        return Container(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: _statCard(Translate.text(context, "إجمالي المعلق", "Total Pending"), "${total.toStringAsFixed(0)} ج.م", Icons.timer, Colors.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(Translate.text(context, "عدد العمليات", "Number of Transactions"), "${snap.hasData ? snap.data!.docs.length : 0}", Icons.list_alt, Colors.blue),
              ),
            ],
          ),
        );
      },
    );
  }

Widget _statCard(String title, String val, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B), // نفس لون الكروت الداكنة
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    ),
  );
}
  // --- فلتر المناديب ---
Widget _buildAgentFilter() {
  const Color darkCard = Color(0xFF1E293B); // لون الخلفية الداكن

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final agentDocs = snap.data!.docs;
        Set<String> agentNames = {};
        for (var d in agentDocs) {
          var data = d.data() as Map<String, dynamic>;
          if (data.containsKey('username') && data['username'] != null) {
            agentNames.add(data['username']);
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: darkCard,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              // استخدام نفس شكل الصورة (CircleAvatar) في الـ Prefix
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                  child: const Icon(Icons.person, color: Colors.indigoAccent, size: 18),
                ),
              ),
              hintText: Translate.text(context, "تصفية حسب المندوب", "Filter by Agent"),
              hintStyle: const TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            initialValue: selectedAgentFilter,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.indigoAccent),
            items: [
              DropdownMenuItem(
                value: null, 
                child: Text(Translate.text(context, "عرض كل المناديب", "Show All Agents"), style: const TextStyle(color: Colors.white54)),
              ),
              ...agentNames.map((name) => DropdownMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 10),
                        Text(name),
                      ],
                    ),
                  )),
            ],
            onChanged: (v) {
              setState(() {
                selectedAgentFilter = v;
              });
            },
          ),
        );
      },
    ),
  );
}
  
  
  
  // --- (العهد المصروفة) ---
Widget _buildStaffExpensesTab() {
  return StreamBuilder<QuerySnapshot>(
    // ملاحظة: تأكد من الضغط على رابط الـ Index اللي بيظهر في الـ Console عشان الترتيب يشتغل
    stream: FirebaseFirestore.instance
        .collection('staff_expenses')
        .where('status', isEqualTo: 'pending')
        .orderBy('date', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(Translate.text(context, "خطأ في البيانات: ${snapshot.error}", "Data Error: ${snapshot.error}")));
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(child: Text(Translate.text(context, "لا توجد عهد معلقة حالياً", "No Pending Advances")));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: snapshot.data!.docs.length,
        itemBuilder: (context, index) {
          var doc = snapshot.data!.docs[index];
          var data = doc.data() as Map<String, dynamic>;
          
          // تأكد من أسماء الحقول كما في صورتك
          String empName = data['employeeName'] ?? Translate.text(context, "غير معروف", "Unknown");
          double amount = (data['amount'] ?? 0).toDouble();
          String note = data['note'] ?? "";

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.money, color: Colors.white)),
              title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${Translate.text(context, "البيان", "Note")}: $note\n${Translate.text(context, "المبلغ", "Amount")}: $amount ج.م"),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                onPressed: () => _showSettleDialog(doc.id, empName, amount),
                child: Text(Translate.text(context, "تسوية", "Settle")),
              ),
            ),
          );
        },
      );
    },
  );
}


void _settleAdvanceDialog(String docId, String name, double totalGiven) {
  final spentController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(Translate.text(context, "تسوية عهدة: $name", "Settle Advance: $name")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${Translate.text(context, "المبلغ المنصرف للموظف", "Amount Given to Employee")} $totalGiven ج.م", style: const TextStyle(color: Colors.blue)),
          const SizedBox(height: 15),
          TextField(
            controller: spentController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "${Translate.text(context, "ما تم صرفه فعلياً", "Actual Amount Spent")}",
              border: const OutlineInputBorder(),
              suffixText: "ج.م",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            if (spentController.text.isEmpty) return;
            
            double actualSpent = double.parse(spentController.text);
            double returnedToSafe = totalGiven - actualSpent;

            // 1. ترحيل المصروف الفعلي لكوليكشن expenses
            await FirebaseFirestore.instance.collection('expenses').add({
              'amount': actualSpent,
              'category': "عهدة موظفين", // نفس الحقل في صورتك
              'date': FieldValue.serverTimestamp(),
              'recordedBy': name, // اسم الموظف اللي صرف
              'title': Translate.text(context, "تسوية عهدة مصروفات", "Settled Advance Expenses"),
            });

            // 2. تحديث مستند العهدة ليكون "تمت التسوية"
            await FirebaseFirestore.instance.collection('staff_expenses').doc(docId).update({
              'status': 'settled',
              'actualSpent': actualSpent,
              'returnedAmount': returnedToSafe,
              'settlementDate': FieldValue.serverTimestamp(),
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(Translate.text(context, "تمت التسوية. المرتجع للخزينة: $returnedToSafe ج.م", "Settlement Complete. Amount Returned to Safe: $returnedToSafe JOD"))),
            );
          },
          child: Text(Translate.text(context, "تأكيد التسوية", "Confirm Settlement")),
        ),
      ],
    ),
  );
}

void _showSettleDialog(String docId, String empName, double totalAdvance) {
  final spentCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(Translate.text(context, "تسوية عهدة $empName", "Settle Advance for $empName")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${Translate.text(context, "المبلغ المستلم", "Amount Received")}: $totalAdvance ج.م"),
          const SizedBox(height: 15),
          TextField(
            controller: spentCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "${Translate.text(context, "المبلغ المصروف فعلياً", "Actual Amount Spent")}",
              border: const OutlineInputBorder(),
              suffixText: "ج.م",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(Translate.text(context, "إلغاء", "Cancel"))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            if (spentCtrl.text.isEmpty) return;
            double actualSpent = double.tryParse(spentCtrl.text) ?? 0;
            double returnedToSafe = totalAdvance - actualSpent;

            // 1. الترحيل لكوليكشن expenses
            await FirebaseFirestore.instance.collection('expenses').add({
              'amount': actualSpent,
              'category': "عهد موظفين",
              'date': FieldValue.serverTimestamp(),
              'recordedBy': empName,
              'title': Translate.text(context, "تسوية عهدة مصروفات", "Settled Advance Expenses"),
            });

            // 2. تحديث حالة العهدة الأصلية
            await FirebaseFirestore.instance.collection('staff_expenses').doc(docId).update({
              'status': 'settled',
              'actualSpent': actualSpent,
              'returnedAmount': returnedToSafe,
              'settledAt': FieldValue.serverTimestamp(),
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(Translate.text(context, "تمت التسوية بنجاح. المتبقي للخزينة: $returnedToSafe ج.م", "Settlement Complete. Amount Returned to Safe: $returnedToSafe JOD"))),
            );
          },
          child: Text(Translate.text(context, "تأكيد التسوية", "Confirm Settlement"), style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}


  // --- دالة صرف عهدة جديدة ---
void _openIssueExpenseSheet() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedEmployee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                Translate.text(context, "تسجيل صرف عهدة موظف", "Issue Staff Advance"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 25),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'agent')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  var items = snap.data!.docs.map((d) {
                    var data = d.data() as Map<String, dynamic>;
                    String nameToShow = data['username'] ?? Translate.text(context, "بدون اسم", "No Name");
                    return DropdownMenuItem<String>(
                      value: nameToShow,
                      child: Text(nameToShow, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: Translate.text(context, "اختر الموظف", "Select Employee"),
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF6366F1)),
                    ),
                    items: items,
                    onChanged: (val) => setModalState(() => selectedEmployee = val),
                  );
                },
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: Translate.text(context, "المبلغ", "Amount"),
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: Translate.text(context, "البيان (بنزين، صيانة..)", "Note (Gas, Maintenance..)"),
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description, color: Colors.orangeAccent),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  if (selectedEmployee == null || amountController.text.isEmpty) return;
                  double amountVal = double.tryParse(amountController.text) ?? 0;
                  if (amountVal <= 0) return;

                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  DocumentReference staffExpRef = FirebaseFirestore.instance.collection('staff_expenses').doc();
                  
                  batch.set(staffExpRef, {
                    'employeeName': selectedEmployee,
                    'amount': amountVal,
                    'note': noteController.text,
                    'status': 'pending',
                    'date': FieldValue.serverTimestamp(),
                    'type': Translate.text(context, 'صرف عهدة', 'Staff Advance Issuance')
                  });

                  DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
                  batch.update(vaultRef, {'balance': FieldValue.increment(-amountVal)});

                  await batch.commit();
                  if (mounted) Navigator.pop(context);
                },
                child: Text(Translate.text(context, "تأكيد الصرف", "Confirm Issuance"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
 
  void _rejectCollection(String id) {
    FirebaseFirestore.instance.collection('pending_collections').doc(id).update({'status': 'rejected'});
  }
}