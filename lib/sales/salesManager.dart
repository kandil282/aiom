import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // لتشغيل الواتساب
import 'package:intl/intl.dart'; // لتنسيق التاريخ والأرقام

class SalesManagerProDashboard extends StatefulWidget {
  const SalesManagerProDashboard({super.key});

  @override
  State<SalesManagerProDashboard> createState() => _SalesManagerProDashboardState();
}

class _SalesManagerProDashboardState extends State<SalesManagerProDashboard> {
  final double defaultMonthlyTarget = 50000.0; // تارجت افتراضي لو لم يتم تعيينه

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xff020617) : const Color(0xfff8fafc),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark), // App Bar بتصميم احترافي
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("نظرة عامة على الأداء", isDark),
                  _buildDynamicTopMetrics(isDark), // كروت KPIs
                  
                  const SizedBox(height: 30),
                  _buildSectionHeader("تتبع أهداف المناديب", isDark),
                  _buildAgentTargetProgress(isDark), // تقدم الأهداف
                  
                  const SizedBox(height: 30),
                  _buildSectionHeader("أكثر المنتجات مبيعاً", isDark),
                  _buildDynamicProductHeatmap(isDark), // المنتجات الرائجة
                  
                  const SizedBox(height: 30),
                  _buildSectionHeader("تنبيهات ومتابعات", isDark),
                  _buildAgentAlerts(isDark), // تنبيهات الواتساب
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- بناء الـ AppBar الفخم ---
  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent, // لجعل التدرج هو الخلفية
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
        title: const Text("رؤى مبيعات استراتيجية", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [const Color(0xff1e1b4b), const Color(0xff312e81)] 
                : [const Color(0xff60a5fa), const Color(0xff3b82f6)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Icon(Icons.analytics_outlined, color: Colors.white.withOpacity(0.3), size: 100),
            ),
          ),
        ),
      ),
    );
  }

  // --- كروت مؤشرات الأداء الرئيسية (KPIs) الديناميكية ---
  Widget _buildDynamicTopMetrics(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        double totalSales = 0;
        double todaySales = 0;
        double currentMonthSales = 0;
        DateTime now = DateTime.now();
        DateTime startOfMonth = DateTime(now.year, now.month, 1);
        DateTime startOfDay = DateTime(now.year, now.month, now.day);

        for (var doc in snapshot.data!.docs) {
          double amt = (doc['totalAmount'] ?? 0).toDouble();
          Timestamp? ts = doc['createdAt'] as Timestamp?;
          
          if (ts != null) {
            DateTime dt = ts.toDate();
            totalSales += amt; // إجمالي المبيعات

            // مبيعات اليوم
            if (dt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && dt.isBefore(startOfDay.add(const Duration(days: 1)))) {
              todaySales += amt;
            }
            // مبيعات الشهر الحالي
            if (dt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && dt.isBefore(startOfMonth.add(const Duration(days: 31)))) {
              currentMonthSales += amt;
            }
          }
        }
        
        // تنسيق الأرقام بالجنيه المصري
        final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildGlassCard(
              "إجمالي المبيعات", 
              currencyFormatter.format(totalSales), 
              Icons.trending_up, 
              Colors.green, 
              isDark
            ),
            _buildGlassCard(
              "مبيعات اليوم", 
              currencyFormatter.format(todaySales), 
              Icons.flash_on, 
              Colors.orange, 
              isDark
            ),
            _buildGlassCard(
              "مبيعات الشهر", 
              currencyFormatter.format(currentMonthSales), 
              Icons.calendar_month, 
              Colors.blue, 
              isDark
            ),
             _buildGlassCard(
              "متوسط قيمة الطلب", 
              currencyFormatter.format(totalSales > 0 ? totalSales / snapshot.data!.docs.length : 0), 
              Icons.receipt_long, 
              Colors.purple, 
              isDark
            ),
          ],
        );
      },
    );
  }

  // --- لوحة تقدم أهداف المناديب ---
  Widget _buildAgentTargetProgress(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', arrayContains: 'sales').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
          builder: (context, orderSnap) {
            if (!userSnap.hasData || !orderSnap.hasData) return const Center(child: CircularProgressIndicator());

            final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

            return Container(
              padding: const EdgeInsets.all(15),
              decoration: _glassDecoration(isDark),
              child: Column(
                children: userSnap.data!.docs.map((u) {
                  double sales = orderSnap.data!.docs
                      .where((o) => o['agentId'] == u.id)
                      .fold(0.0, (s, d) => s + (d['totalAmount'] ?? 0).toDouble());
                  
                  double target = (u.data() as Map).containsKey('target') ? (u['target'] ?? defaultMonthlyTarget).toDouble() : defaultMonthlyTarget;
                  double percent = (sales / target).clamp(0.0, 1.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: InkWell( // لجعل الكارت قابل للضغط لتعديل التارجت
                      onTap: () => _showTargetSetter(context, u.id, u['username']),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(u['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                "${currencyFormatter.format(sales)} / ${currencyFormatter.format(target)}",
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 10,
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              color: percent >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              "${(percent * 100).toStringAsFixed(1)}% من الهدف",
                              style: TextStyle(fontSize: 10, color: percent >= 1.0 ? Colors.green : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  // --- تحليل المنتجات الأكثر طلباً (Product Heatmap) ---
  Widget _buildDynamicProductHeatmap(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        Map<String, int> productFrequency = {};
        for (var doc in snapshot.data!.docs) {
          List items = doc['items'] ?? []; // افترض أن الطلب يحتوي على قائمة items
          for (var item in items) {
            String name = item['productName'] ?? "غير معروف"; // اسم المنتج من الـ item
            productFrequency[name] = (productFrequency[name] ?? 0) + 1;
          }
        }

        var sorted = productFrequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.primaries[index % Colors.primaries.length].shade400,
                      Colors.primaries[index % Colors.primaries.length].shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${sorted[index].value}", 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                    const Text("طلب", style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 8),
                    Text(
                      sorted[index].key, 
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), 
                      textAlign: TextAlign.center, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- تنبيهات المناديب (واتساب ومتابعة) ---
  Widget _buildAgentAlerts(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', arrayContains: 'sales').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
          builder: (context, orderSnap) {
            if (!userSnap.hasData || !orderSnap.hasData) return const Center(child: CircularProgressIndicator());

            Map<String, Map<String, String>> agentsInfo = {
              for (var d in userSnap.data!.docs) 
                d.id: {
                  'name': d['username'] ?? "مجهول",
                  'phone': d['phone'] ?? "" // افترض وجود حقل phone للمندوب
                }
            };
            
            // حساب مبيعات الشهر الحالي لكل مندوب
            Map<String, double> currentMonthSales = {};
            DateTime now = DateTime.now();
            DateTime startOfMonth = DateTime(now.year, now.month, 1);

            for (var doc in orderSnap.data!.docs) {
              Timestamp? ts = doc['createdAt'] as Timestamp?;
              if (ts != null) {
                DateTime dt = ts.toDate();
                if (dt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && dt.isBefore(startOfMonth.add(const Duration(days: 31)))) {
                  String id = doc['agentId'] ?? "";
                  if (agentsInfo.containsKey(id)) {
                    String name = agentsInfo[id]!['name']!;
                    currentMonthSales[name] = (currentMonthSales[name] ?? 0) + (doc['totalAmount'] ?? 0).toDouble();
                  }
                }
              }
            }

            List<Widget> alertWidgets = [];

            // 1. تنبيه للمناديب اللي محققوش أي مبيعات هذا الشهر
            List<String> inactiveAgents = agentsInfo.values
                .where((info) => !currentMonthSales.containsKey(info['name']))
                .map((info) => info['name']!)
                .toList();

            if (inactiveAgents.isNotEmpty) {
              alertWidgets.add(_buildAlertCard(
                title: "مناديب لم يبدأوا بعد هذا الشهر",
                subtitle: "تحتاج لمتابعة لضمان بدء النشاط.",
                icon: Icons.person_off_rounded,
                color: Colors.redAccent,
                isDark: isDark,
                actionWidgets: inactiveAgents.map((name) {
                  String? phone = agentsInfo.entries.firstWhere((e) => e.value['name'] == name, orElse: () => MapEntry("", {})).value['phone'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                        if (phone != null && phone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.green),
                            onPressed: () => _launchWhatsApp(phone, name),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ));
              alertWidgets.add(const SizedBox(height: 20));
            }

            // 2. تنبيه للمناديب اللي حققوا 100% من التارجت (احتفال)
            List<String> achievers = [];
            for (var userDoc in userSnap.data!.docs) {
              String userId = userDoc.id;
              String userName = userDoc['username'];
              double sales = currentMonthSales[userName] ?? 0;
              double target = (userDoc.data() as Map).containsKey('target') ? (userDoc['target'] ?? defaultMonthlyTarget).toDouble() : defaultMonthlyTarget;
              if (target > 0 && sales >= target) {
                achievers.add(userName);
              }
            }

            if (achievers.isNotEmpty) {
              alertWidgets.add(_buildAlertCard(
                title: "تهانينا! حققوا هدفهم 🎉",
                subtitle: "هؤلاء المناديب تجاوزوا التارجت لهذا الشهر.",
                icon: Icons.celebration_rounded,
                color: Colors.green,
                isDark: isDark,
                actionWidgets: achievers.map((name) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text("• $name", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                )).toList(),
              ));
              alertWidgets.add(const SizedBox(height: 20));
            }

            if (alertWidgets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _glassDecoration(isDark),
                child: const Text("كل شيء تحت السيطرة! لا توجد تنبيهات حالياً.", style: TextStyle(color: Colors.grey)),
              );
            }

            return Column(children: alertWidgets);
          },
        );
      },
    );
  }

  // --- دوال مساعدة للتصميم ---

  BoxDecoration _glassDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
    );
  }

  Widget _buildGlassCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: _glassDecoration(isDark).copyWith(
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark ? [] : [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(right: -10, bottom: -10, child: Icon(icon, size: 60, color: color.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                Text("ج.م", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueGrey.shade900)),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    List<Widget>? actionWidgets,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassDecoration(isDark).copyWith(
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isDark ? [] : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 12)),
          if (actionWidgets != null && actionWidgets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...actionWidgets,
          ],
        ],
      ),
    );
  }

  // --- دالة فتح الواتساب ---
  void _launchWhatsApp(String? phone, String name) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف لهذا المندوب.")));
      return;
    }
    String message = "أهلاً يا $name، لاحظت عدم وجود مبيعات مسجلة باسمك هذا الشهر. هل توجد أي تحديات أقدر أساعدك فيها؟";
    var url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يمكن فتح تطبيق واتساب.")));
    }
  }

  // --- دالة إعداد التارجت (Modal Bottom Sheet) ---
  void _showTargetSetter(BuildContext context, String userId, String userName) {
    TextEditingController targetController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // للسماح للكيبورد بالظهور
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ليأخذ الحجم الأدنى
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("تحديد هدف مبيعات: $userName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.track_changes_rounded, color: Colors.blueAccent),
                hintText: "أدخل القيمة المستهدفة (مثلاً 50000)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
              ),
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                if (targetController.text.isNotEmpty) {
                  _updateAgentTarget(userId, double.parse(targetController.text));
                  Navigator.pop(context); // إغلاق الـ Bottom Sheet
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم تحديث الهدف بنجاح!")));
                }
              },
              child: const Text("حفظ الهدف الجديد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // دالة لتحديث التارجت في Firestore
  Future<void> _updateAgentTarget(String userId, double newTarget) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'target': newTarget});
  }
}
// ```http://googleusercontent.com/image_generation_content/0



// ### ملخص لأهم ميزات هذه النسخة:

// * **تصميم جمالي عصري (Glassmorphism & Gradients):** استخدام تدرجات الألوان والشفافية لإعطاء مظهر احترافي وفاخر.
// * **SliverAppBar مخصص:** يوفر تجربة تمرير سلسة وجميلة.
// * **كل البيانات ديناميكية:** جميع المؤشرات والرسوم البيانية تسحب البيانات مباشرة من Firestore.
// * **لوحة أهداف تفاعلية:** يمكن للمدير الضغط على اسم المندوب لتعديل هدفه الشهري بسهولة عبر Bottom Sheet أنيقة.
// * **Product Heatmap ذكي:** يعرض المنتجات الأكثر طلباً بتصميم جذاب.
// * **نظام تنبيهات متكامل:**
//     * يعرض المناديب الذين لم يبدأوا مبيعاتهم بعد هذا الشهر مع زر واتساب مباشر.
//     * يحتفل بالمناديب الذين حققوا أهدافهم.
// * **استخدام `intl` لتنسيق العملة:** لعرض الأرقام بالجنيه المصري بشكل احترافي.

// هذه الصفحة ستوفر لمدير المبيعات رؤية شاملة وعميقة لأداء فريقه وسوق المنتجات، مع أدوات تفاعلية لاتخاذ القرارات بسرعة وكفاءة.http://googleusercontent.com/image_generation_content/1