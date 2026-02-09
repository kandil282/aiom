import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmartProductionOrderPage extends StatefulWidget {
  const SmartProductionOrderPage({super.key});

  @override
  State<SmartProductionOrderPage> createState() => _SmartProductionOrderPageState();
}

class _SmartProductionOrderPageState extends State<SmartProductionOrderPage> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedProductId;
  String? _selectedProductName;
  int _currentStock = 0; // متغير المخزون
  bool _isSubmitting = false;

  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // دالة جلب المخزون
  Future<void> _fetchStock(String pId) async {
    var invSnapshot = await FirebaseFirestore.instance
        .collection('products').doc(pId).collection('inventory').get();
    
    int total = 0;
    for (var doc in invSnapshot.docs) {
      total += int.tryParse(doc.data()['quantity'].toString()) ?? 0;
    }
    setState(() => _currentStock = total);
  }

  @override
  Widget build(BuildContext context) {
    // جلب ألوان الثيم الحالي من الـ Context
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translate.text(context, "طلب إنتاج جديد", "New Production Order")),
        centerTitle: true,
      ),
// في صفحة AddProductionOrderPage (أو الصفحة التي أرسلت صورتها)
// استبدل الـ Body في الـ build بهذا الكود:

body: StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('products').where('isDeleted', isNotEqualTo: true).snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text(Translate.text(context, "حدث خطأ: ${snapshot.error}", "An error occurred: ${snapshot.error}")));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

    var allProducts = snapshot.data!.docs;

    // 1. استخراج التصنيفات بأمان (Fixing the Red Screen)
    Set<String> categories = {};
    for (var doc in allProducts) {
      var data = doc.data() as Map<String, dynamic>;
      // إذا لم يوجد تصنيف، نضع "عام"
      categories.add(data['category'] ?? Translate.text(context, "عام", "General"));
    }

    // 2. تصفية المنتجات بناءً على الاختيار
    var filteredProducts = allProducts.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String cat = data['category'] ?? Translate.text(context, "عام", "General");
      String sub = data['subCategory'] ?? Translate.text(context, "عام", "General");
      
      bool catMatch = _selectedCategory == null || cat == _selectedCategory;
      bool subMatch = _selectedSubCategory == null || sub == _selectedSubCategory;
      
      return catMatch && subMatch;
    }).toList();

    // استخراج التصنيفات الفرعية المتاحة للتصنيف الرئيسي المختار
    Set<String> subCategories = {};
    if (_selectedCategory != null) {
      for (var doc in allProducts) {
        var data = doc.data() as Map<String, dynamic>;
        if ((data['category'] ?? Translate.text(context, "عام", "General")) == _selectedCategory) {
          subCategories.add(data['subCategory'] ?? Translate.text(context, "عام", "General"));
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildThemedCard(
              context,
              title: Translate.text(context, "بيانات المنتج", "Product Details"),
              child: Column(
                children: [
                  _buildDropdown(Translate.text(context, "القسم الرئيسي", "Main Category"), _selectedCategory, categories.toList(), (val) {
                    setState(() { _selectedCategory = val; _selectedSubCategory = null; _selectedProductId = null; });
                  }),
                  if (_selectedCategory != null)
                    _buildDropdown(Translate.text(context, "النوع الفرعي", "Sub Category"), _selectedSubCategory, subCategories.toList(), (val) {
                      setState(() { _selectedSubCategory = val; _selectedProductId = null; });
                    }),
                  
                  // القائمة المنسدلة للمنتجات
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProductId,
                    decoration: _inputDecoration(context, Translate.text(context, "اختر المنتج", "Select Product")),
                    hint: Text(Translate.text(context, "حدد المنتج", "Select Product")),
                    items: filteredProducts.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['productName'] ?? Translate.text(context, "بدون اسم", "Unnamed Product")),
                      );
                    }).toList(),
                    onChanged: (val) {
                      var product = filteredProducts.firstWhere((d) => d.id == val);
                      var pData = product.data() as Map<String, dynamic>;
                      setState(() {
                        _selectedProductId = val;
                        // قراءة المخزون الإجمالي المحدث (الحل السحري)
                        _currentStock = (pData['totalQuantity'] ?? 0); 
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_selectedProductId != null) _buildStockCard(context), // كارت المخزون
            const SizedBox(height: 20),
            // ... (باقي حقول الكمية والملاحظات كما هي عندك)
             _buildThemedCard(
                    context,
                    title: Translate.text(context, "أمر التشغيل", "Production Order"),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(context, Translate.text(context, "الكمية المراد إنتاجها", "Quantity to be Produced"), icon: Icons.factory),
                        ),
                         const SizedBox(height: 15),
                         // زر الحفظ هنا يستدعي دالة حفظ الطلب في production_orders
                      ]
                    )
             ),
             const SizedBox(height: 20),
             ElevatedButton(
               onPressed: _submitOrder, // دالة الحفظ العادية
               child: Text(Translate.text(context, "إرسال للمصنع", "Send to Factory")),
             )
          ],
        ),
      ),
    );
  },
),
   
   
    );
  }

  // ودجت كارت المخزون المستجيب للألوان
  Widget _buildStockCard(BuildContext context) {
    bool isLow = _currentStock < 10;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLow ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLow ? Colors.orange : Colors.green, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(Translate.text(context, "المخزن الحالي", "Current Stock"), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          Text("${Translate.text(context, "$_currentStock قطعة", "$_currentStock Pieces")}", style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 18, 
            color: isLow ? Colors.orange : Colors.green
          )),
        ],
      ),
    );
  }

  // تنسيق المدخلات المستجيب للثيم
  InputDecoration _inputDecoration(BuildContext context, String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).primaryColor) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Theme.of(context).canvasColor, // يستجيب للثيم
    );
  }

  Widget _buildThemedCard(BuildContext context, {required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 25),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _inputDecoration(context, label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isSubmitting ? null : _submitOrder,
      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("إرسال الأمر"),
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('production_orders').add({
        'productId': _selectedProductId,
        'productName': _selectedProductName,
        'quantity': int.parse(_qtyController.text),
        'note': _notesController.text,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      _qtyController.clear();
      _notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translate.text(context, "تم الإرسال", "Submitted Successfully"))));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}