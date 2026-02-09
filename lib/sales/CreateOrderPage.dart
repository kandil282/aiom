import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgentOrderPage extends StatefulWidget {
  final dynamic agentId;
  const AgentOrderPage({super.key, this.agentId});

  @override
  State<AgentOrderPage> createState() => _AgentOrderPageState();
}

class _AgentOrderPageState extends State<AgentOrderPage> {
  String? selectedCustomerId;
  String? selectedCategory;
  String? selectedSubCategory;
  String? selectedProductId;
  String? selectedProductName;
  double? selectedProductPrice;
  int quantity = 1;
  int availableStock = 0;

  List<Map<String, dynamic>> orderItems = [];

  // دالة جلب المخزون
// استبدل دالة _updateAvailableStock بهذا الكود الخفيف
Future<void> _updateAvailableStock(String prodId) async {
  try {
    var doc = await FirebaseFirestore.instance.collection('products').doc(prodId).get();
    if (doc.exists) {
      setState(() {
        // قراءة مباشرة من الحقل الذي حدثناه في الإنتاج والفواتير
        availableStock = (doc.data()?['totalQuantity'] ?? 0) as int;
      });
    }
  } catch (e) {
    setState(() => availableStock = 0);
  }
}
void _addItemToOrder() {
  if (selectedProductId != null && quantity > 0) {
    setState(() {
      orderItems.add({
        'productId': selectedProductId,
        'productName': selectedProductName,
        'category': selectedCategory,      // ✅ أضفنا التصنيف
        'subCategory': selectedSubCategory, // ✅ أضفنا التصنيف الفرعي
        'price': selectedProductPrice,
        'qty': quantity,
        'total': quantity * selectedProductPrice!,
      });
      // تصفير الاختيارات بعد الإضافة
      selectedProductId = null;
      availableStock = 0;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    // جلب ألوان الثيم
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // خلفية متغيرة
      appBar: AppBar(
        title:  Text(Translate.text(context, "أوردر مندوب جديد", "New Agent Order")),
        backgroundColor: isDark ? theme.cardColor : const Color(0xff692960),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCustomerSelector(theme),
            _buildProductFilterSection(theme, isDark),
            _buildOrderTable(theme),
            _buildSubmitSection(theme),
          ],
        ),
      ),
    );
  }

  // 1. اختيار العميل - متكيف مع الثيم
  Widget _buildCustomerSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(15),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('customers').where('agentId', isEqualTo: widget.agentId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          return DropdownButtonFormField<String>(
            dropdownColor: theme.cardColor, // لون القائمة في الدارك مود
            decoration: _inputDecoration(theme, Translate.text(context, "اختر العميل", "Select Customer") ),
            items: snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(),
            onChanged: (val) {
                              setState(() {
                                selectedCustomerId = val;
                              });
                            },
          );
        },
      ),
    );
  }

  // 2. فلترة المنتجات - متكيف مع الثيم
  Widget _buildProductFilterSection(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.grey[50], // خلفية غامقة في الدارك مود
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          _buildCategoryDropdown(theme),
          const SizedBox(height: 10),
          if (selectedCategory != null) _buildSubCategoryDropdown(theme),
          const SizedBox(height: 10),
          if (selectedSubCategory != null) _buildProductAndQtySection(theme),
        ],
      ),
    );
  }

  // --- دوال مساعدة لتقليل تكرار الكود واستجابة الثيم ---

  Widget _buildCategoryDropdown(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var cats = snap.data!.docs.map((d) => d['category'] as String).toSet().toList();
        return DropdownButtonFormField<String>(
          dropdownColor: theme.cardColor,
          decoration: _inputDecoration(theme, Translate.text(context, "التصنيف الرئيسي", "Main Category")),
          items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) => setState(() {
            selectedCategory = val;
            selectedSubCategory = null;
            selectedProductId = null;
          }),
        );
      },
    );
  }

  Widget _buildSubCategoryDropdown(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').where('category', isEqualTo: selectedCategory).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var subCats = snap.data!.docs.map((d) => (d.data() as Map)['subCategory']?.toString() ?? "عام").toSet().toList();
        return DropdownButtonFormField<String>(
          dropdownColor: theme.cardColor,
          decoration: _inputDecoration(theme, Translate.text(context, "التصنيف الفرعى", "Sub Category")),
          items: subCats.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() {
            selectedSubCategory = val;
            selectedProductId = null;
          }),
        );
      },
    );
  }

  Widget _buildProductAndQtySection(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: selectedCategory)
          .where('subCategory', isEqualTo: selectedSubCategory)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        return Column(
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: theme.cardColor,
              decoration: _inputDecoration(theme, Translate.text(context, "اختر المنتج", "Select Product")),
              items: snap.data!.docs.map((d) {
                var data = d.data() as Map;
                return DropdownMenuItem(value: d.id, child: Text("${data['productName']} - ${data['price']}ج"));
              }).toList(),
              onChanged: (val) {
                var doc = snap.data!.docs.firstWhere((e) => e.id == val);
                var data = doc.data() as Map;
                setState(() {
                  selectedProductId = val;
                  selectedProductName = data['productName'];
                  selectedProductPrice = (data['price'] ?? 0).toDouble();
                });
                _updateAvailableStock(val!);
              },
            ),
            if (selectedProductId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(Translate.text(context, "المخزن: $availableStock قطعة", "Available Stock: $availableStock Pieces"), 
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(theme, Translate.text(context, "الكمية", "Quantity")),
                  onChanged: (v) => quantity = int.tryParse(v) ?? 1,
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addItemToOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildOrderTable(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orderItems.length,
      itemBuilder: (context, i) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        child: ListTile(
          title: Text(orderItems[i]['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(Translate.text(context, "${orderItems[i]['qty']} x ${orderItems[i]['price']} ج.م", "${orderItems[i]['qty']} x ${orderItems[i]['price']} EGP")  ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent), 
            onPressed: () => setState(() => orderItems.removeAt(i))
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitSection(ThemeData theme) {
    double total = orderItems.fold(0, (sum, item) => sum + item['total']);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Divider(color: theme.dividerColor),
          Text(Translate.text(context, "إجمالي الطلبية: $total ج.م", "Total Order Amount: $total EGP"), 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.dividerColor)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: (selectedCustomerId == null || orderItems.isEmpty) ? null : _submitToFirestore,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.brightness == Brightness.dark ? theme.primaryColor : const Color(0xff692960),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
            ),
            child:  Text(Translate.text(context, "إرسال الطلبية للمحاسب 📤", "Submit Order to Accountant"), style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.hintColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor,
    );
  }

Future<void> _submitToFirestore() async {
  if (selectedCustomerId == null || orderItems.isEmpty) return;

  try {
    // 1. جلب بيانات المندوب والعميل لضمان عدم ظهور "غير معروف" عند المحاسب
    var agentSnap = await FirebaseFirestore.instance.collection('users').doc(widget.agentId).get();
    String agentName = agentSnap.exists ? (agentSnap.data()?['name'] ?? Translate.text(context, "غير معروف", "Unknown")) : Translate.text(context, "مندوب", "Agent");

    var customerSnap = await FirebaseFirestore.instance.collection('customers').doc(selectedCustomerId).get();
    String customerName = customerSnap.exists ? (customerSnap.data()?['name'] ?? Translate.text(context, "غير معروف", "Unknown")) : Translate.text(context, "عميل", "Customer");

    // 2. تجهيز قائمة الأصناف (تأكيد إرسال Category و SubCategory)
    // هنا نضمن أن كل حقل تمت إضافته في _addItemToOrder سيصل للـ Firebase
    List<Map<String, dynamic>> finalItems = orderItems.map((item) => {
      'productId': item['productId'],
      'productName': item['productName'],
      'category': item['category'],       // ✅ مضاف الآن للكوليكشن
      'subCategory': item['subCategory'], // ✅ مضاف الآن للكوليكشن
      'price': item['price'],
      'qty': item['qty'],
      'total': item['total'],
    }).toList();

    // 3. إرسال الطلبية كاملة البيانات لكوليكشن agent_orders
    await FirebaseFirestore.instance.collection('agent_orders').add({
      'agentId': widget.agentId,
      'agentName': agentName,      
      'customerId': selectedCustomerId,
      'customerName': customerName, 
      'items': finalItems,         // القائمة الكاملة مع التصنيفات
      'totalAmount': orderItems.fold(0.0, (sum, item) => sum + item['total']),
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(Translate.text(context, "تم إرسال الطلبية بنجاح ✅", "Order Submitted Successfully ✅")), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translate.text(context, "فشل الإرسال: $e", "Submission Failed: $e")), backgroundColor: Colors.red)
      );
    }
    print("Firebase Error: $e");
  }
}
}