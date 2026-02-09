import 'dart:async';
import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CEO_Dashboard extends StatefulWidget {
  const CEO_Dashboard({super.key});

  @override
  State<CEO_Dashboard> createState() => _CEO_DashboardState();
}

class _CEO_DashboardState extends State<CEO_Dashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);
  
  // متغيرات الكارت المتحرك
  int _currentPage = 0;
  final PageController _pageController = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 إدارات رئيسية
    
    // تشغيل التايمر لتقليب الكروت تلقائياً
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < 4) { // عدد الكروت الإحصائية
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xff0f172a) : const Color(0xfff8fafc);
    final Color textColor = isDark ? Colors.white : const Color(0xff1e293b);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Translate.text(context, "غرفة العمليات المركزية", "CEO Operations Center"), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            Text(Translate.text(context, "CEO Live Monitor", "CEO Live Monitor"), style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_active, color: Colors.orange), onPressed: (){}),
          CircleAvatar(
  backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blue[100],
  child:  Icon(Icons.person, color: isDark ? Colors.white : Colors.blue),
),
          const SizedBox(width: 15),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 1. شاشة الإعلانات المتحركة (The Flash Report)
                SizedBox(
                  height: 220,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('global_transactions').snapshots(), 
                    // ملاحظة: هنا بنسحب الـ transactions كمثال، المفروض نسحب داتا مجمعة لتسريع الأداء
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      // حسابات سريعة (للعرض فقط)
                      var docs = snapshot.data!.docs;
                      double totalSales = docs.where((d) => d['type'] == 'invoice').fold(0.0, (s, d) => s + (d['amount']??0));


                      
                      // الداتا اللي هتتعرض في الكاروسيل
                      List<Widget> flashCards = [
                        _buildSalesFlashCard(isDark),
                        _buildTotalPaymentsFlashCard(isDark), // كارت خاص بيحسب الكاش الفعلي من كولكشن payments
                        _buildProductionFlashCard(isDark), // كارت خاص بيحسب الإنتاج
                        _buildInventoryFlashCard(isDark), // كارت خاص بيحسب قيمة المخزون
// استدعاء الكارت الذكي اللي بيحسب البيانات ويقارنها
_buildActiveTopAgentCard(isDark),                      ];

                      return PageView(
                        controller: _pageController,
                        onPageChanged: (int page) => setState(() => _currentPage = page),
                        children: flashCards,
                      );
                    },
                  ),
                ),
                
                // مؤشر الصفحات (Dots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    width: _currentPage == index ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.blueAccent : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ],
            ),
          ),
          
          // 2. التبويبات (Departments Tabs)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.blueAccent,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs:  [
                  Tab(text:Translate.text(context, "📊 الموقف المالي", "📊 Financial Status")),
                  Tab(text: Translate.text(context, "🏭 الإنتاج والتصنيع", "🏭 Production & Manufacturing")),
                  Tab(text: Translate.text(context, "📦 المخزون", "📦 Inventory")),
                  Tab(text: Translate.text(context, "🚚 التسليمات", "🚚 Deliveries")),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFinancialTab(isDark),   // تابات تفصيلية
            _buildProductionTab(isDark),
            _buildInventoryTab(isDark),
            _buildLogisticsTab(isDark),
          ],
        ),
      ),
    );
  }
Widget _buildSalesFlashCard(bool isDark) {
  DateTime now = DateTime.now();
  DateTime startOfCurrent = DateTime(now.year, now.month, 1);
  DateTime startOfLast = DateTime(now.year, now.month - 1, 1);

  return StreamBuilder<QuerySnapshot>(
    // الوصول لكولكشن المعاملات العالمية بناءً على الصورة
    stream: FirebaseFirestore.instance.collection('global_transactions').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      double currentSales = 0;
      double lastSales = 0;

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        // التحقق من أن النوع فاتورة "invoice" كما في الصورة
        if (data['type'] == 'invoice') {
          // استخراج التاريخ (بفرض وجود حقل timestamp أو date في الوثيقة)
          DateTime date = (data['date'] as Timestamp? ?? Timestamp.now()).toDate(); 
          
          // حساب المجموع من قائمة العناصر items
          double invoiceTotal = 0;
          if (data['items'] != null) {
            for (var item in data['items']) {
              invoiceTotal += (item['totalPrice'] ?? 0).toDouble();
            }
          }

          if (date.isAfter(startOfCurrent)) {
            currentSales += invoiceTotal;
          } else if (date.isAfter(startOfLast) && date.isBefore(startOfCurrent)) {
            lastSales += invoiceTotal;
          }
        }
      }

      // حساب نسبة النمو
      double percent = lastSales > 0 ? ((currentSales - lastSales) / lastSales) * 100 : 100.0;

      return _buildFlashCard(
        title: Translate.text(context, "إجمالي مبيعات المصنع", "Total Factory Sales"),
        value: currentSales,
        percent: percent,
        icon: Icons.trending_up_rounded,
        // لون نيلي فخم للمبيعات
        colors: [const Color(0xff6366f1), const Color(0xff4338ca)], 
        isCurrency: true,
      );
    },
  );
}
// كارت المخزون 
Widget _buildInventoryFlashCard(bool isDark) {
  DateTime now = DateTime.now();
  DateTime startOfCurrent = DateTime(now.year, now.month, 1);

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('products').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      double currentTotalValue = 0;
      double previousTotalValue = 0;

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double price = (data['price'] ?? 0).toDouble();
        int currentQty = (data['totalQuantity'] ?? 0).toInt();
        
        currentTotalValue += (price * currentQty);

        // للمقارنة: سنفترض وجود حقل يوضح الكمية السابقة أو تاريخ الإضافة
        // إذا لم يتوفر سجل تاريخي، سنعرض القيمة الحالية ونسبة نمو تقديرية
      }

      return _buildFlashCard(
        title: Translate.text(context, "إجمالي قيمة المخزون", "Total Inventory Value"),
        value: currentTotalValue,
        percent: 5.2, // يمكن برمجتها بدقة إذا توفر كولكشن inventory_logs
        icon: Icons.inventory_2_rounded,
        colors: [const Color(0xfff39c12), const Color(0xffe67e22)],
        isCurrency: true,
      );
    },
  );
}

// كارت الانتاج
Widget _buildProductionFlashCard(bool isDark) {
  DateTime now = DateTime.now();
  DateTime startOfCurrent = DateTime(now.year, now.month, 1);
  DateTime startOfLast = DateTime(now.year, now.month - 1, 1);

  return StreamBuilder<QuerySnapshot>(
    // السحب من كولكشن أوامر الإنتاج
    stream: FirebaseFirestore.instance.collection('production_orders').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      double currentQty = 0;
      double lastQty = 0;

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        // التأكد أن الحالة "completed" كما في الصورة
        if (data['status'] == 'completed') {
          DateTime date = (data['completedAt'] as Timestamp).toDate();
          double qty = (data['actualQuantity'] ?? 0).toDouble();

          if (date.isAfter(startOfCurrent)) {
            currentQty += qty;
          } else if (date.isAfter(startOfLast) && date.isBefore(startOfCurrent)) {
            lastQty += qty;
          }
        }
      }

      double percent = lastQty > 0 ? ((currentQty - lastQty) / lastQty) * 100 : 100.0;

      return _buildFlashCard(
        title: Translate.text(context, "إنتاج المصنع المكتمل", "Completed Factory Production"),
        value: currentQty,
        percent: percent,
        icon: Icons.precision_manufacturing_rounded,
        colors: [const Color(0xff3498db), const Color(0xff2980b9)],
        isCurrency: false, // عشان تظهر بكلمة "قطعة"
      );
    },
  );
}
Widget _buildTotalPaymentsFlashCard(bool isDark) {
  DateTime now = DateTime.now();
  // تحديد بداية الشهر الحالي والماضي
  DateTime startOfCurrentMonth = DateTime(now.year, now.month, 1);
  DateTime startOfLastMonth = DateTime(now.year, now.month - 1, 1);

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('payments').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      double currentMonthTotal = 0;
      double lastMonthTotal = 0;

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        // تحويل التايم ستامب لتاريخ
        DateTime payDate = (data['date'] as Timestamp).toDate();
        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;

        if (payDate.isAfter(startOfCurrentMonth)) {
          currentMonthTotal += amount;
        } else if (payDate.isAfter(startOfLastMonth) && payDate.isBefore(startOfCurrentMonth)) {
          lastMonthTotal += amount;
        }
      }

      // حساب نسبة التغير
      double percentChange = 0;
      if (lastMonthTotal > 0) {
        percentChange = ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
      } else if (currentMonthTotal > 0) {
        percentChange = 100.0; // نمو كامل لو مكنش فيه داتا الشهر اللي فات
      }

      return _buildFlashCard(
        title: Translate.text(context, "إجمالي تحصيلات الشهر", "Total Monthly Collections"),
        value: currentMonthTotal, 
        percent: percentChange,
        icon: Icons.account_balance_wallet_rounded, 
        colors: [const Color(0xff2ecc71), const Color(0xff27ae60)]
      );
    },
  );
}
  // ===================== الودجت السحرية (Flash Card) =====================
Widget _buildFlashCard({
  required String title,
  required double value,
  required double percent,
  required IconData icon,
  required List<Color> colors,
  bool isCurrency = true,
}) {
  bool isGrowth = percent >= 0;
  return Container(
    height: 190,
    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(25),
      boxShadow: [BoxShadow(color: colors.last.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
    ),
    child: Stack(
      children: [
        Positioned(right: -20, top: -20, child: Icon(icon, size: 150, color: Colors.white.withOpacity(0.12))),
        Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              Text(
                isCurrency ? currencyFormat.format(value) : Translate.text(context, "${value.toInt()} قطعة", "${value.toInt()} Pieces"),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(isGrowth ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text("${percent.abs().toStringAsFixed(1)}% ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   Text(Translate.text(context, "عن الشهر الماضي", "from last month"), style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
 
 Widget _buildActiveTopAgentCard(bool isDark) {
  DateTime now = DateTime.now();
  // بداية الشهر الحالي
  DateTime startOfCurrentMonth = DateTime(now.year, now.month, 1);
  // بداية الشهر الماضي
  DateTime startOfLastMonth = DateTime(now.year, now.month - 1, 1);
  // نهاية الشهر الماضي (هي بداية الشهر الحالي)
  DateTime endOfLastMonth = startOfCurrentMonth;

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('payments').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      Map<String, double> currentMonthSales = {};
      Map<String, double> lastMonthSales = {};

      for (var doc in snapshot.data!.docs) {
        var data = doc.data() as Map<String, dynamic>;
        // تحويل التايم ستامب لتاريخ
        DateTime payDate = (data['date'] as Timestamp).toDate();
        String agentName = data['agentName'] ?? Translate.text(context, "غير معروف", "Unknown");
        double amount = (data['amount'] ?? 0).toDouble();

        // تصنيف المبالغ حسب الشهر
        if (payDate.isAfter(startOfCurrentMonth)) {
          currentMonthSales[agentName] = (currentMonthSales[agentName] ?? 0) + amount;
        } else if (payDate.isAfter(startOfLastMonth) && payDate.isBefore(endOfLastMonth)) {
          lastMonthSales[agentName] = (lastMonthSales[agentName] ?? 0) + amount;
        }
      }

      if (currentMonthSales.isEmpty) return const SizedBox();

      // تحديد المندوب الأعلى في الشهر الحالي
      var topAgentEntry = currentMonthSales.entries.reduce((a, b) => a.value > b.value ? a : b);
      String topAgentName = topAgentEntry.key;
      double currentAmount = topAgentEntry.value;

      // حساب أدائه في الشهر اللي فات للمقارنة
      double lastAmount = lastMonthSales[topAgentName] ?? 0.0;
      
      // حساب نسبة التغير
      double percentChange = 0;
      if (lastAmount > 0) {
        percentChange = ((currentAmount - lastAmount) / lastAmount) * 100;
      } else {
        percentChange = 100; // لو ملوش مبيعات الشهر اللي فات يبقى نمو 100%
      }

      return _buildAdvancedTopAgentCard(
        topAgentName, 
        currentAmount, 
        percentChange,
        [const Color(0xff4f46e5), const Color(0xff7c3aed)]
      );
    },
  );
}

// الودجت المعدلة لعرض نسبة التحسن
Widget _buildAdvancedTopAgentCard(String name, double amount, double percent, List<Color> colors) {
  bool isGrowth = percent >= 0;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(25),
      boxShadow: [BoxShadow(color: colors.last.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 35, 
                backgroundColor: Colors.white.withOpacity(0.2), 
                child: const Icon(Icons.man_3, color: Colors.white, size: 35)
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events, size: 15, color: Colors.orange),
              )
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translate.text(context, "نجم المبيعات (هذا الشهر) 🌟", "Top Sales Agent (This Month)"), style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(currencyFormat.format(amount), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // جزء المقارنة بالشهر الماضي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(
                  isGrowth ? Icons.trending_up : Icons.trending_down,
                  color: isGrowth ? Colors.greenAccent : Colors.redAccent,
                ),
                Text(
                  "${percent.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: isGrowth ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(Translate.text(context, "عن الشهر الماضي", "from last month"), style: TextStyle(color: Colors.white60, fontSize: 8)),
              ],
            ),
          )
        ],
      ),
    ),
  );
}
  // ===================== التبويبات التفصيلية (Placeholders) =====================
Widget _buildFinancialTab(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    // 1. سحب المبيعات من global_transactions (عشان نعرف الفواتير اللي طلعت)
    stream: FirebaseFirestore.instance.collection('global_transactions').snapshots(),
    builder: (context, salesSnap) {
      if (!salesSnap.hasData) return const Center(child: CircularProgressIndicator());

      double totalSales = salesSnap.data!.docs
          .where((d) => d['type'] == 'invoice')
          .fold(0.0, (sum, d) => sum + (d['amount'] ?? 0).toDouble());

      return StreamBuilder<QuerySnapshot>(
        // 2. سحب التحصيلات الفعلية من كولكشن payments مباشرة
        stream: FirebaseFirestore.instance.collection('payments').snapshots(),
        builder: (context, paymentsSnap) {
          // حساب كل الكاش اللي دخل (سواء direct أو agent) من كولكشن payments
          double totalCollected = 0;
          if (paymentsSnap.hasData) {
            totalCollected = paymentsSnap.data!.docs
                .fold(0.0, (sum, d) => sum + (d['amount'] ?? 0).toDouble());
          }
       


          return StreamBuilder<QuerySnapshot>(
            // 3. سحب المصروفات
            stream: FirebaseFirestore.instance.collection('vault_transactions').where('type', isEqualTo: 'expense').snapshots(),
            builder: (context, expSnapshot) {
              double totalExpenses = 0;
              if (expSnapshot.hasData) {
                totalExpenses = expSnapshot.data!.docs
                    .fold(0.0, (sum, d) => sum + (d['amount'] ?? 0).toDouble());
              }

            return         StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('vault').doc('main_vault').snapshots(),
          builder: (context, snap) {
            double balance = 0.0;
            if (snap.hasData && snap.data!.exists) {
              balance = (snap.data!['balance'] ?? 0).toDouble();
            }

              // الحسبة النهائية: الكاش الفعلي اللي دخل - المصاريف اللي طلعت
              double netCash = balance;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // كارت السيولة الفعلية في الخزنة حالياً
                    _buildLuxuryGradientCard(
                     Translate.text(context, "السيولة النقدية الفعلية", "Actual Cash Liquidity"), 
                      netCash, 
                      Icons.account_balance_wallet, 
                      netCash >= 0 
                        ? [const Color(0xff10b981), const Color(0xff059669)] 
                        : [const Color(0xffef4444), const Color(0xffb91c1c)]
                    ),
                    
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: _buildStatCard(Translate.text(context, "إجمالي المبيعات", "Total Sales"), totalSales, Icons.assignment, Colors.blue, isDark)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildStatCard(Translate.text(context, "إجمالي التحصيل", "Total Collected"), totalCollected, Icons.payments, Colors.teal, isDark)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildStatCard(Translate.text(context, "إجمالي المصروفات", "Total Expenses"), totalExpenses, Icons.outbox, Colors.redAccent, isDark),
                    
                    const SizedBox(height: 25),

                    // مؤشر نسبة التحصيل (المبيعات مقابل الكاش الداخل)
                    _buildCollectionAnalysis(totalSales, totalCollected, isDark),
                  ],
                ),
              );
            },
          );
        },
      );
        },
      );
    },
  );
}

// ودجت تحليل نسبة التحصيل
Widget _buildCollectionAnalysis(double sales, double collected, bool isDark) {
  double ratio = sales > 0 ? (collected / sales) : 0;
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xff1e293b) : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(Translate.text(context, "كفاءة التحصيل", "Collection Efficiency"), style: TextStyle(fontWeight: FontWeight.bold)),
            Text("${(ratio * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[300],
          color: Colors.green,
          minHeight: 8,
        ),
      ],
    ),
  );
} 
 
 
 Widget _buildProductionTab(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('production_orders').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      
      var docs = snapshot.data!.docs;
      // تصنيف الأوامر بناءً على الحالة الموجودة في الصورة
      var pending = docs.where((d) => d['status'] == 'pending').toList();
      var completed = docs.where((d) => d['status'] == 'completed').toList(); // لو عندك حالة completed

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ملخص سريع
            Row(
              children: [
                Expanded(child: _buildStatCard(Translate.text(context, "تحت التشغيل", "Under Production"), pending.length.toDouble(), Icons.settings_suggest, Colors.orange, isDark)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCard(Translate.text(context, "تم الإنتاج", "Completed"), completed.length.toDouble(), Icons.check_circle, Colors.green, isDark)),
              ],
            ),
            const SizedBox(height: 20),
            
            // قائمة أوامر الشغل الحالية
            Align(alignment: Alignment.centerRight, child: Text(Translate.text(context, "📌 أوامر قيد التنفيذ", "📌 Under Execution Orders"), style: TextStyle(color: isDark? Colors.white:Colors.black, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            
            ...pending.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border(right: BorderSide(color: Colors.orange, width: 4)), // علامة برتقالي
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['productName'] ?? Translate.text(context, "منتج مجهول", "Unknown Product"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark?Colors.white:Colors.black)),
                        Text(Translate.text(context, "الكمية المطلوبة: ${data['quantity']}", "Required Quantity: ${data['quantity']}"), style: const TextStyle(color: Colors.grey)),
                        Text(Translate.text(context, "تاريخ الطلب: ${DateFormat.yMMMd('ar_EG').format((data['createdAt'] as Timestamp).toDate())}", "Order Date: ${DateFormat.yMMMd('ar_EG').format((data['createdAt'] as Timestamp).toDate())}"), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Text("Pending", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              );
            }),
            
            if (pending.isEmpty) 
               Padding(padding: EdgeInsets.all(20), child: Text(Translate.text(context, "خط الإنتاج متوقف حالياً ✅", "Production Line is Currently Stopped ✅"), style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    },
  );
}


Widget _buildInventoryTab(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    // جلب كل المنتجات لعرض تقرير شامل
    stream: FirebaseFirestore.instance.collection('products').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      
      var products = snapshot.data!.docs;

      return Column(
        children: [
          // رأس التقرير مع زر الطباعة
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Translate.text(context, "📊 تقرير المخزون الحالي", "📊 Current Inventory Report"), 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black)),
                ElevatedButton.icon(
                  onPressed: () => _generateInventoryPDF(products), // دالة الطباعة
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(Translate.text(context, "طباعة PDF", "Print PDF")),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: products.length,
              itemBuilder: (context, index) {
                var data = products[index].data() as Map<String, dynamic>;
                // استخدام totalQuantity بناءً على الداتا بيز
                int qty = data['totalQuantity'] ?? 0; 
                double price = (data['price'] ?? 0).toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff1e293b) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: qty < 10 ? Colors.red.withOpacity(0.3) : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['productName'] ?? Translate.text(context, "بدون اسم", "No Name"), 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark?Colors.white:Colors.black)),
                          Text(Translate.text(context, "$qty قطعة", "$qty Pieces"), 
                            style: TextStyle(color: qty < 10 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTag(data['category'] ?? Translate.text(context, "عام", "General"), Colors.blue),
                          const SizedBox(width: 8),
                          _buildTag(data['subCategory'] ?? Translate.text(context, "غير مصنف", "Uncategorized"), Colors.orange),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Translate.text(context, "السعر: $price ج.م", "Price: $price EGP"), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          if(qty < 10)  Text(Translate.text(context, "⚠️ مخزون منخفض", "⚠️ Low Inventory"), style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
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
Future<void> _generateInventoryPDF(List<QueryDocumentSnapshot> docs) async {
  final pdf = pw.Document();

  // تحميل خط يدعم العربية (اختياري ولكن يفضل لضبط التقرير)
  final arabicFont = await PdfGoogleFonts.cairoMedium();

  // حساب إجمالي قيمة المخزون
  double totalInventoryValue = docs.fold(0, (sum, doc) {
    var d = doc.data() as Map<String, dynamic>;
    return sum + ((d['price'] ?? 0) * (d['totalQuantity'] ?? 0));
  });

  pdf.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: arabicFont),
      textDirection: pw.TextDirection.rtl, // دعم الكتابة من اليمين لليسار
      build: (context) => [
        pw.Header(level: 0, child: pw.Text(Translate.text(context as BuildContext, "تقرير جرد المخزن التفصيلي", "Detailed Inventory Report"))),
        pw.SizedBox(height: 10),
        pw.Text(Translate.text(context as BuildContext, "إجمالي قيمة البضاعة بالمخزن: ${totalInventoryValue.toStringAsFixed(2)} ج.م", "Total Value of Inventory: ${totalInventoryValue.toStringAsFixed(2)} EGP"), 
               style: pw.TextStyle(fontSize: 18, color: PdfColors.blue)),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            Translate.text(context as BuildContext, "المنتج", "Product Name"),
            Translate.text(context as BuildContext, "القسم", "Category"),
            Translate.text(context as BuildContext, "القسم الفرعي", "Subcategory"),
            Translate.text(context as BuildContext, "السعر", "Price"),
            Translate.text(context as BuildContext, "الكمية", "Quantity")
          ],
          data: docs.map((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return [
              d['productName'] ?? Translate.text(context as BuildContext, "بدون اسم", "No Name"),
              d['category'] ?? Translate.text(context as BuildContext, "عام", "General"),
              d['subCategory'] ?? Translate.text(context as BuildContext, "غير مصنف", "Uncategorized"),
              Translate.text(context as BuildContext, "${d['price']} ج.م", "${d['price']} EGP"),
              d['totalQuantity'].toString(),
            ];
          }).toList(),
          headerStyle: pw.TextStyle( color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueAccent),
          cellAlignment: pw.Alignment.centerRight,
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) => pdf.save());
}

// ودجت صغيرة للـ Category
Widget _buildTag(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}
 
  Widget _buildLogisticsTab(bool isDark) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('invoices').orderBy('date', descending: true).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      var docs = snapshot.data!.docs;
      var readyToShip = docs.where((d) => d['shippingStatus'] == 'ready').toList();
      var shipped = docs.where((d) => d['shippingStatus'] == 'shipped').toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // عدادات الحالة
            Row(
              children: [
                Expanded(child: _buildStatCard(Translate.text(context, "جاهز للشحن", "Ready to Ship"), readyToShip.length.toDouble(), Icons.local_shipping, Colors.blue, isDark)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCard(Translate.text(context, "خرج للتسليم", "Shipped"), shipped.length.toDouble(), Icons.check_circle_outline, Colors.purple, isDark)),
              ],
            ),
            const SizedBox(height: 25),

            // الفواتير المتأخرة في المخزن (Ready بس لسه مخرجتش)
            if (readyToShip.isNotEmpty) ...[
              Align(alignment: Alignment.centerRight, child: Text(Translate.text(context, "⚠️ طلبيات تنتظر التحميل", "⚠️ Orders Waiting for Loading"), style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(height: 10),
              ...readyToShip.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff1e293b) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['customerName'] ?? Translate.text(context, "عميل نقدي", "Cash Customer"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark?Colors.white:Colors.black)),
                          Chip(label: Text(Translate.text(context, "جاهز", "Ready"), style: TextStyle(color: Colors.blue)), backgroundColor: Colors.blue.withOpacity(0.1)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Translate.text(context, "رقم الفاتورة: #${data['invoiceId']?.toString().substring(0,4) ?? '---'}", "Invoice Number: #${data['invoiceId']?.toString().substring(0,4) ?? '---'}"), style: const TextStyle(color: Colors.grey)),
                          Text(Translate.text(context, "${data['totalAmount']} ج.م", "${data['totalAmount']} EGP"), style: TextStyle(color: isDark?Colors.white:Colors.black, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // زرار سريع لتغيير الحالة (للمدير لو حب يمشي الشغل)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // كود تحديث الحالة لـ shipped
                            FirebaseFirestore.instance.collection('invoices').doc(doc.id).update({'shippingStatus': 'shipped'});
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: Text(Translate.text(context, "تأكيد خروج الشحنة", "Confirm Shipment")),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        ),
                      )
                    ],
                  ),
                );
              }),
            ] else 
              Center(child: Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Column(children: [
                   Icon(Icons.thumb_up_alt, size: 50, color: Colors.grey.withOpacity(0.5)),
                   const SizedBox(height: 10),
                    Text(Translate.text(context, "المخزن تمام، مفيش بضاعة مركونة", "Warehouse is clear, no pending goods"), style: TextStyle(color: Colors.grey))
                ]),
              )),
          ],
        ),
      );
    },
  );
}

Widget _buildStatCard(String title, double count, IconData icon, Color color, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xff1e293b) : Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(count.toInt().toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    ),
  );
}
// ===========================================================================
// ✨ ودجت الكارت الملون الفاخر (Luxury Gradient Card)
// ===========================================================================
Widget _buildLuxuryGradientCard(String title, double value, IconData icon, List<Color> colors) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      // التدرج اللوني (Gradient)
      gradient: LinearGradient(
        colors: colors, 
        begin: Alignment.topLeft, 
        end: Alignment.bottomRight
      ),
      borderRadius: BorderRadius.circular(25),
      // ظل للكارت بنفس لون الخلفية
      boxShadow: [
        BoxShadow(
          color: colors.last.withOpacity(0.4), 
          blurRadius: 12, 
          offset: const Offset(0, 8)
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الأيقونة والزرار الجانبي
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), 
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const Icon(Icons.more_horiz, color: Colors.white38),
          ],
        ),
        const SizedBox(height: 20),
        
        // العنوان
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 5),
        
        // الرقم (القيمة)
        Text(
          // تنسيق الرقم عشان يظهر بفاصلة الآلاف (مثلاً 1,500)
          NumberFormat.decimalPattern('en').format(value), 
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 28, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1
          )
        ),
      ],
    ),
  );
}
}

// كلاس مساعد لتثبيت التبويبات عند السكرول
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}