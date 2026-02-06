import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExecutiveReportsPage extends StatefulWidget {
  const ExecutiveReportsPage({super.key});

  @override
  State<ExecutiveReportsPage> createState() => _ExecutiveReportsPageState();
}

class _ExecutiveReportsPageState extends State<ExecutiveReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xff0f172a) : const Color(0xfff1f5f9);
    final Color cardColor = isDark ? const Color(0xff1e293b) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xff1e293b);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
        elevation: 0,
        title: Text("مركز التقارير التنفيذي", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 22)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 4,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "الموقف المالي العام", icon: Icon(Icons.account_balance)),
            Tab(text: "أداء فريق المبيعات", icon: Icon(Icons.groups)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- التبويب الأول: الموقف المالي ---
          _buildFinancialReportTab(isDark, cardColor, textColor),
          
          // --- التبويب الثاني: المناديب (مصحح 100%) ---
          _buildAgentsReportTab(isDark, cardColor, textColor),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. تبويب الموقف المالي (Financial Report)
  // ===========================================================================
  Widget _buildFinancialReportTab(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // كارت الخزنة (السيولة الحالية)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('vault').doc('main_vault').snapshots(),
            builder: (context, snapshot) {
              double balance = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                balance = (snapshot.data!['balance'] ?? 0).toDouble();
              }
              return _buildLuxuryGradientCard(
                "السيولة النقدية المتاحة", 
                balance, 
                Icons.account_balance_wallet, 
                [const Color(0xff10b981), const Color(0xff059669)],
              );
            },
          ),
          const SizedBox(height: 20),
          
          // صف المصروفات والمبيعات
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
                  builder: (context, snap) {
                    double total = snap.hasData ? snap.data!.docs.fold(0.0, (s, d) => s + (d['totalAmount'] ?? 0)) : 0;
                    return _buildStatCard("إجمالي المبيعات", total, Icons.trending_up, Colors.blue, cardColor, textColor);
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
                  builder: (context, snap) {
                    // هنا يتم جمع قيمة المصروفات (amount) وليس عددها
                    double total = snap.hasData ? snap.data!.docs.fold(0.0, (s, d) => s + (d['amount'] ?? 0)) : 0;
                    return _buildStatCard("إجمالي المصروفات", total, Icons.trending_down, Colors.redAccent, cardColor, textColor);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // كارت صافي الربح
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
            builder: (context, s1) => StreamBuilder(
              stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
              builder: (context, s2) {
                double sales = s1.hasData ? s1.data!.docs.fold(0.0, (s, d) => s + (d['totalAmount'] ?? 0)) : 0;
                double exp = s2.hasData ? s2.data!.docs.fold(0.0, (s, d) => s + (d['amount'] ?? 0)) : 0;
                return _buildLuxuryGradientCard(
                  "صافي الأرباح (Sales - Expenses)", 
                  sales - exp, 
                  Icons.monetization_on, 
                  [const Color(0xff6366f1), const Color(0xff4f46e5)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. تبويب المناديب (Agents Report) - المصحح
  // ===========================================================================
  Widget _buildAgentsReportTab(bool isDark, Color cardColor, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      // 1. جلب المستخدمين الذين لديهم "sales" داخل مصفوفة الـ role
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', arrayContains: 'sales')
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (userSnapshot.data!.docs.isEmpty) {
          return Center(child: Text("لا يوجد مناديب مسجلين", style: TextStyle(color: textColor)));
        }

        // 2. جلب كل الطلبات مرة واحدة لحساب المجموع لكل مندوب
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('agent_orders').snapshots(),
          builder: (context, orderSnapshot) {
            if (!orderSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            var users = userSnapshot.data!.docs;
            var orders = orderSnapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: users.length,
              itemBuilder: (context, index) {
                var userDoc = users[index];
                Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                
                String agentName = userData['username'] ?? "Unknown";
                String agentId = userDoc.id;
                // جلب التارجت من داتا المندوب، ولو مش موجود نعتبره رقم افتراضي
                double target = (userData['target'] ?? 50000).toDouble();

                // فلترة الطلبات الخاصة بهذا المندوب فقط وجمع قيمتها
                double totalSales = orders
                    .where((o) => o['agentId'] == agentId)
                    .fold(0.0, (sum, o) => sum + (o['totalAmount'] ?? 0).toDouble());

                double progress = target > 0 ? (totalSales / target) : 0;
                
                return _buildLuxuryAgentCard(agentName, totalSales, target, progress, isDark, cardColor, textColor);
              },
            );
          },
        );
      },
    );
  }

  // --- تصميم كارت المندوب الفاخر ---
  Widget _buildLuxuryAgentCard(String name, double sales, double target, double progress, bool isDark, Color cardColor, Color textColor) {
    Color progressColor = progress >= 1 ? Colors.green : (progress >= 0.5 ? Colors.orange : Colors.red);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: progressColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: progressColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: progressColor),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(progress >= 1 ? "هدف محقق 🏆" : "جاري العمل...", style: TextStyle(color: progressColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("${(progress * 100).toStringAsFixed(1)}%", style: TextStyle(color: progressColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // شريط التقدم المخصص
          Stack(
            children: [
              Container(height: 10, decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[200], borderRadius: BorderRadius.circular(10))),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: progressColor.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("المبيعات المحققة", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(currencyFormat.format(sales), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("الهدف المطلوب", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(currencyFormat.format(target), style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- تصميم كارت التدرج اللوني (للأرقام الكبيرة) ---
  Widget _buildLuxuryGradientCard(String title, double value, IconData icon, List<Color> colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Icon(Icons.more_horiz, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text(currencyFormat.format(value), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  // --- تصميم كارت الإحصائيات الصغير ---
  Widget _buildStatCard(String title, double value, IconData icon, Color iconColor, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(currencyFormat.format(value), 
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}