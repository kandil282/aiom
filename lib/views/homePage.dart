import 'package:aiom/accountant/AccountsSettlementPage.dart';
import 'package:aiom/accountant/AddProductPage.dart';
import 'package:aiom/accountant/CustomerAccountsPage.dart';
import 'package:aiom/accountant/CustomerPrintStatementPage.dart';
import 'package:aiom/accountant/ExpensesPage.dart';
import 'package:aiom/accountant/InvoicePage.dart';
import 'package:aiom/accountant/RawMaterialsInventoryPage.dart';
import 'package:aiom/accountant/SuppliersAccountsPage.dart';
import 'package:aiom/accountant/accountantApprovalPage.dart';
import 'package:aiom/accountant/warehouses.dart';
import 'package:aiom/configer/CompanySettingsPage.dart';
import 'package:aiom/configer/settingPage.dart';
import 'package:aiom/configer/settings_provider.dart';
import 'package:aiom/management/MaterialRequestArchivePage.dart';
import 'package:aiom/management/ReportsDashboard.dart';
import 'package:aiom/management/hrMasterPage.dart';
import 'package:aiom/partners/AddPartnerPage.dart';
import 'package:aiom/production/CreateProductionOrderPage.dart';
import 'package:aiom/production/MaterialRequestPage.dart';
import 'package:aiom/production/ProductionPage.dart';
import 'package:aiom/sales/CreateOrderPage.dart';
import 'package:aiom/sales/salesManagement.dart';
import 'package:aiom/sales/salesManager.dart' hide BusinessExecutiveDashboard;
import 'package:aiom/shipping/CourierPage.dart';
import 'package:aiom/shipping/CourierReportsPage.dart';
import 'package:aiom/shipping/ShippingManagerPage.dart';
import 'package:aiom/storages/PurchaseOrderPage.dart';
import 'package:aiom/storages/StorageDashboard.dart';
import 'package:aiom/storages/WarehouseDispatchPage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// استيراد كافة الصفحات الخاصة بك (تأكد من صحة المسارات لديك)
// import 'package:aiom/shipping/CourierPage.dart'; ... إلخ

class HomePage extends StatefulWidget {
  final String userName;
  final String email;

  const HomePage({
    super.key,
    required this.userName,
    required this.email, required List<dynamic> roles,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // متغير لتخزين صلاحيات المستخدم
  Map<String, dynamic>? userPermissions;
  bool isLoading = true;

                  bool get hasPermission => userPermissions?[permissionKey] ?? false;
                  
                    static Null get permissionKey => null;
  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }
Widget _buildAnimatedAction({required IconData icon, required VoidCallback onTap, Color iconColor = Colors.white}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: IconButton(
      icon: Icon(icon, color: iconColor, size: 22),
      onPressed: onTap,
    ),
  );
}
  // جلب الصلاحيات من الفايربيز
  Future<void> _loadUserPermissions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          userPermissions = doc.data()?['permissions'] ?? {};
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xff0f172a))));
    }

    return Scaffold(
backgroundColor: Theme.of(context).scaffoldBackgroundColor,appBar: AppBar(
  toolbarHeight: 80, // زيادة الطول ليعطي فخامة
  leading: IconButton(
    icon: const Icon(Icons.settings_suggest_rounded, size: 28), // أيقونة أحدث
    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsPage())),
  ),
  title: Column(
    children: [
      const Text(
        "لوحة التحكم الذكية",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.1),
      ),
      // زخرفة بسيطة تحت النص
      Container(
        height: 2,
        width: 40,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(10),
        ),
      )
    ],
  ),
  centerTitle: true,
  backgroundColor: Colors.transparent, // لجعل التدرج يظهر
  elevation: 0,
  // --- الجزء الخرافي (الخلفية والزخرفة) ---
flexibleSpace: Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xff064e3b), Color.fromARGB(255, 52, 6, 179)], // درجات الأخضر الملكي أو الكحلي
    ),
    // image: DecorationImage(
    //   // رابط لنقش إسلامي هندسي شفاف
    //   image: AssetImage('D:/downloads/new new/aiom/lib/assets/images/diamond-upholstery.png'),// نقش هادي ومضمون
    //   opacity: 0.10, // الشفافية عشان تظهر كعلامة مائية
    //   repeat: ImageRepeat.repeat,
    // ),
  ),
),
  
  
  actions: [
    // زر اللغة بتصميم "بابل" (Bubble)
    _buildAnimatedAction(
      icon: Icons.language_rounded,
      onTap: () {
        final prov = Provider.of<SettingsProvider>(context, listen: false);
        prov.locale.languageCode == 'ar' ? prov.setLocale('en') : prov.setLocale('ar');
      },
    ),
    // زر الثيم بتأثير الشمس والقمر
    _buildAnimatedAction(
      icon: Provider.of<SettingsProvider>(context).isDarkMode 
           ? Icons.wb_sunny_rounded : Icons.nightlight_round,
      iconColor: Provider.of<SettingsProvider>(context).isDarkMode ? Colors.amber : Colors.blueAccent,
      onTap: () => Provider.of<SettingsProvider>(context, listen: false).toggleTheme(),
    ),
    // زر الخروج المميز
    IconButton(
      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 28),
      onPressed: () => FirebaseAuth.instance.signOut(),
    ),
    const SizedBox(width: 8),
  ],
),
      
      
      
      body: SingleChildScrollView(
        
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPremiumHeader(), // الهيدر "القمر" اللي طلبته
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Column(
children: [

  // --- قسم الإدارة ---
                  _buildSection("الإدارة والـ HR", [
                    _item("إدارة الموظفين", Icons.people_alt_rounded, Colors.teal, const HRMasterPage(), "hr_manage", Theme.of(context).brightness == Brightness.dark),
                    _item("بيانات الشركة", Icons.business_center_rounded, Colors.blueGrey, const CompanySettingsPage(), "company_info", Theme.of(context).brightness == Brightness.dark),
                    _item("أرشيف المخزن", Icons.inventory_rounded, Colors.blueGrey, const MaterialArchivePage(), "warehouse_archive", Theme.of(context).brightness == Brightness.dark),
                    _item(" التقارير", Icons.bar_chart_rounded, Colors.blueGrey, const ExecutiveReportsPage(), "admin", Theme.of(context).brightness == Brightness.dark),
                  ]
                  
                  
                  ),

                  // --- قسم المبيعات ---
                  _buildSection("المبيعات والعملاء", [
                    _item("مدير مبيعات", Icons.shopping_cart_checkout_rounded, Colors.green, const SalesManagerDashboard(), "sales_manager", Theme.of(context).brightness == Brightness.dark),
                    _item("طلب مبيعات", Icons.shopping_cart_checkout_rounded, Colors.green, const AgentOrderPage(), "sales_create", Theme.of(context).brightness == Brightness.dark),
                    _item("إدارة المبيعات", Icons.analytics_rounded, Colors.green, ProfessionalAgentDashboard(userId: FirebaseAuth.instance.currentUser!.uid, agentName: widget.userName), "sales_manage", Theme.of(context).brightness == Brightness.dark),
                    _item("إدارة العملاء", Icons.person_add_alt_1_rounded, Colors.green, const ManageCustomersPage(), "customer_add", Theme.of(context).brightness == Brightness.dark),
                  ]),

                  // --- قسم المالية ---
                  _buildSection("الحسابات والمالية", [
                    _item("حسابات العملاء", Icons.account_balance_wallet_rounded, Colors.blue, const CustomerAccountsPage(), "acc_customers", Theme.of(context).brightness == Brightness.dark),
                    _item("فاتورة ", Icons.receipt_long_rounded, Colors.blue, const SmartInvoicePage(), "acc_invoices", Theme.of(context).brightness == Brightness.dark),
                    _item("كشف حساب", Icons.picture_as_pdf_rounded, Colors.blue, const CustomerStatementPage(), "acc_statements", Theme.of(context).brightness == Brightness.dark),
                    _item("الخزنة", Icons.account_balance_rounded, Colors.redAccent, const VaultPage(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                    _item("الموردين", Icons.account_balance_rounded, Colors.redAccent, const SuppliersDashboard(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                    _item("العهدة", Icons.money, Colors.redAccent, const ProfessionalAccountsPage(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                    _item("مراجعة أوردرات المبيعات", Icons.account_balance_rounded, Colors.redAccent, const AccountantApprovalPage(), "acc_invoices", Theme.of(context).brightness == Brightness.dark),
                    _item("  أوامر الإنتاج", Icons.precision_manufacturing_outlined, Colors.redAccent, const SmartProductionOrderPage(), "acc_invoices", Theme.of(context).brightness == Brightness.dark),
                  ]),

                  // --- قسم المخازن ---
                  _buildSection("المخازن والإنتاج", [
                    _item("مخزن المنتجات", Icons.warehouse_rounded, Colors.brown, const StorageDashboard(), "store_products", Theme.of(context).brightness == Brightness.dark),
                    _item(" المنتجات", Icons.production_quantity_limits, Colors.brown, const AddProductPage(), "store_products", Theme.of(context).brightness == Brightness.dark),
                    _item("أوامر الإنتاج", Icons.precision_manufacturing_rounded, Colors.blueGrey, const ProductionDashboard(), "production_orders", Theme.of(context).brightness == Brightness.dark),
                    _item("صرف خامات", Icons.outbox_rounded, Colors.blueGrey, const WarehouseDispatchPage(), "warehouse_dispatch", Theme.of(context).brightness == Brightness.dark),
                    _item("طلب خامات", Icons.inbox_rounded, Colors.blueGrey, const MaterialRequestPage(), "production_orders", Theme.of(context).brightness == Brightness.dark),
                    _item("فاتورة شراء", Icons.receipt_long_rounded, Colors.blueGrey, const PurchaseInvoicePage(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                    _item(" المخازن", Icons.warehouse_rounded, Colors.blueGrey, const ManageWarehousesPage(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                    _item(" مخزن الخامات", Icons.warehouse_rounded, Colors.blueGrey, const RawMaterialsInventoryPage(), "acc_expenses", Theme.of(context).brightness == Brightness.dark),
                  ]),

                  // --- قسم الشحن (هنا الذكاء للمندوب) ---
                  _buildSection("الشحن والنقل", [
                    _item("إدارة الشحن", Icons.local_shipping_rounded, Colors.orange, const ShippingManagementPage(), "shipping_admin", Theme.of(context).brightness == Brightness.dark),
                    _item("تتبع الشحن", Icons.location_searching_rounded, Colors.orange, const FleetRadarPage(), "shipping_track", Theme.of(context).brightness == Brightness.dark),
                    _item("مندوب التوصيل", Icons.delivery_dining_rounded, Colors.orange, const CourierDashboard(), "is_courier", Theme.of(context).brightness == Brightness.dark),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // هيدر بريميوم
  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 30, left: 25, right: 25, top: 20),
      decoration: const BoxDecoration(
        color: Color(0xff0f172a),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
            child: CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Text(widget.userName[0], style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("أهلاً بك،", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.email, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // بناء القسم بذكاء
Widget _buildSection(String title, List<Widget?> items) {
  // تصفية القائمة من أي عناصر null قبل تمريرها للـ Grid
  final List<Widget> visibleItems = items.whereType<Widget>().toList();

  // لو القسم فاضي تماماً ملوش لزمة يظهر
  if (visibleItems.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // توزيع احترافي للويب والموبايل
          crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 5 : 
                          MediaQuery.of(context).size.width > 700 ? 3 : 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.2,
        ),
        itemCount: visibleItems.length,
        itemBuilder: (context, index) => visibleItems[index],
      ),
    ],
  );
}
  // تصميم الـ Item مع فحص الصلاحية
Widget? _item(String title, IconData icon, Color color, Widget dest, String permissionKey, bool isDark) {
  // التحقق من الصلاحية (Flat Structure كما في Firebase عندك)
  bool isUserAdmin = (userPermissions?['role'] is List && (userPermissions?['role'] as List).contains('admin'));
  bool hasPermission = isUserAdmin || (userPermissions?[permissionKey] == true);

  if (!hasPermission) return null;

  return MouseRegion( // إضافة MouseRegion بتساعد الويب في تتبع الماوس صح
    cursor: SystemMouseCursors.click,
    child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => dest)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
}
}



