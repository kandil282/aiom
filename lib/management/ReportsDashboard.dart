import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart'; // لا تنسى إضافة المكتبة في pubspec.yaml

class BusinessExecutiveDashboard extends StatefulWidget {
  const BusinessExecutiveDashboard({super.key});

  @override
  State<BusinessExecutiveDashboard> createState() => _BusinessExecutiveDashboardState();
}

class _BusinessExecutiveDashboardState extends State<BusinessExecutiveDashboard> {
  String selectedFilter = "الكل";

  // دالة الأنيميشن الموحدة للكروت
  Widget _animatedItem(Widget child, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Future<void> _generatePDFReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text("Business Executive Report - 2026", 
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff020617) : const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text("الرقابة المالية", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.blueGrey[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
            onPressed: _generatePDFReport,
          ),
          _buildFilterMenu(),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _animatedItem(_buildSmartAlerts(isDark), 0),
                  _buildSectionTitle("الملخص المالي اللحظي", Icons.bolt, isDark),
                  _animatedItem(_buildProfitCard(isDark), 1),
                  const SizedBox(height: 15),
                  _animatedItem(_buildMainFinancialStats(isDark), 2),
                  const SizedBox(height: 25),
                  _buildSectionTitle("تحليل المبيعات", Icons.query_stats, isDark),
                  _animatedItem(_buildComprehensiveAnalysis(isDark), 3),
                  const SizedBox(height: 25),
                  _buildSectionTitle("حالة المخازن", Icons.warehouse_rounded, isDark),
                  _animatedItem(_buildInventoryValuation(isDark), 4),
                  const SizedBox(height: 25),
                  _buildSectionTitle("إحصائيات التشغيل", Icons.account_tree_outlined, isDark),
                  _animatedItem(_buildOperationalStats(isDark), 5),
                  const SizedBox(height: 40),
                  _animatedItem(_buildDeleteEverythingButton(context), 6),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- تصفير البيانات مع الأنيميشن وحل مشكلة التعليق ---
  Future<void> _performErasure(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 6, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text("جاري تنظيف المنظومة...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      List<String> collections = [
        'agent_orders', 'expenses', 'pending_collections', 'work_orders', 
        'raw_materials', 'customers', 'categories', 'checks', 'employeeData', 
        'invoices', 'suppliers', 'vault_transactions', 'storage_locations', 'products',
      ];

      for (var coll in collections) {
        var snapshot = await FirebaseFirestore.instance.collection(coll).get();
        if (snapshot.docs.isNotEmpty) {
          WriteBatch batch = FirebaseFirestore.instance.batch();
          for (var doc in snapshot.docs) { batch.delete(doc.reference); }
          await batch.commit();
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // إغلاق اللودنج يقيناً

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم تصفير قاعدة البيانات بنجاح"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e"), backgroundColor: Colors.red));
    }
  }

  // --- الرسوم البيانية مع ربط الأسماء بالـ Users ---
Widget _buildComprehensiveAnalysis(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    // جلب كل المستخدمين اللي دورهم مبيعات "sales"
    stream: FirebaseFirestore.instance.collection('users')
        .where('role', arrayContains: 'sales').snapshots(),
    builder: (context, userSnap) {
      if (!userSnap.hasData) return const CircularProgressIndicator();

      // خريطة لتخزين بيانات المناديب (الاسم والرقم)
      Map<String, Map<String, String>> agentsInfo = {
        for (var d in userSnap.data!.docs) 
          d.id: {
            'name': d['username'] ?? "مجهول",
            'phone': d['phone'] ?? ""
          }
      };

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
        builder: (context, orderSnap) {
          if (!orderSnap.hasData) return const SizedBox();

          // حساب إجمالي المبيعات لكل مندوب
          Map<String, double> salesStats = {};
          for (var doc in orderSnap.data!.docs) {
            String id = doc['agentId'] ?? "";
            if (agentsInfo.containsKey(id)) {
              String name = agentsInfo[id]!['name']!;
              salesStats[name] = (salesStats[name] ?? 0) + (doc['totalAmount'] ?? 0).toDouble();
            }
          }

          // تحديد المناديب الذين لم يحققوا مبيعات
          List<String> inactiveIds = agentsInfo.keys
              .where((id) => !salesStats.containsKey(agentsInfo[id]!['name']))
              .toList();

          // ترتيب المناديب الناجحين تنازلياً
          var sortedSales = salesStats.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Column(
            children: [
              // 1. الشارت المرتّب
              _buildModernBarChart(sortedSales, isDark),
              
              const SizedBox(height: 25),

              // 2. قائمة المتابعة والتحفيز (واتساب)
              if (inactiveIds.isNotEmpty)
                _buildActionList(inactiveIds, agentsInfo, isDark),
            ],
          );
        },
      );
    },
  );
}

// ويدجت قائمة "اتخاذ الإجراء"
Widget _buildActionList(List<String> ids, Map<String, Map<String, String>> info, bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text("مناديب لم يسجلوا مبيعات (تحتاج متابعة)", 
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      ),
      ...ids.map((id) {
        final name = info[id]!['name']!;
        final phone = info[id]!['phone']!;
        
        return Card(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.person_outline, color: Colors.red)),
            title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text("لا توجد عمليات اليوم", style: TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () => _launchWhatsApp(phone, name),
            ),
          ),
        );
      }),
    ],
  );
}

// دالة فتح الواتساب برسالة تلقائية
void _launchWhatsApp(String phone, String name) async {
  String message = "أهلاً يا $name، لاحظت إن مفيش مبيعات مسجلة باسمك النهاردة، هل فيه أي مشكلة أقدر أساعدك فيها؟";
  var url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
  if (await canLaunch(url)) {
    await launch(url);
  }
}
// ويدجت الرسم البياني الاحترافي
Widget _buildModernBarChart(List<MapEntry<String, double>> data, bool isDark) {
  if (data.isEmpty) return const Center(child: Text("لا توجد مبيعات مسجلة"));
  
  return Container(
    height: 350,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      borderRadius: BorderRadius.circular(25),
    ),
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.first.value * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 60,
            getTitlesWidget: (v, m) => Text(data[v.toInt()].key, style: const TextStyle(fontSize: 9))
          )),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [BarChartRodData(
            toY: e.value.value,
            color: e.key == 0 ? Colors.orangeAccent : Colors.blueAccent,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          )]
        )).toList(),
      ),
    ),
  );
}

// ويدجت التنبيه للمناديب "بدون نشاط"
Widget _buildInactiveAgentsAlert(List<String> names, bool isDark) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Text("مناديب بدون مبيعات حالياً", 
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: names.map((name) => Chip(
            label: Text(name, style: const TextStyle(fontSize: 11)),
            backgroundColor: isDark ? Colors.white10 : Colors.white,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    ),
  );
}


  // --- ويدجت قيمة المخزون (خامات + منتجات) ---
  Widget _buildInventoryValuation(bool isDark) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('raw_materials').snapshots(),
          builder: (context, snapshot) {
            double val = snapshot.hasData ? snapshot.data!.docs.fold(0.0, (s, d) => s + (d['stock'] ?? 0) * (d['unitPrice'] ?? 0)) : 0;
            return _largeMetricCard("قيمة الخامات", val, Icons.inventory_2, Colors.orange, isDark);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, snapshot) {
            double val = snapshot.hasData ? snapshot.data!.docs.fold(0.0, (s, d) => s + (d['totalQuantity'] ?? 0) * (d['price'] ?? 0)) : 0;
            return _largeMetricCard("قيمة المنتجات التامة", val, Icons.precision_manufacturing, Colors.purple, isDark);
          },
        ),
      ],
    );
  }

  // --- باقي الويدجت (نفس الستايل الخاص بك مع تحسين الأنيميشن) ---
  Widget _buildMainFinancialStats(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
      builder: (context, snapshot) {
        double total = snapshot.hasData ? snapshot.data!.docs.fold(0.0, (s, d) => s + (d['totalAmount'] ?? 0)) : 0;
        return _largeMetricCard("إجمالي المبيعات", total, Icons.auto_graph_rounded, Colors.green, isDark);
      },
    );
  }

  Widget _buildProfitCard(bool isDark) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
      builder: (context, s1) => StreamBuilder(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, s2) {
          double sales = s1.hasData ? s1.data!.docs.fold(0.0, (s, d) => s + (d['totalAmount'] ?? 0)) : 0;
          double exp = s2.hasData ? s2.data!.docs.fold(0.0, (s, d) => s + (d['amount'] ?? 0)) : 0;
          return _largeMetricCard("صافي الربح", sales - exp, Icons.account_balance_wallet, Colors.blueAccent, isDark);
        },
      ),
    );
  }

  Widget _buildDeleteEverythingButton(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () => _showAdminPasswordDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            color: Colors.redAccent.withOpacity(0.05),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dangerous_outlined, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("تصفير شامل لقاعدة البيانات", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminPasswordDialog(BuildContext context) {
    final TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff0f172a),
        title: const Text("رمز تأكيد الإدارة", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: passController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "أدخل 7070", hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () { if(passController.text == "7070"){ Navigator.pop(context); _confirmFinalDeletion(context); } }, child: const Text("تأكيد")),
        ],
      ),
    );
  }

  void _confirmFinalDeletion(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("تأكيد نهائي"),
      content: const Text("هل أنت متأكد من مسح كافة السجلات؟ لا يمكن التراجع."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
        ElevatedButton(onPressed: () { Navigator.pop(context); _performErasure(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("امسح")),
      ],
    ));
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_awesome_motion_outlined, size: 50, color: Colors.grey.withOpacity(0.5)),
      const SizedBox(height: 10),
      const Text("لا توجد بيانات حالياً", style: TextStyle(color: Colors.grey)),
    ]));
  }

  Widget _buildOperationalStats(bool isDark) {
    return Row(children: [
      _buildCounterCard("أوامر الإنتاج", "work_orders", Icons.assignment, Colors.blue, isDark),
      const SizedBox(width: 12),
      _buildCounterCard("المصاريف", "expenses", Icons.payments, Colors.red, isDark),
    ]);
  }

  Widget _buildCounterCard(String title, String coll, IconData icon, Color color, bool isDark) {
    return Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coll).snapshots(),
      builder: (context, snap) {
        int count = snap.hasData ? snap.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text("$count", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        );
      },
    ));
  }

  Widget _largeMetricCard(String title, double value, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? color.withOpacity(0.05) : Colors.white,
        border: Border.all(color: isDark ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
          const SizedBox(width: 15),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("${value.toStringAsFixed(0)} ج.م", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSmartAlerts(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        var low = (snapshot.data?.docs ?? []).where((d) => (d['totalQuantity'] ?? 0) < 5).toList();
        if (low.isEmpty) return const SizedBox();
        return Container(
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Text("⚠️ تنبيه: يوجد ${low.length} منتجات أوشكت على النفاذ!", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      onSelected: (v) => setState(() => selectedFilter = v),
      itemBuilder: (c) => ["الكل", "اليوم", "هذا الشهر"].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
    );
  }
}