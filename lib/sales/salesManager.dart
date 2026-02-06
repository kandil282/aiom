import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesManagerDashboard extends StatefulWidget {
  const SalesManagerDashboard({super.key});

  @override
  State<SalesManagerDashboard> createState() => _SalesManagerDashboardState();
}

class _SalesManagerDashboardState extends State<SalesManagerDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- دالة مساعدة لضمان الأمان وعدم توقف التطبيق ---
  // هذه الدالة تتأكد إن الحقل موجود، ولو مش موجود بترجع 0
  double _safeGetAmount(Map<String, dynamic> data, String fieldName) {
    if (data.containsKey(fieldName) && data[fieldName] != null) {
      return (data[fieldName] as num).toDouble();
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xff0f172a) : const Color(0xfff8fafc);
    final Color textColor = isDark ? Colors.white : const Color(0xff1e293b);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 10),
            Text("غرفة عمليات المبيعات", style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 22)),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "لوحة الأبطال", icon: Icon(Icons.emoji_events)),
            Tab(text: "أداء الفريق", icon: Icon(Icons.speed)),
            Tab(text: "بث مباشر", icon: Icon(Icons.online_prediction)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(isDark), 
          _buildTeamPerformanceTab(isDark),
          _buildLiveOrdersFeed(isDark), 
        ],
      ),
    );
  }


Future<Map<String, double>> _getAgentDetailedStats(String agentId) async {
  double totalSales = 0;
  double totalCollections = 0;

  // --- أولاً: حساب المبيعات (من العملاء -> العمليات -> الفواتير) ---
  var customersSnap = await FirebaseFirestore.instance
      .collection('customers')
      .where('agentId', isEqualTo: agentId)
      .get();

  for (var customer in customersSnap.docs) {
    var transSnap = await customer.reference
        .collection('transactions')
        .where('type', isEqualTo: 'invoice')
        .get();

    for (var doc in transSnap.docs) {
      totalSales += (doc.data()['amount'] ?? 0).toDouble();
    }
  }

  // --- ثانياً: حساب التحصيلات (من 3 مصادر كما في كود المندوب) ---
  
  // 1. النقدي المؤكد
  var agentStream = await FirebaseFirestore.instance
      .collection('pending_collections')
      .where('agentId', isEqualTo: agentId)
      .where('status', isEqualTo: 'confirmed')
      .get();
  for (var doc in agentStream.docs) {
    totalCollections += (doc['amount'] ?? 0).toDouble();
  }

  // 2. التحصيل المباشر
  var directPayments = await FirebaseFirestore.instance
      .collection('payments')
      .where('agentId', isEqualTo: agentId)
      .where('type', isEqualTo: 'direct_collection')
      .get();
  for (var doc in directPayments.docs) {
    totalCollections += (doc['amount'] ?? 0).toDouble();
  }

  // 3. الشيكات المحصلة
  var cashedChecks = await FirebaseFirestore.instance
      .collection('checks')
      .where('employeeId', isEqualTo: agentId)
      .where('status', isEqualTo: 'cashed')
      .get();
  for (var doc in cashedChecks.docs) {
    var val = doc['amount'];
    totalCollections += (val is String) ? (double.tryParse(val) ?? 0) : (val ?? 0).toDouble();
  }

  return {
    'sales': totalSales,
    'collections': totalCollections,
  };
}
 
 
 
  // ===========================================================================
  // 1. تبويب لوحة الأبطال (The Podium) - (تم الإصلاح)
  // ===========================================================================
// 2. دالة بناء الواجهة (Leaderboard Tab)
  Widget _buildLeaderboardTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      // أولاً: نراقب قائمة المناديب
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', arrayContains: 'sales')
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnap.hasData || userSnap.data!.docs.isEmpty) {
          return const Center(child: Text("لا يوجد مناديب حالياً", style: TextStyle(color: Colors.white)));
        }

        // ثانياً: نحسب مبيعات كل مندوب بناءً على القائمة اللي جت لنا
        return FutureBuilder<List<Map<String, dynamic>>>(
// داخل FutureBuilder في دالة _buildLeaderboardTab
future: Future.wait(userSnap.data!.docs.map((userDoc) async {
  String uid = userDoc.id;
  Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
  
  // جلب البيانات المفصلة
  var stats = await _getAgentDetailedStats(uid);
  
  return {
    'uid': uid,
    'name': userData['username'] ?? 'مجهول',
    'total': stats['sales'],        // المبيعات (للترتيب)
    'collected': stats['collections'], // التحصيل (للعمولة)
    'target': (userData['target'] ?? 0).toDouble(),
  };
})),
          builder: (context, performanceSnap) {
            if (!performanceSnap.hasData) {
              return const Center(child: Text("جاري حساب الأرقام...", style: TextStyle(color: Colors.grey)));
            }

            // ترتيب البيانات: الأعلى مبيعات في الأول
            List<Map<String, dynamic>> agentsLeaderboard = performanceSnap.data!;
            agentsLeaderboard.sort((a, b) => b['total'].compareTo(a['total']));
            
            var top3 = agentsLeaderboard.take(3).toList();
            var remainingAgents = agentsLeaderboard.skip(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("🔥 المتصدرين حالياً 🔥", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const SizedBox(height: 30),
                  
                  // منصة التتويج (Top 3)
                  if (top3.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end, 
                      children: [
                        if (top3.length > 1) _buildPodiumPlace(top3[1], 2, 140, Colors.grey.shade400, isDark),
                        if (top3.isNotEmpty) _buildPodiumPlace(top3[0], 1, 180, Colors.amber, isDark),
                        if (top3.length > 2) _buildPodiumPlace(top3[2], 3, 110, Colors.brown.shade300, isDark),
                      ],
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // باقي المناديب في قائمة
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: remainingAgents.length,
                    itemBuilder: (context, index) {
                      var agent = remainingAgents[index];
                      return Card(
                        color: isDark ? const Color(0xff1e293b) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade800, 
                            child: Text("${index + 4}", style: const TextStyle(color: Colors.white, fontSize: 12))
                          ),
                          title: Text(agent['name'], 
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormat.format(agent['total']), 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          Text("تحصيل: ${currencyFormat.format(agent['collected'])}", 
                            style: const TextStyle(fontSize: 10, color: Colors.greenAccent)),
                          // مثال لحساب عمولة 1% من التحصيل
                          // Text("العمولة: ${currencyFormat.format(agent['collected'] * 0.01)}", 
                          //   style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double calculateSmartCommission(double sales, double collected, Map<String, dynamic> agentData) {
  double target = (agentData['target'] ?? 0).toDouble();
  double commissionRate = (agentData['commissionRate'] ?? 0).toDouble(); // مثلاً 0.02
  double minPercent = (agentData['minAchievementForCommission'] ?? 0).toDouble(); // مثلاً 0.80

  if (target <= 0) return 0; // لو مفيش تارجت مفيش حساب

  double achievementPercent = sales / target;

  // الشرط: لو حقق التارجت أو النسبة المطلوبة منه (مثلاً 80% منه)
  if (achievementPercent >= minPercent) {
    return collected * commissionRate; // العمولة بتتحسب من التحصيل
  } else {
    return 0; // محققش الحد الأدنى من التارجت
  }
}
  Widget _buildPodiumPlace(Map<String, dynamic> agent, int rank, double height, Color color, bool isDark) {
    return Column(
      children: [
        Icon(Icons.emoji_events_rounded, color: color, size: 30),
        const SizedBox(height: 5),
        Text(agent['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black)),
        Text(currencyFormat.format(agent['total']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black)),
        Text("تحصيل: ${currencyFormat.format(agent['collected'])}", 
      style: const TextStyle(fontSize: 10, color: Colors.greenAccent)),
      // Text("العمولة: ${currencyFormat.format(agent['collected'] * 0.01)}", 
      // style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15)],
          ),
          child: Center(
            child: Text("$rank", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. تبويب أداء الفريق (Detailed Stats) - (تم الإصلاح)
  // ===========================================================================
// دالة شاملة لحساب إجمالي المبيعات والتحصيلات للشركة
Future<Map<String, double>> _getCompanyWideStats() async {
  double totalCompanySales = 0;
  double totalCompanyCollections = 0;

  // 1. جلب كل المناديب عشان نلف عليهم
  var salesAgentsSnap = await FirebaseFirestore.instance
      .collection('users')
      .where('role', arrayContains: 'sales')
      .get();

  // 2. لكل مندوب، نجيب بياناته
  for (var agentDoc in salesAgentsSnap.docs) {
    String agentId = agentDoc.id;
    // هنا بنستخدم نفس دالة التحصيلات والمبيعات الفردية اللي عملناها قبل كده
    var agentStats = await _getAgentDetailedStats(agentId); // تأكد أن هذه الدالة موجودة عندك

    totalCompanySales += agentStats['sales']!;
    totalCompanyCollections += agentStats['collections']!;
  }

  return {
    'totalSales': totalCompanySales,
    'totalCollections': totalCompanyCollections,
  };
}


Widget _buildSummaryCard({
  required String title,
  required double total,
  required double target,
  required Color color,
  required IconData icon,
}) {
  double percent = target == 0 ? 0 : (total / target);
  return Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 16)),
            Icon(icon, color: color.withOpacity(0.8), size: 28),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          currencyFormat.format(total),
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (target > 0) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.3),
            color: percent >= 1 ? Colors.greenAccent : color,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("التحقيق: ${(percent * 100).toStringAsFixed(1)}%",
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
              Text("المطلوب: ${currencyFormat.format(target)}",
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
            ],
          ),
        ] else ...[
           const SizedBox(height: 5),
           Text("لا يوجد تارجت محدد", style: TextStyle(color: color.withOpacity(0.5), fontSize: 12)),
        ]
      ],
    ),
  );
}

// دالة المدير الجديدة
Widget _buildTeamPerformanceTab(bool isDark) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إجمالي أداء الشركة",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),

        // --- كروت الملخص (المبيعات والتحصيلات الكلية) ---
        FutureBuilder<Map<String, double>>(
          future: _getCompanyWideStats(), // الدالة الشاملة الجديدة
          builder: (context, companyStatsSnap) {
            if (companyStatsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!companyStatsSnap.hasData) {
              return const Text("لا توجد بيانات للشركة", style: TextStyle(color: Colors.grey));
            }

            // جلب التارجت الكلي للشركة (جمع تارجت كل المناديب)
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', arrayContains: 'sales').snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();

// التعديل في جزء الـ fold عشان نتجنب الـ Null
double totalCompanyTarget = userSnap.data!.docs.fold(0.0, (sum, doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  // نستخدم ?? 0 للضمان
  double targetValue = (data['target'] ?? 0).toDouble(); 
  return sum + targetValue;
});

                return Column(
                  children: [
                    _buildSummaryCard(
                      title: "إجمالي المبيعات",
                      total: companyStatsSnap.data!['totalSales'] ?? 0,
                      target: totalCompanyTarget, // هنا استخدم التارجت الكلي
                      color: Colors.blueAccent,
                      icon: Icons.shopping_bag_rounded,
                    ),
                    _buildSummaryCard(
                      title: "إجمالي التحصيلات",
                      total: companyStatsSnap.data!['totalCollections'] ?? 0,
                      target: totalCompanyTarget, // ممكن يكون ليها تارجت تحصيل منفصل لو حبيت
                      color: Colors.greenAccent,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 30),
        const Text("أداء المناديب الفردي",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),

        // --- قائمة المناديب (مع إمكانية تعديل التارجت) ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', arrayContains: 'sales').snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!userSnap.hasData || userSnap.data!.docs.isEmpty) {
              return const Center(child: Text("لا يوجد مناديب لعرضهم.", style: TextStyle(color: Colors.grey)));
            }

            // هنا بقى بنجيب الـ stats لكل مندوب
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: Future.wait(userSnap.data!.docs.map((userDoc) async {
                String uid = userDoc.id;
                Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                
                var stats = await _getAgentDetailedStats(uid);
                
                // عشان نمرر كل بيانات المندوب (بما فيها نسب العمولة) لدالة حساب العمولة
                userData['uid'] = uid; // نضيف الـ UID عشان يكون متاح في الداتا
                return {
                  'uid': uid,
                  'name': userData['username'] ?? 'مجهول',
                  'sales': stats['sales'] ?? 0,
                  'collected': stats['collections'] ?? 0,
                  'target': (userData['target'] ?? 0).toDouble(),
                  'fullData': userData, // نمرر كل بيانات المندوب
                };
              })),
              builder: (context, agentsStatsSnap) {
                if (!agentsStatsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Map<String, dynamic>> agentsPerformance = agentsStatsSnap.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: agentsPerformance.length,
                  itemBuilder: (context, index) {
                    var agent = agentsPerformance[index];
                    double achievementPercent = agent['target'] == 0 ? 0 : (agent['sales'] / agent['target']);
                    double commission = calculateSmartCommission(agent['sales'], agent['collected'], agent['fullData']);

                    return Card(
                      color: isDark ? const Color(0xff1e293b) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigoAccent,
                          child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(agent['name'],
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("مبيعات: ${currencyFormat.format(agent['sales'])} | تحصيل: ${currencyFormat.format(agent['collected'])}",
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                            LinearProgressIndicator(
                              value: achievementPercent,
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade700,
                              color: achievementPercent >= 1 ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            Text("التحقيق: ${(achievementPercent * 100).toStringAsFixed(1)}%",
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 10)),
                            commission > 0
                                ? Text("عمولة: ${currencyFormat.format(commission)}",
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))
                                : const Text("لم يحقق شرط العمولة",
                                    style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.grey),
                          onPressed: () => _openAgentSettingsSheet(context, agent['uid'], agent['fullData']),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

void _openAgentSettingsSheet(BuildContext context, String agentId, Map<String, dynamic> agentData) {
  // تعريف وحدات التحكم بالمدخلات مع القيم الحالية من قاعدة البيانات
  final TextEditingController targetController = TextEditingController(text: (agentData['target'] ?? 0).toString());
  final TextEditingController commissionRateController = TextEditingController(text: (agentData['commissionRate'] ?? 0).toString());
  final TextEditingController minAchievementController = TextEditingController(text: (agentData['minAchievementForCommission'] ?? 0).toString());

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B), // نفس لون الخلفية الداكنة لشاشتك
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط السحب الصغير فوق
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          
          Text(
            "تحديث أهداف: ${agentData['username'] ?? 'المندوب'}",
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),

          // 1. حقل التارجت
          _buildSettingsInput(
            controller: targetController,
            label: "تارجت المبيعات (ج.م)",
            hint: "مثلاً: 500000",
            icon: Icons.track_changes_rounded,
            color: Colors.blueAccent,
          ),

          // 2. حقل نسبة العمولة
          _buildSettingsInput(
            controller: commissionRateController,
            label: "نسبة العمولة (0.01 تعني 1%)",
            hint: "ادخل القيمة العشرية",
            icon: Icons.percent_rounded,
            color: Colors.greenAccent,
            isDecimal: true,
          ),

          // 3. حقل شرط تحقيق التارجت
          _buildSettingsInput(
            controller: minAchievementController,
            label: "شرط تفعيل العمولة (0.80 تعني 80%)",
            hint: "أدنى نسبة تحقيق ليأخذ المندوب عمولته",
            icon: Icons.verified_user_rounded,
            color: Colors.orangeAccent,
            isDecimal: true,
          ),

          const SizedBox(height: 30),

          // زر الحفظ
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 5,
            ),
            onPressed: () async {
              // تحديث بيانات المندوب في Firebase
              await FirebaseFirestore.instance.collection('users').doc(agentId).update({
                'target': double.tryParse(targetController.text) ?? 0,
                'commissionRate': double.tryParse(commissionRateController.text) ?? 0,
                'minAchievementForCommission': double.tryParse(minAchievementController.text) ?? 0,
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ تم حفظ التعديلات وتحديث نظام العمولات"),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("حفظ وتطبيق الإعدادات", 
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

// دالة مساعدة لتصميم حقول الإدخال بشكل احترافي
Widget _buildSettingsInput({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  required Color color,
  bool isDecimal = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        labelStyle: TextStyle(color: color.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    ),
  );
}
  // ===========================================================================
  // 3. تبويب البث المباشر (Live Feed)
  // ===========================================================================
Widget _buildLiveOrdersFeed(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    // البحث في جميع كولكشنز transactions الفرعية في السيستم كله
    stream: FirebaseFirestore.instance
        .collectionGroup('transactions') 
        .where('type', isEqualTo: 'invoice') // نجيب الفواتير بس
        .orderBy('date', descending: true)   // الترتيب حسب التاريخ (تأكد أن الحقل اسمه date عندك)
        .limit(50)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text("حدث خطأ: تأكد من عمل Index في Firebase"));
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(Icons.history_toggle_off, size: 50, color: Colors.grey),
              const SizedBox(height: 10),
              Text("لا توجد مبيعات مسجلة حتى الآن", style: TextStyle(color: Colors.grey))
            ]
          )
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: snapshot.data!.docs.length,
        itemBuilder: (context, index) {
          var doc = snapshot.data!.docs[index];
          var data = doc.data() as Map<String, dynamic>;
          
          // معالجة التاريخ بأمان
          DateTime date = DateTime.now();
          if (data['date'] != null) {
            date = (data['date'] as Timestamp).toDate();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1e293b) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              // تمييز الفواتير الكبيرة بلون مختلف (إضافة لمسة جمالية)
              border: Border(
                right: BorderSide(
                  color: (data['amount'] ?? 0) > 10000 ? Colors.amberAccent : Colors.greenAccent, 
                  width: 5
                )
              ),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
              ),
              title: Text(
                data['customerName'] ?? "عميل غير معروف", // تأكد من اسم الحقل في الترانزاكشن
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, 
                  fontWeight: FontWeight.bold,
                  fontSize: 15
                )
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "المندوب: ${data['agentName'] ?? 'غير محدد'}", 
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy/MM/dd - hh:mm a').format(date), 
                          style: const TextStyle(fontSize: 11, color: Colors.grey)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(data['amount'] ?? 0), 
                    style: TextStyle(
                      color: isDark ? Colors.greenAccent : Colors.green.shade700, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 17
                    )
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                ],
              ),
              onTap: () {
                // هنا ممكن تفتح تفاصيل الفاتورة لو حبيت
              },
            ),
          );
        },
      );
    },
  );
}

}