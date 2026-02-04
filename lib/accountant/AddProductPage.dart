import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  
  String? _selectedCat;
  String? _selectedSubCat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- دالة الحفظ الملكية وتوزيع المخازن ---
// استبدل دالة _saveProduct بهذا الكود
Future<void> _saveProduct() async {
  if (_nameController.text.isEmpty || _selectedCat == null || _selectedSubCat == null) return;
  setState(() => _isLoading = true);

  try {
    DocumentReference pRef = FirebaseFirestore.instance.collection('products').doc();
    String barcode = _barcodeController.text.isEmpty ? "BC-${pRef.id.substring(0,6).toUpperCase()}" : _barcodeController.text.trim();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // 1. إنشاء المنتج مع حقل إجمالي المخزون (أهم نقطة)
    batch.set(pRef, {
      'productName': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'barcode': barcode,
      'category': _selectedCat,
      'subCategory': _selectedSubCat,
      'totalQuantity': 0, // هذا الحقل هو مرجعنا السريع
      'isDeleted': false, // للحماية من الحذف الخطأ
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. إنشاء سجلات للمخازن (بقيم صفرية)
    var warehouses = await FirebaseFirestore.instance.collection('storage_locations').get();
    for (var w in warehouses.docs) {
      batch.set(pRef.collection('inventory').doc(w.id), {
        'warehouseId': w.id,
        'warehouseName': w['name'],
        'quantity': 0,
      });
    }

    await batch.commit();
    // ... (تنظيف الحقول وإظهار رسالة نجاح)
  } catch (e) {
    // ... (معالجة الخطأ)
  } finally {
    setState(() => _isLoading = false);
  }
}

// استبدل دالة _deleteProduct بهذا الكود (الحذف الناعم)
Future<void> _deleteProduct(String productId) async {
  await FirebaseFirestore.instance.collection('products').doc(productId).update({
    'isDeleted': true, // إخفاء فقط وليس حذف
    'deletedAt': FieldValue.serverTimestamp(),
  });
  _showSnackBar("تم حذف المنتج بنجاح (إخفاء فقط)", Colors.blueGrey);
}




  // --- دالة الحذف النهائي للمنتج وسجلاته ---
  // Future<void> _deleteProduct(String productId) async {
  //   try {
  //     // حذف السجلات الفرعية أولاً (المخازن) ثم المنتج الرئيسي
  //     var invDocs = await FirebaseFirestore.instance.collection('products').doc(productId).collection('inventory').get();
  //     WriteBatch batch = FirebaseFirestore.instance.batch();
      
  //     for (var doc in invDocs.docs) {
  //       batch.delete(doc.reference);
  //     }
  //     batch.delete(FirebaseFirestore.instance.collection('products').doc(productId));
      
  //     await batch.commit();
  //     _showSnackBar("تم حذف المنتج وسجلاته بنجاح", Colors.blueGrey);
  //   } catch (e) {
  //     _showSnackBar("فشل الحذف", Colors.red);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildInputSection()),
          SliverToBoxAdapter(child: _buildSectionTitle("إدارة الأصناف (اسحب للحذف)")),
          _buildProductList(),
        ],
      ),
    );
  }

  // --- بناء الهيدر ونموذج الإدخال (نفس الكود السابق مع تحسينات بصرية) ---
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120, pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text("المصنع الذكي", style: TextStyle(fontWeight: FontWeight.bold)),
        background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1A237E)]))),
      ),
      bottom: TabBar(controller: _tabController, indicatorColor: Colors.amber, tabs: const [Tab(text: "منتجات تامة"), Tab(text: "خامات")]),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: _inputDecoration(Icons.inventory_2, label: "اسم الصنف")),
              const SizedBox(height: 15),
              _buildCategorySelectors(),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: TextField(controller: _priceController, decoration: _inputDecoration(Icons.payments, label: "السعر"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _barcodeController, decoration: _inputDecoration(Icons.qr_code_scanner, label: "الباركود"))),
                ],
              ),
              const SizedBox(height: 25),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- قائمة العرض مع "السحب للحذف" وحساب الكمية ---
  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').orderBy('category').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        
        Map<String, List<DocumentSnapshot>> grouped = {};
        for (var d in snapshot.data!.docs) {
          var data = d.data() as Map<String, dynamic>;
          String cat = data.containsKey('category') ? data['category'] : "غير مصنف";
          grouped.putIfAbsent(cat, () => []).add(d);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            String catName = grouped.keys.elementAt(index);
            var items = grouped[catName]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryHeader(catName),
                ...items.map((item) => _buildDismissibleCard(item)),
              ],
            );
          }, childCount: grouped.keys.length),
        );
      },
    );
  }

  // ويدجت الحذف بالسحب

// ويدجت الحذف بالسحب مع نافذة تأكيد ملكية
  Widget _buildDismissibleCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String productName = data['productName'] ?? "هذا الصنف";

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart, // السحب من اليمين لليسار
      
      // --- إضافة نافذة التأكيد هنا ---
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Text("تأكيد الحذف"),
                ],
              ),
              content: Text("هل أنت متأكد من حذف ($productName) نهائياً من جميع المخازن؟"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // إرجاع "خطأ" لعدم الحذف
                  child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true), // إرجاع "صح" لتنفيذ الحذف
                  child: const Text("حذف الآن", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },

      onDismissed: (direction) => _deleteProduct(doc.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 30),
            Text("حذف", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: _buildProductItemCard(doc),
    );
  }


  Widget _buildProductItemCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    
    // جلب مجموع الكميات من المخازن لكل منتج بشكل لحظي
    return StreamBuilder<QuerySnapshot>(
      stream: doc.reference.collection('inventory').snapshots(),
      builder: (context, invSnapshot) {
        num totalQty = 0;
        if (invSnapshot.hasData) {
          for (var invDoc in invSnapshot.data!.docs) {
            totalQty += (invDoc.data() as Map<String, dynamic>)['quantity'] ?? 0;
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo[50],
              child: Text(totalQty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
            title: Text(data['productName'] ?? "صنف قديم", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${data['subCategory'] ?? '---'} • ${data['barcode'] ?? '---'}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${data['price'] ?? 0} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const Text("إجمالي رصيد", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  // (باقي الـ Widgets المساعدة: _buildCategoryHeader, _inputDecoration, _buildSaveButton, إلخ كما هي)
  Widget _buildCategoryHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.blue[50], width: double.infinity,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
    );
  }

  InputDecoration _inputDecoration(IconData icon, {String? label}) {
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
      filled: true, fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _isLoading ? null : _saveProduct,
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ وتوزيع الصنف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
  
  // دالة اختيار التصنيفات (نفس الكود السابق مع استدعاء _addNewCategoryDialog)
  Widget _buildCategorySelectors() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCat,
                    hint: const Text("اختر الرئيسي"),
                    decoration: _inputDecoration(Icons.category),
                    items: snapshot.hasData ? snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']))).toList() : [],
                    onChanged: (val) => setState(() { _selectedCat = val; _selectedSubCat = null; }),
                  );
                },
              ),
            ),
            IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF0D47A1)), onPressed: () => _addNewCategoryDialog(isMainCategory: true)),
          ],
        ),
        if (_selectedCat != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').doc(_selectedCat).collection('subcategories').snapshots(),
                  builder: (context, snapshot) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedSubCat,
                      hint: const Text("اختر الفرعي"),
                      decoration: _inputDecoration(Icons.account_tree_outlined),
                      items: snapshot.hasData ? snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']))).toList() : [],
                      onChanged: (val) => setState(() => _selectedSubCat = val),
                    );
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0D47A1)), onPressed: () => _addNewCategoryDialog(isMainCategory: false)),
            ],
          ),
        ],
      ],
    );
  }

  void _addNewCategoryDialog({required bool isMainCategory}) {
    TextEditingController newCatController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isMainCategory ? "إضافة رئيسي جديد" : "إضافة فرعي لـ $_selectedCat"),
        content: TextField(controller: newCatController, decoration: _inputDecoration(Icons.add_box)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () async {
            if (newCatController.text.isNotEmpty) {
              String name = newCatController.text.trim();
              if (isMainCategory) {
                await FirebaseFirestore.instance.collection('categories').doc(name).set({'name': name});
              } else {
                await FirebaseFirestore.instance.collection('categories').doc(_selectedCat).collection('subcategories').add({'name': name});
              }
              Navigator.pop(context);
            }
          }, child: const Text("حفظ")),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.all(20.0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
  }
}