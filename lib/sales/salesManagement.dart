
import 'dart:async';
import 'package:async/async.dart'; // تأكد من إضافة async: ^2.11.0 في pubspec.yaml
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart' show kIsWeb;

// استيراد الصفحات الخاصة بك (تأكد من صحة المسارات في مشروعك)
import 'package:aiom/sales/CreateOrderPage.dart'; 
import 'package:aiom/sales/agentCustomerStatement.dart';

class ProfessionalAgentDashboard extends StatefulWidget {
  final String userId;
  final String agentName;

  const ProfessionalAgentDashboard({super.key, required this.userId, required this.agentName});

  @override
  State<ProfessionalAgentDashboard> createState() => _ProfessionalAgentDashboardState();
}

class _ProfessionalAgentDashboardState extends State<ProfessionalAgentDashboard> {
  final ScreenshotController screenshotController = ScreenshotController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null);
  }

  // --- دالة موحدة لبناء كروت الإحصائيات (تستخدم في الكروت الثلاثة) ---
Widget _buildCombinedStatsCard({required String title, required Color color}) {
  // 1. تحصيلات المندوب النقدية (المؤكدة)
  final Stream<QuerySnapshot> agentStream = FirebaseFirestore.instance
      .collection('pending_collections')
      .where('agentId', isEqualTo: widget.userId)
      .where('status', isEqualTo: 'confirmed')
      .snapshots();

  // 2. التحصيل المباشر (من المحاسب)
  final Stream<QuerySnapshot> directPayments = FirebaseFirestore.instance
      .collection('payments')
      .where('agentId', isEqualTo: widget.userId)
      .where('type', isEqualTo: 'direct_collection')
      .snapshots();

  // 3. الشيكات المحصلة (هذا هو الجزء الذي كان ناقصاً)
  final Stream<QuerySnapshot> cashedChecks = FirebaseFirestore.instance
      .collection('checks')
      .where('employeeId', isEqualTo: widget.userId) // تأكد أن الحقل في الشيك اسمه employeeId
      .where('status', isEqualTo: 'cashed')
      .snapshots();

  return StreamBuilder<List<QuerySnapshot>>(
    // دمج الـ 3 مصادر معاً
    stream: StreamZip([agentStream, directPayments, cashedChecks]),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text("Error");

      double total = 0;

      if (snapshot.hasData && snapshot.data != null) {
        // جمع النقدي المؤكد
        for (var doc in snapshot.data![0].docs) {
          total += (doc['amount'] ?? 0).toDouble();
        }
        // جمع المباشر
        for (var doc in snapshot.data![1].docs) {
          total += (doc['amount'] ?? 0).toDouble();
        }
        // جمع الشيكات المحصلة
for (var doc in snapshot.data![2].docs) {
  var val = doc['amount'];
  if (val is String) {
    total += double.tryParse(val) ?? 0;
  } else {
    total += (val ?? 0).toDouble();
  }
}
      }

      return _styleStatsCard(title, total, color);
    },
  );
}


// دالة التصميم (Stats UI)
Widget _styleStatsCard(String title, double total, Color accentColor) {
  final theme = Theme.of(context);
  
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: theme.cardColor, // هيتغير أبيض في الـ Light وأسود في الـ Dark
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentColor.withOpacity(0.2)),
      boxShadow: [
        if (theme.brightness == Brightness.light) // ظل فقط في الوضع الفاتح
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
      ],
    ),
    child: Column(
      children: [
        Text(title, style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
        const SizedBox(height: 8),
        Text(
          "${NumberFormat('#,###.##').format(total)} ج.م",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color, // لون النص الأساسي للثيم
            fontSize: 24, 
            fontWeight: FontWeight.bold
          ),
        ),
      ],
    ),
  );
}
Widget _buildSubCollectionStatsCard({required String title, required Color color}) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('customers')
        .where('agentId', isEqualTo: widget.userId)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();
      
      return FutureBuilder<double>(
        future: _calculateTotal(snapshot.data!.docs),
        builder: (context, totalSnapshot) {
          return _buildStatLayout(title, totalSnapshot.data ?? 0, color);
        },
      );
    },
  );
}

// دالة الحساب المساعدة
Future<double> _calculateTotal(List<DocumentSnapshot> customerDocs) async {
  double total = 0;
  for (var customer in customerDocs) {
    var transSnap = await customer.reference
        .collection('transactions')
        .where('type', isEqualTo: 'invoice')
        .get();
    
    for (var doc in transSnap.docs) {
      total += (doc.data()['amount'] ?? 0).toDouble();
    }
  }
  return total;
}





// دالة مساعدة لشكل الكارت الموحد عشان م نكررش الكود
Widget _buildStatLayout(String title, double total, Color color) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Icon(Icons.account_balance_wallet_outlined, color: color, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "${NumberFormat('#,###.##').format(total)} ج.م",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
@override
Widget build(BuildContext context) {
  // تعريف الألوان الأساسية للدارك مود لتسهيل التغيير
  const Color scaffoldBg = Color(0xFF0F172A); // الخلفية العميقة
  const Color cardColor = Color(0xFF1E293B);  // لون الكروت
  const Color accentColor = Colors.indigoAccent;

  return Scaffold(
    backgroundColor: scaffoldBg,
    appBar: AppBar(
      title: Text(
        "لوحة تحكم ${widget.agentName}",
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: cardColor,
      centerTitle: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.calendar_month, 
              color: startDate == null ? Colors.white70 : Colors.amber),
          onPressed: () => _selectDateRange(context),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("الإحصائيات المباشرة", 
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          
          // الكروت (التي برمجناها سابقاً) ستظهر هنا بشكل رائع
          _buildCombinedStatsCardSimple(
            title: "العهدة المعلقة",
            collection: "pending_collections",
            status: "pending",
            color: Colors.orangeAccent,
          ),

          _buildCombinedStatsCard(
            title: "إجمالي التحصيلات (كاش + شيكات)",
            color: Colors.greenAccent,
          ),

          _buildSubCollectionStatsCard(
            title: "مبيعاتك الإجمالية", 
            color: Colors.blueAccent,
          ),

          const SizedBox(height: 25),
          const Text("الوصول السريع", 
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),

          // شبكة الأزرار بتصميم الدارك الموحد
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: [
              _buildActionCard("إضافة عميل", Icons.person_add_rounded, accentColor, _openAddCustomerSheet),
              _buildActionCard("سند قبض", Icons.account_balance_wallet_rounded, Colors.greenAccent, _openPaymentSheet),
              _buildActionCard("فاتورة مبيعات", Icons.shopping_bag_rounded, Colors.orangeAccent, () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => AgentOrderPage(agentId: widget.userId)));
              }),
              _buildActionCard("كشف حساب", Icons.analytics_rounded, Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Agentcustomerstatement(agentId: widget.userId)));
              }),
            ],
          ),
        ],
      ),
    ),
  );
}
 
  // --- دالة الكارت البسيط (للعهدة فقط) ---
  Widget _buildCombinedStatsCardSimple({
    required String title,
    required String collection,
    required String status,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('agentId', isEqualTo: widget.userId)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();
          }
        }
        return _styleStatsCard(title, total, color);
      },
    );
  }

  // --- تصميم الكارت الموحد ---



// داخل شاشة المندوب - كارت الإحصائيات




Widget _buildFlexibleDoneCard() {
  // 1. الاستعلام الأساسي (يعمل دائماً بدون مشاكل)
  Query query = FirebaseFirestore.instance
      .collection('pending_collections')
      .where('agentId', isEqualTo: widget.userId)
      .where('status', isEqualTo: 'confirmed');

  // 2. فلتر التاريخ (سيتم تفعيله فقط إذا اختار المندوب فترة)
  if (startDate != null && endDate != null) {
    // ملاحظة: قد يطلب منك Firebase رابط Index جديد لهذا الترتيب
    query = query
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
  }

  return StreamBuilder<QuerySnapshot>(
    stream: query.snapshots(),
    builder: (context, snapshot) {
      // حل مشكلة الخطأ الأحمر عند اختيار الفترة
      if (snapshot.hasError) {
        return _buildErrorUI("يجب تفعيل الفهرس (Index) للفترة المختارة من كونسول Firebase");
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: LinearProgressIndicator());
      }

      double total = 0;
      if (snapshot.hasData) {
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('amount') && data['amount'] != null) {
            total += (data['amount'] as num).toDouble();
          }
        }
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي التحصيل", style: TextStyle(color: Colors.white70)),
                IconButton(
                  icon: Icon(Icons.calendar_month, color: startDate == null ? Colors.white : Colors.amber),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            Text(
              "${total.toStringAsFixed(2)} ج.م",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (startDate != null)
              TextButton.icon(
                onPressed: () => setState(() => startDate = endDate = null),
                icon: const Icon(Icons.refresh, size: 14, color: Colors.redAccent),
                label: const Text("إلغاء الفلتر والعودة للإجمالي", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
              ),
          ],
        ),
      );
    },
  );
}


Widget _buildActionCard(String t, IconData i, Color c, VoidCallback o) {
  final theme = Theme.of(context);
  
  return InkWell(
    onTap: o,
    child: Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i, color: c, size: 35),
          const SizedBox(height: 10),
          Text(t, style: TextStyle(
            color: theme.textTheme.bodyLarge?.color, 
            fontWeight: FontWeight.w600
          )),
        ],
      ),
    ),
  );
}
  // --- دوال التشغيل (Logics) ---

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _openAddCustomerSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("تسجيل عميل جديد", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "اسم العميل", labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: phoneController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "رقم التليفون", labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('customers').add({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'addedByAgent': widget.agentName,
                  'agentId': widget.userId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildFlexibleStatsCard() {
  // 1. الاستعلام الأساسي (يعمل دائماً بدون مشاكل)
  Query query = FirebaseFirestore.instance
      .collection('pending_collections')
      .where('agentId', isEqualTo: widget.userId)
      .where('status', isEqualTo: 'pending');

  // 2. فلتر التاريخ (سيتم تفعيله فقط إذا اختار المندوب فترة)
  if (startDate != null && endDate != null) {
    // ملاحظة: قد يطلب منك Firebase رابط Index جديد لهذا الترتيب
    query = query
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
  }

  return StreamBuilder<QuerySnapshot>(
    stream: query.snapshots(),
    builder: (context, snapshot) {
      // حل مشكلة الخطأ الأحمر عند اختيار الفترة
      if (snapshot.hasError) {
        return _buildErrorUI("يجب تفعيل الفهرس (Index) للفترة المختارة من كونسول Firebase");
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: LinearProgressIndicator());
      }

      double total = 0;
      if (snapshot.hasData) {
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('amount') && data['amount'] != null) {
            total += (data['amount'] as num).toDouble();
          }
        }
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إجمالي العهدة", style: TextStyle(color: Colors.white70)),
                IconButton(
                  icon: Icon(Icons.calendar_month, color: startDate == null ? Colors.white : Colors.amber),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            Text(
              "${total.toStringAsFixed(2)} ج.م",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (startDate != null)
              TextButton.icon(
                onPressed: () => setState(() => startDate = endDate = null),
                icon: const Icon(Icons.refresh, size: 14, color: Colors.redAccent),
                label: const Text("إلغاء الفلتر والعودة للإجمالي", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
              ),
          ],
        ),
      );
    },
  );
}
// الدالة التي كانت مفقودة وتسبب خطأ في الكود
Widget _buildErrorUI(String msg) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
        const SizedBox(height: 8),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 8),
        const Text("برجاء مراجعة الـ Debug Console في VS Code لضغط رابط التفعيل", 
          style: TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    ),
  );
}

  // --- 3. دالة تحصيل النقدية وإصدار الإيصال الشيك ---
 void _openPaymentSheet() {
  final amountController = TextEditingController();
  String? selectedId, selectedName;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => StatefulBuilder( // أضفت StatefulBuilder لتحديث الاختيار داخل الشيت
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("سند قبض (أمانة عهدة)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 15),
       StreamBuilder<QuerySnapshot>(
  // الفلترة هنا تضمن جلب العملاء التابعين لهذا المندوب فقط
  stream: FirebaseFirestore.instance
      .collection('customers')
      .where('agentId', isEqualTo: widget.userId) // الربط عبر الـ ID
      .snapshots(),
  builder: (context, snap) {
    if (snap.hasError) return const Text("خطأ في تحميل العملاء");
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());

    // التأكد من أن القائمة ليست فارغة
    if (snap.data!.docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("لا يوجد عملاء مضافين باسمك حتى الآن", style: TextStyle(color: Colors.orange)),
      );
    }

    // فحص العمليات المرفوضة (اختياري كما في كودك)
    var rejectedDocs = snap.data!.docs.where((d) {
      var data = d.data() as Map<String, dynamic>;
      return data.containsKey('status') && data['status'] == 'rejected';
    }).toList();

    return Column(
      children: [
        if (rejectedDocs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
            child: Text("لديك ${rejectedDocs.length} عمليات مرفوضة، برجاء مراجعة الحسابات", 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: "اختر عميلك", border: OutlineInputBorder()),
          items: snap.data!.docs.map((d) {
            var data = d.data() as Map<String, dynamic>;
            // استخدام name كما هو مسجل في قاعدة البيانات
            String cName = data['name'] ?? "بدون اسم";
            return DropdownMenuItem(
              value: d.id, 
              child: Text(cName), 
              onTap: () => selectedName = cName
            );
          }).toList(),
          onChanged: (v) => setModalState(() => selectedId = v),
        ),
      ],
    );
  },
),
           
           
            const SizedBox(height: 10),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ المحصل", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                if (selectedId == null || amountController.text.isEmpty) return;
                
                String rNo = "TR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
                
                await FirebaseFirestore.instance.collection('pending_collections').add({
                  'amount': double.parse(amountController.text),
                  'customerId': selectedId,
                  'customerName': selectedName,
                  'agentId': widget.userId,
                  'agentName': widget.agentName,
                  'status': 'pending', // التأكد من كتابتها status وليس sNatus
                  'date': FieldValue.serverTimestamp(),
                  'receiptNo': rNo,
                });

                Navigator.pop(context);
                // دالة المشاركة
                _handleShareReceipt(selectedName!, amountController.text, rNo);
              },
              child: const Text("حفظ وإرسال الإيصال", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}

  // --- 4. جلب بيانات الشركة وتصوير الإيصال ---
  void _handleShareReceipt(String customer, String amount, String rNo) async {
    var companySnap = await FirebaseFirestore.instance.collection('settings').doc('company_info').get();
    Map<String, dynamic> companyData = companySnap.data() ?? {};

    final uint8List = await screenshotController.captureFromWidget(
      Material(child: _buildReceiptDesign(customer, amount, rNo, companyData)),
      context: context,
    );

    // if (kIsWeb) {
    //   final blob = html.Blob([uint8List]);
    //   final url = html.Url.createObjectUrlFromBlob(blob);
    //   html.AnchorElement(href: url)..setAttribute("download", "Receipt-$rNo.png")..click();
    //   html.Url.revokeObjectUrl(url);
    // } else {
    //   final dir = await getTemporaryDirectory();
    //   final file = await File('${dir.path}/receipt.png').create();
    //   await file.writeAsBytes(uint8List);
    //   await Share.shareXFiles([XFile(file.path)], text: 'إيصال استلام نقدية من ${companyData['name'] ?? 'شركتنا'}');
    // }
  if (kIsWeb) {
    // كود الويب (سيتم تجاهله في الأندرويد ولن يسبب خطأ)
    // ملاحظة: لاستخدام html في الويب فقط دون ضرب الأندرويد، يفضل استخدام 
    // مكتبة universal_html من pub.dev بدلاً من dart:html
    
    // أو استخدم الحل اليدوي البسيط:
    // html.AnchorElement(href: url)...
  } else {
    // كود الأندرويد والويندوز
    // هنا نستخدم مكتبة مثل path_provider لحفظ الصورة في الاستوديو أو الفولدر
    print("تحميل الإيصال على الموبايل...");
  }





  }

  // --- 5. تصميم الإيصال الشياكة ---
  Widget _buildReceiptDesign(String customer, String amount, String rNo, Map<String, dynamic> company) {
    String dayName = DateFormat('EEEE', 'ar').format(DateTime.now());
    DateTime now = DateTime.now();
   String formattedDate = "${now.year}/${now.month}/${now.day}";
  String formattedTime = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    return Container(
      width: 380, padding: const EdgeInsets.all(30), color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              company['logoUrl'] != null && company['logoUrl'] != "" 
                ? Image.network(company['logoUrl'], width: 60, height: 60)
                : const Icon(Icons.business, size: 50, color: Colors.grey),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(company['name'] ?? "الشركة", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(company['phone'] ?? "", style: const TextStyle(fontSize: 12)),
              ]),
            ],
          ),
          const Divider(height: 40),
          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text("تم الاستلام بنجاح", 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),Text("$dayName $formattedDate | $formattedTime", 
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 30),
          _row("العميل", customer),
          _row("المبلغ", "$amount ج.م"),
          _row("رقم السند", rNo),
          _row("المندوب المستلم", widget.agentName),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Text(
                  "إيصال عهدة مؤقت (ذمة أمانة)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                SizedBox(height: 4),
                Text(
                  "لا يعتبر هذا الإيصال سداداً نهائياً إلا بعد التوريد للخزينة وتأكيد الحسابات",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        const Text("نظام الإدارة الذكي - شكراً لثقتكم", 
          style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(color: Colors.blueGrey))]),
  );

  @override
 

  Widget _buildCard(String t, IconData i, Color c, VoidCallback o) => InkWell(
    onTap: o,
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.1))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 40), const SizedBox(height: 10), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))]),
    ),
  );

}

