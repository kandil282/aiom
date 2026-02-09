import 'package:aiom/management/EmployeeProfilePage.dart';
import 'package:aiom/translate/translationhelper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // ضروري للحل السحري
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HRMasterPage extends StatefulWidget {
  const HRMasterPage({super.key});

  @override
  State<HRMasterPage> createState() => _HRMasterPageState();
}

class _HRMasterPageState extends State<HRMasterPage> {
  String searchQuery = "";

@override
Widget build(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  
  return Scaffold(
    // تغيير الخلفية حسب المود
    backgroundColor: isDark ? const Color(0xff0f172a) : const Color(0xfff4f7f6),
    appBar: AppBar(
      title:  Text(Translate.text(context, "إدارة الموظفين والصلاحيات", "Employee Management and Permissions")),
      // لون الـ AppBar يفضل يفضل ثابت أو يتغير بسيط
      backgroundColor: const Color(0xff134e4a), 
      elevation: 0,
    ),
    body: Column(
      children: [
        _buildSearchSection(isDark), // نمرر الـ isDark هنا
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var docs = snapshot.data!.docs.where((doc) {
                var name = (doc.data() as Map<String, dynamic>)['username']?.toString() ?? "";
                return name.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var userData = docs[index].data() as Map<String, dynamic>;
                  return _buildEmployeeCard(userData, docs[index].id, isDark);
                },
              );
            },
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openEmployeeWizard(context),
      backgroundColor: const Color(0xff134e4a),
      label: Text(Translate.text(context, "إضافة موظف جديد", "Add New Employee"), style: const TextStyle(color: Colors.white)),
      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
    ),
  );
}
  // نفس دوال البحث والبطاقة السابقة (لم تتغير لتقليل حجم الكود المكرر، التركيز على الـ Dialog)
  Widget _buildSearchSection(bool isDark) => Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xff134e4a),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(hintText: Translate.text(context, "بحث...", "Search..."), filled: true, fillColor: isDark ? Colors.grey[800]! : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
      ));

  Widget _buildEmployeeCard(Map<String, dynamic> data, String id, bool isDark) {
     List roles = data['role'] is List ? data['role'] : [data['role'] ?? 'user'];
     return Card(
       margin: const EdgeInsets.only(bottom: 10),
       child: ListTile(
        // داخل ListTile في _buildEmployeeCard
          trailing: Wrap(
            children: [
              // IconButton(
              //   icon: const Icon(Icons.analytics, color: Colors.blue), 
              //   // onPressed: () => EmployeeControlPanel(context, data, id)
              // ),
              IconButton(
                icon: const Icon(Icons.edit), 
                onPressed: () => _openEmployeeWizard(context, employeeData: data, docId: id)
              ),
            ],
          ),
         leading: const CircleAvatar(child: Icon(Icons.person)),
         title: Text(data['username'] ?? ""),
         subtitle: Text(roles.join(" - ")),
         onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EmployeeControlPanel(
        userData: data,
        docId: id,
      ),
    ),
  );
},
       ),

     );
  }

  void _openEmployeeWizard(BuildContext context, {Map<String, dynamic>? employeeData, String? docId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmployeeWizardDialog(existingData: employeeData, docId: docId),
    );
  }
}

// -----------------------------------------------------------------------------
// --- المعالج المطور (حل مشكلة التبديل + صلاحيات دقيقة) ---
// -----------------------------------------------------------------------------
class EmployeeWizardDialog extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const EmployeeWizardDialog({super.key, this.existingData, this.docId});

  @override
  State<EmployeeWizardDialog> createState() => _EmployeeWizardDialogState();
}

class _EmployeeWizardDialogState extends State<EmployeeWizardDialog> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  late TextEditingController nameCtrl, dobCtrl, phoneCtrl, addressCtrl, emailCtrl, passCtrl;
  List<String> selectedRoles = []; // للأدوار العامة
  Map<String, bool> granularPermissions = {}; // للصلاحيات الدقيقة

  // هيكل الصلاحيات التفصيلية (كل صفحة زر)
  late final Map<String, List<Map<String, String>>> permissionGroups = {
    Translate.text(context, "الإدارة والـ HR", "Administration & HR"): [
      {'key': 'hr_manage', 'name': Translate.text(context, "صفحة إدارة الموظفين", "Employee Management Page")},
      {'key': 'company_info', 'name': Translate.text(context, "بيانات الشركة", "Company Information")},
      {'key': 'admin', 'name': Translate.text(context, "لوحة التقارير العليا", "Executive Reports Dashboard")},
    ],
    Translate.text(context, "المبيعات", "Sales"): [
      {'key': 'sales_create', 'name': Translate.text(context, "إنشاء أوردر جديد", "Create New Order")},
      {'key': 'sales_manage', 'name': Translate.text(context, "إدارة المبيعات الحالية", "Manage Current Sales")},
      {'key': 'customer_add', 'name': Translate.text(context, "إضافة وتعديل العملاء", "Add and Edit Customers")},
      {'key': 'sales_manager', 'name': Translate.text(context, "لوحة مدير المبيعات", "Sales Manager Dashboard")},
    ],
    Translate.text(context, "الحسابات", "Accounts"): [
      {'key': 'acc_customers', 'name': Translate.text(context, "كشف حساب عميل", "Customer Statement")},
      {'key': 'acc_invoices', 'name': Translate.text(context, "الفواتير والضرائب", "Invoices and Taxes")},
      {'key': 'acc_expenses', 'name': Translate.text(context, "المصاريف والعهدة", "Expenses and Petty Cash")},
    ],
    Translate.text(context, "المخازن", "Stores"): [
      {'key': 'store_products', 'name': Translate.text(context, "جرد المنتجات التامة", "Complete Product Inventory")},
      {'key': 'warehouse_archive', 'name': Translate.text(context, "أرشيف الحركات", "Movement Archive")},
      {'key': 'warehouse_dispatch', 'name': Translate.text(context, "إذن صرف خامات", "Raw Materials Dispatch Authorization")},
    ],
     Translate.text(context, "الشحن", "Shipping"): [
      {'key': 'shipping_admin', 'name': Translate.text(context, "إدارة شركات الشحن", "Shipping Company Management")},
      {'key': 'shipping_track', 'name': Translate.text(context, "تتبع الشحنات", "Shipment Tracking")},
      {'key': 'is_courier', 'name': Translate.text(context, "المندوبين", "Couriers")},
    ],
  };

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existingData?['username']);
    dobCtrl = TextEditingController(text: widget.existingData?['dob']);
    phoneCtrl = TextEditingController(text: widget.existingData?['phone']);
    addressCtrl = TextEditingController(text: widget.existingData?['address']);
    emailCtrl = TextEditingController(text: widget.existingData?['email']);
    passCtrl = TextEditingController();

    // استرجاع الصلاحيات المحفوظة
    if (widget.existingData != null) {
      if (widget.existingData!['role'] is List) {
        selectedRoles = List<String>.from(widget.existingData!['role']);
      }
      // استرجاع الصلاحيات الدقيقة
      if (widget.existingData!['permissions'] != null) {
        granularPermissions = Map<String, bool>.from(widget.existingData!['permissions']);
      }
    } else {
      selectedRoles.add('courier'); 
    }
  }

@override
Widget build(BuildContext context, {bool isPass = false, bool isDate = false}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  return Dialog(
    backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      width: 600,
      height: 750,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(isDark), // تعديل الهيدر
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4, 
            color: const Color(0xff134e4a), 
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200]
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                _simpleStep(title: Translate.text(context, "البيانات الشخصية", "Personal Information"), isDark: isDark, children: [
                  _tf(nameCtrl,Translate.text(context, "الاسم", "Name"), Icons.person, isDark),
                  _tf(dobCtrl, Translate.text(context, "تاريخ الميلاد", "Date of Birth"), Icons.calendar_today, isDark, isDate: true),
                ]),
                _simpleStep(title: Translate.text(context, "بيانات الاتصال", "Contact Information"), isDark: isDark, children: [
                  _tf(phoneCtrl, Translate.text(context, "الموبايل", "Mobile"), Icons.phone, isDark),
                  _tf(addressCtrl, Translate.text(context, "العنوان", "Address"), Icons.location_on, isDark),
                ]),
                _simpleStep(title: Translate.text(context, "بيانات الدخول", "Login Information"), isDark: isDark, children: [
                  if(widget.docId != null)  Text(Translate.text(context, "⚠️ اترك الباسوورد فارغاً إذا لم ترد تغييره", "⚠️ Leave password empty if you don't want to change it"), style: TextStyle(color: Colors.amber)),
                  _tf(emailCtrl, Translate.text(context, "الإيميل", "Email"), Icons.email, isDark),
                  _tf(passCtrl, Translate.text(context, "الباسوورد", "Password"), Icons.lock, isDark, isPass: true),
                ]),
                _step4DetailedPermissions(isDark), 
              ],
            ),
          ),
          _buildBottomButtons(isDark),
        ],
      ),
    ),
  );
}
  // --- الخطوة 4: الصلاحيات التفصيلية ---
Widget _step4DetailedPermissions(bool isDark) {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Translate.text(context, "الصلاحيات التفصيلية", "Detailed Permissions"), 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
         Text(Translate.text(context, "حدد الصفحات المسموح للموظف بدخولها:", "Select the pages allowed for the employee to access:"), style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        
        ...permissionGroups.entries.map((entry) {
          return Card(
            elevation: 0,
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              // لون النص في حالة الفتح والغلق
              iconColor: const Color(0xff134e4a),
              collapsedIconColor: Colors.grey,
              title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xff134e4a))),
              leading: const Icon(Icons.folder_shared),
              children: entry.value.map((perm) {
                String key = perm['key']!;
                bool isChecked = granularPermissions[key] ?? false;
                
                return CheckboxListTile(
                  title: Text(perm['name']!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  value: isChecked,
                  activeColor: const Color(0xff134e4a),
                  checkColor: Colors.white,
                  dense: true,
                  onChanged: (val) {
                    setState(() => granularPermissions[key] = val!);
                  },
                );
              }).toList(),
            ),
          );
        }),
      ],
    ),
  );
}
  // --- دالة الحفظ الذكية (بدون خروج من الحساب) ---
  Future<void> _submitData() async {
    setState(() => _isLoading = true);
    try {
      String uid = widget.docId ?? "";

      // 1. إنشاء المستخدم باستخدام (تطبيق ثانوي) لمنع الخروج
      if (widget.docId == null) {
        // ننشئ نسخة مؤقتة من التطبيق
        FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'temporaryRegisterApp',
          options: Firebase.app().options,
        );

        try {
          // نستخدم النسخة المؤقتة لإنشاء المستخدم
          UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim(),
          );
          uid = cred.user!.uid;
          
          debugPrint(Translate.text(context, "تم إنشاء المستخدم الجديد بنجاح: $uid دون التأثير على الحساب الحالي.", "New user created successfully: $uid without affecting the current account."));
        } catch (e) {
          rethrow; // نعيد رمي الخطأ للتعامل معه في الخارج
        } finally {
          // نحذف النسخة المؤقتة لتنظيف الذاكرة
          await tempApp.delete();
        }
      }

      // 2. تجهيز البيانات
      Map<String, dynamic> dataToSave = {
        'username': nameCtrl.text.trim(),
        'dob': dobCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'role': selectedRoles,
        'permissions': granularPermissions, // حفظ الصلاحيات التفصيلية
        'hasAppAccess': true,
        // حفظ الصلاحيات بشكل مسطح أيضاً لدعم الكود القديم في الهوم بيج
        ...granularPermissions,
      };

      // 3. الحفظ في Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(dataToSave, SetOptions(merge: true));

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "تم حفظ الموظف والصلاحيات بنجاح ✅", "Employee and permissions saved successfully ✅"))));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- أدوات مساعدة للواجهة ---
  Widget _simpleStep({required String title, required List<Widget> children, required bool isDark}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ...children
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData icon, bool isDark, {bool isPass = false, bool isDate = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
      controller: c,
      obscureText: isPass,
      readOnly: isDate,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xff134e4a)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
      ),
      onTap: isDate ? () async {
        DateTime? d = await showDatePicker(
          context: context, 
          initialDate: DateTime(2000), 
          firstDate: DateTime(1950), 
          lastDate: DateTime.now(),
          // لتنسيق ألوان الـ DatePicker في الدارك مود
          builder: (context, child) => Theme(
            data: isDark ? ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xff134e4a)),
            ) : ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xff134e4a)),
            ),
            child: child!,
          ),
        );
        if(d!=null) c.text = DateFormat('yyyy-MM-dd').format(d);
      } : null,
    ),
  );
}
  Widget _buildHeader(bool isDark) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(widget.docId == null ? Translate.text(context, "موظف جديد", "New Employee") : Translate.text(context, "تعديل موظف", "Edit Employee"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.close))
  ]);

  Widget _buildBottomButtons(bool isDark) => Row(children: [
    if (_currentStep > 0) TextButton(onPressed: () { _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setState(() => _currentStep--); }, child: Text(Translate.text(context, "السابق", "Previous"))),
    const Spacer(),
    _isLoading ? const CircularProgressIndicator() : ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff134e4a)),
      onPressed: () {
         if (_currentStep < 3) {
           _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
           setState(() => _currentStep++);
         } else {
           _submitData();
         }
      },
      child: Text(Translate.text(context, _currentStep == 3 ? "حفظ" : "التالي", _currentStep == 3 ? "Save" : "Next")),
    )
  ]);
}