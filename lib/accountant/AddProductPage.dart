import 'package:aiom/configer/settingPage.dart';
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

  // --- دوال الحفظ والحذف (كما هي بدون تغيير) ---
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _selectedCat == null || _selectedSubCat == null) return;
    setState(() => _isLoading = true);
    try {
      DocumentReference pRef = FirebaseFirestore.instance.collection('products').doc();
      String barcode = _barcodeController.text.isEmpty ? "BC-${pRef.id.substring(0, 6).toUpperCase()}" : _barcodeController.text.trim();
      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(pRef, {
        'productName': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'barcode': barcode,
        'category': _selectedCat,
        'subCategory': _selectedSubCat,
        'totalQuantity': 0,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      var warehouses = await FirebaseFirestore.instance.collection('storage_locations').get();
      for (var w in warehouses.docs) {
        batch.set(pRef.collection('inventory').doc(w.id), {
          'warehouseId': w.id,
          'warehouseName': w['name'],
          'quantity': 0,
        });
      }
      await batch.commit();
      _nameController.clear();
      _priceController.clear();
      _barcodeController.clear();
      _showSnackBar(Translate.text(context, "تم الحفظ بنجاح", "Successfully Saved"), Colors.green);
    } catch (e) {
      _showSnackBar(Translate.text(context, "حدث خطأ", "An error occurred"), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    await FirebaseFirestore.instance.collection('products').doc(productId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    _showSnackBar(Translate.text(context, "تم حذف المنتج بنجاح (إخفاء فقط)", "Product deleted successfully (Hidden only)"), Colors.blueGrey);
  }

  @override
  Widget build(BuildContext context) {
    // 1. تحديد ما إذا كنا في الوضع الليلي
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // 2. تحديد لون النص الأساسي (أسود في اللايت، أبيض في الدارك)
    final Color mainTextColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      // تغيير لون الخلفية حسب الوضع
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F7F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDarkMode),
          SliverToBoxAdapter(child: _buildInputSection(isDarkMode, mainTextColor)),
          SliverToBoxAdapter(child: _buildSectionTitle(Translate.text(context, "إدارة الأصناف (اسحب للحذف)", "Manage Products (Drag to Delete)"), mainTextColor)),
          _buildProductList(isDarkMode, mainTextColor),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDarkMode) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(Translate.text(context, "المصنع الذكي", "Smart Factory"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                  ? [Colors.black87, Colors.grey[900]!] // ألوان داكنة للوضع الليلي
                  : [const Color(0xFF0D47A1), const Color(0xFF1A237E)], // ألوان زرقاء للوضع النهاري
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.amber,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs:  [Tab(text: Translate.text(context, "منتجات تامة", "Finished Products")), ],
      ),
    );
  }

  Widget _buildInputSection(bool isDarkMode, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        // لون الكارد يتغير
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor), // لون الكتابة
                decoration: _inputDecoration(Icons.inventory_2, isDarkMode, label: Translate.text(context, "اسم الصنف", "Product Name")),
              ),
              const SizedBox(height: 15),
              _buildCategorySelectors(isDarkMode, textColor),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration(Icons.payments, isDarkMode, label: Translate.text(context, "السعر", "Price")),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _barcodeController,
                      style: TextStyle(color: textColor),
                      decoration: _inputDecoration(Icons.qr_code_scanner, isDarkMode, label: Translate.text(context, "الباركود", "Barcode")),
                    ),
                  ),
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

 Widget _buildProductList(bool isDarkMode, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      // التعديل هنا: سنحذف شرط 'where' مؤقتاً لضمان ظهور البيانات القديمة والجديدة
      stream: FirebaseFirestore.instance.collection('products').orderBy('category').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Text("خطأ في التحميل: ${snapshot.error}")));
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

        // تصفية البيانات يدوياً لضمان عدم تعليق التحميل
        var docs = snapshot.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          // إذا كان الحقل غير موجود (منتج قديم) سنعتبره false
          return data['isDeleted'] != true; 
        }).toList();

        if (docs.isEmpty) {
          return  SliverToBoxAdapter(child: Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(Translate.text(context, "لا توجد أصناف حالياً، أضف صنفك الأول", "No products available yet, add your first product"), style: TextStyle(fontSize: 16, color: Colors.grey)),
          )));
        }

        Map<String, List<DocumentSnapshot>> grouped = {};
        for (var d in docs) {
          var data = d.data() as Map<String, dynamic>;
          String cat = data.containsKey('category') ? data['category'] : Translate.text(context, "غير مصنف", "Uncategorized");
          grouped.putIfAbsent(cat, () => []).add(d);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            String catName = grouped.keys.elementAt(index);
            var items = grouped[catName]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryHeader(catName, isDarkMode),
                ...items.map((item) => _buildDismissibleCard(item, isDarkMode, textColor)),
              ],
            );
          }, childCount: grouped.keys.length),
        );
      },
    );
  }

  
  Widget _buildDismissibleCard(DocumentSnapshot doc, bool isDarkMode, Color textColor) {
    var data = doc.data() as Map<String, dynamic>;
    String productName = data['productName'] ?? Translate.text(context, "هذا الصنف", "This Product");

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white, // خلفية الحوار
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 10),
                  Text(Translate.text(context, "تأكيد الحذف", "Confirm Deletion"), style: TextStyle(color: textColor)),
                ],
              ),
              content: Text("${Translate.text(context, "هل أنت متأكد من حذف", "Are you sure you want to delete")} ($productName) ${Translate.text(context, "نهائياً؟", "permanently?")}", style: TextStyle(color: textColor)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(Translate.text(context, "إلغاء", "Cancel"), style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(Translate.text(context, "حذف الآن", "Delete Now"), style: TextStyle(color: Colors.white)),
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
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 30),
            Text(Translate.text(context, "حذف", "Delete"), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: _buildProductItemCard(doc, isDarkMode, textColor),
    );
  }

  Widget _buildProductItemCard(DocumentSnapshot doc, bool isDarkMode, Color textColor) {
    var data = doc.data() as Map<String, dynamic>;

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
          // لون البطاقة في القائمة
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDarkMode ? Colors.indigo[900] : Colors.indigo[50],
              child: Text(totalQty.toString(), 
                style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.indigo)
              ),
            ),
            title: Text(Translate.text(context, data['productName'] ?? "صنف قديم", "Old Product"), 
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor) // هنا اللون الأسود في اللايت
            ),
            subtitle: Text("${data['subCategory'] ?? '---'} • ${data['barcode'] ?? '---'}",
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${data['price'] ?? 0} ج.م", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)
                ),
                Text(Translate.text(context, "إجمالي رصيد", "Total Stock"), style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[500] : Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(String title, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      width: double.infinity,
      color: isDarkMode ? Colors.grey[900] : Colors.blue[50], // خلفية العنوان
      child: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: isDarkMode ? Colors.white : const Color(0xFF0D47A1) // لون العنوان
        )
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, bool isDarkMode, {String? label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.blueGrey[200] : const Color(0xFF0D47A1)),
      filled: true,
      fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50], // لون خلفية الحقل
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _isLoading ? null : _saveProduct,
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(Translate.text(context, "حفظ وتوزيع الصنف", "Save and Distribute Product"), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _buildCategorySelectors(bool isDarkMode, Color textColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  return DropdownButtonFormField<String>(
                    dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white, // لون القائمة المنسدلة
                    initialValue: _selectedCat,
                    style: TextStyle(color: textColor), // لون النص المختار
                    hint: Text(Translate.text(context, "اختر التصنيف الرئيسي", "Choose Main Category"), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700])),
                    decoration: _inputDecoration(Icons.category, isDarkMode),
                    items: snapshot.hasData ? snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']))).toList() : [],
                    onChanged: (val) => setState(() { _selectedCat = val; _selectedSubCat = null; }),
                  );
                },
              ),
            ),
            IconButton(icon: Icon(Icons.add_circle, color: isDarkMode ? Colors.blueAccent : const Color(0xFF0D47A1)), onPressed: () => _addNewCategoryDialog(isMainCategory: true, isDarkMode: isDarkMode, textColor: textColor)),
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
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      initialValue: _selectedSubCat,
                      style: TextStyle(color: textColor),
                      hint: Text(Translate.text(context, "اختر التصنيف الفرعي", "Choose Subcategory"), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700])),
                      decoration: _inputDecoration(Icons.account_tree_outlined, isDarkMode),
                      items: snapshot.hasData ? snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']))).toList() : [],
                      onChanged: (val) => setState(() => _selectedSubCat = val),
                    );
                  },
                ),
              ),
              IconButton(icon: Icon(Icons.add_circle_outline, color: isDarkMode ? Colors.blueAccent : const Color(0xFF0D47A1)), onPressed: () => _addNewCategoryDialog(isMainCategory: false, isDarkMode: isDarkMode, textColor: textColor)),
            ],
          ),
        ],
      ],
    );
  }

  void _addNewCategoryDialog({required bool isMainCategory, required bool isDarkMode, required Color textColor}) {
    TextEditingController newCatController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isMainCategory ? Translate.text(context, "إضافة رئيسي جديد", "Add New Main Category") : Translate.text(context, "إضافة فرعي لـ $_selectedCat", "Add Subcategory to $_selectedCat"), style: TextStyle(color: textColor)),
        content: TextField(
          controller: newCatController, 
          style: TextStyle(color: textColor),
          decoration: _inputDecoration(Icons.add_box, isDarkMode)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child:  Text(  Translate.text(context, "إلغاء", "Cancel"), style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
            if (newCatController.text.isNotEmpty) {
              String name = newCatController.text.trim();
              if (isMainCategory) {
                await FirebaseFirestore.instance.collection('categories').doc(name).set({'name': name});
              } else {
                await FirebaseFirestore.instance.collection('categories').doc(_selectedCat).collection('subcategories').add({'name': name});
              }
              Navigator.pop(context);
            }
          }, child: Text(Translate.text(context, "حفظ", "Save"), style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(padding: const EdgeInsets.all(20.0), child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)));
  }
}