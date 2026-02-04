import 'package:aiom/management/EmployeeProfilePage.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f6),
      appBar: AppBar(
        title: const Text("إدارة الموظفين والصلاحيات"),
        backgroundColor: const Color(0xff134e4a),
      ),
      body: Column(
        children: [
          _buildSearchSection(),
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
                    return _buildEmployeeCard(userData, docs[index].id);
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
        label: const Text("إضافة موظف جديد"),
        icon: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  // نفس دوال البحث والبطاقة السابقة (لم تتغير لتقليل حجم الكود المكرر، التركيز على الـ Dialog)
  Widget _buildSearchSection() => Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xff134e4a),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(hintText: "بحث...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
      ));

  Widget _buildEmployeeCard(Map<String, dynamic> data, String id) {
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
  final Map<String, List<Map<String, String>>> permissionGroups = {
    "الإدارة والـ HR": [
      {'key': 'hr_manage', 'name': 'صفحة إدارة الموظفين'},
      {'key': 'company_info', 'name': 'بيانات الشركة'},
      {'key': 'admin', 'name': 'لوحة التقارير العليا'},
    ],
    "المبيعات": [
      {'key': 'sales_create', 'name': 'إنشاء أوردر جديد'},
      {'key': 'sales_manage', 'name': 'إدارة المبيعات الحالية'},
      {'key': 'customer_add', 'name': 'إضافة وتعديل العملاء'},
      {'key': 'sales_manager', 'name': 'لوحة مدير المبيعات'},
    ],
    "الحسابات": [
      {'key': 'acc_customers', 'name': 'كشف حساب عميل'},
      {'key': 'acc_invoices', 'name': 'الفواتير والضرائب'},
      {'key': 'acc_expenses', 'name': 'المصاريف والعهدة'},
    ],
    "المخازن": [
      {'key': 'store_products', 'name': 'جرد المنتجات التامة'},
      {'key': 'warehouse_archive', 'name': 'أرشيف الحركات'},
      {'key': 'warehouse_dispatch', 'name': 'إذن صرف خامات'},
    ],
     "الشحن": [
      {'key': 'shipping_admin', 'name': 'إدارة شركات الشحن'},
      {'key': 'shipping_track', 'name': 'تتبع الشحنات'},
      {'key': 'is_courier', 'name': ' المندوبين'},
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600, // وسعنا العرض شوية عشان الصلاحيات
        height: 700,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // الهيدر والبروجرس بار (نفس السابق)
            _buildHeader(),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: (_currentStep + 1) / 4, color: const Color(0xff134e4a), backgroundColor: Colors.grey[200]),
            const SizedBox(height: 20),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _simpleStep(title: "البيانات الشخصية", children: [
                    _tf(nameCtrl, "الاسم", Icons.person),
                    _tf(dobCtrl, "تاريخ الميلاد", Icons.calendar_today, isDate: true),
                  ]),
                  _simpleStep(title: "بيانات الاتصال", children: [
                    _tf(phoneCtrl, "الموبايل", Icons.phone),
                    _tf(addressCtrl, "العنوان", Icons.location_on),
                  ]),
                  _simpleStep(title: "بيانات الدخول", children: [
                    if(widget.docId != null) const Text("⚠️ اترك الباسوورد فارغاً إذا لم ترد تغييره", style: TextStyle(color: Colors.amber)),
                    _tf(emailCtrl, "الإيميل", Icons.email),
                    _tf(passCtrl, "الباسوورد", Icons.lock, isPass: true),
                  ]),
                  _step4DetailedPermissions(), // الخطوة الجديدة كلياً
                ],
              ),
            ),
            
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // --- الخطوة 4: الصلاحيات التفصيلية ---
  Widget _step4DetailedPermissions() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("الصلاحيات التفصيلية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("حدد الصفحات المسموح للموظف بدخولها:", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          
          // عرض المجموعات كـ ExpansionTiles
          ...permissionGroups.entries.map((entry) {
            return Card(
              elevation: 0,
              color: Colors.grey[50],
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff134e4a))),
                leading: const Icon(Icons.folder_shared, color: Color(0xff134e4a)),
                children: entry.value.map((perm) {
                  String key = perm['key']!;
                  bool isChecked = granularPermissions[key] ?? false;
                  
                  return CheckboxListTile(
                    title: Text(perm['name']!),
                    value: isChecked,
                    activeColor: const Color(0xff134e4a),
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                         granularPermissions[key] = val!;
                      });
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
          
          debugPrint("تم إنشاء المستخدم الجديد بنجاح: $uid دون التأثير على الحساب الحالي.");
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ الموظف والصلاحيات بنجاح ✅")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- أدوات مساعدة للواجهة ---
  Widget _simpleStep({required String title, required List<Widget> children}) {
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

  Widget _tf(TextEditingController c, String label, IconData icon, {bool isPass = false, bool isDate = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: c,
        obscureText: isPass,
        readOnly: isDate,
        onTap: isDate ? () async {
          DateTime? d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
          if(d!=null) c.text = DateFormat('yyyy-MM-dd').format(d);
        } : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(widget.docId == null ? "موظف جديد" : "تعديل موظف", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.close))
  ]);

  Widget _buildBottomButtons() => Row(children: [
    if (_currentStep > 0) TextButton(onPressed: () { _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setState(() => _currentStep--); }, child: const Text("السابق")),
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
      child: Text(_currentStep == 3 ? "حفظ" : "التالي"),
    )
  ]);
}