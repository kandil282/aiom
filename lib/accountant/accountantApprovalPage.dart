import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountantApprovalPage extends StatefulWidget {
  const AccountantApprovalPage({super.key});

  @override
  State<AccountantApprovalPage> createState() => _AccountantApprovalPageState();
}

class _AccountantApprovalPageState extends State<AccountantApprovalPage> {
  bool _isProcessing = false;

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,
    appBar: AppBar(
      title: Text(Translate.text(context, "اعتماد مبيعات المناديب", "Approve Agent Sales")),
      backgroundColor: isDark ? theme.cardColor : const Color(0xff692960),
      centerTitle: true,
      elevation: 0,
    ),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('agent_orders')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) {
                return Center(child: Text(Translate.text(context, "لا توجد طلبات معلقة", "No pending orders"), style: TextStyle(color: theme.hintColor)));
              }

              return ListView.builder(
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, i) {
                  var orderDoc = snap.data!.docs[i];
                  var orderData = orderDoc.data() as Map<String, dynamic>;
                  List items = orderData['items'] ?? [];
                  String customerId = orderData['customerId'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: theme.cardColor,
                    child: (customerId.isEmpty) 
                      ?  ListTile(title: Text(Translate.text(context, "بيانات العميل ناقصة (ID فارغ)", "Missing Customer Data (Empty ID)")))
                      : FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('customers').doc(customerId).get(),
                          builder: (context, custSnap) {
                            // 1. استخراج البيانات من وثيقة العميل
                            String customerName = Translate.text(context, "تحميل...", "Loading...");
                            String agentName = Translate.text(context, "إدارة المكتب", "Office Management");

                            if (custSnap.hasData && custSnap.data!.exists) {
                              var custData = custSnap.data!.data() as Map<String, dynamic>;
                              customerName = custData['name'] ?? Translate.text(context, "عميل بدون اسم", "Unnamed Customer");
                              agentName = custData['addedByAgent'] ?? Translate.text(context, "إدارة المكتب", "Office Management");
                            }

                            return ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: theme.primaryColor.withOpacity(0.1),
                                child: Icon(Icons.person, color: theme.primaryColor),
                              ),
                              // عرض اسم العميل
                              title: Text(
                                "العميل: $customerName",
                                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              // عرض اسم المندوب من حقل addedByAgent
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Translate.text(context, "المندوب: $agentName", "Agent: $agentName"), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                                  Text(Translate.text(context, "إجمالي: ${orderData['totalAmount']} ج.م", "Total: ${orderData['totalAmount']} EGP"), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                  child: Column(
                                    children: [
                                      ...items.map((item) => ListTile(
                                        title: Text(Translate.text(context, item['productName'] ?? "منتج", "Unnamed Product"), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text("${item['category'] ?? Translate.text(context, "عام", "General")} / ${item['subCategory'] ?? Translate.text(context, "عام", "General")}"),
                                        trailing: Text(Translate.text(context, "الكمية: ${item['qty']}", "Quantity: ${item['qty']}"), style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                      const SizedBox(height: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 50),
                                        ),
                                        onPressed: _isProcessing ? null : () => _approveOrder(orderDoc.id, orderData),
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: Text(Translate.text(context, "اعتماد الفاتورة الآن", "Approve Invoice Now")),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
 
 
 
 
 Widget _buildProductionBadge(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('production_orders')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        int count = snap.hasData ? snap.data!.docs.length : 0;
        return IconButton(
          onPressed: () => _showProductionOrdersSheet(context, snap.data?.docs ?? []),
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            backgroundColor: Colors.orange,
            child: Icon(Icons.factory_outlined, color: isDark ? Colors.tealAccent : Colors.white, size: 28),
          ),
        );
      },
    );
  }

  void _showProductionOrdersSheet(BuildContext context, List<QueryDocumentSnapshot> docs) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 15),
              Text(Translate.text(context, "طلبات الإنتاج القائمة", "Pending Production Orders"), 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor)),
              const Divider(),
              if (docs.isEmpty) 
                 Padding(padding: EdgeInsets.all(20.0), child: Text(Translate.text(context, "لا توجد طلبات تصنيع", "No Production Orders"))),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.build_circle, color: Colors.orange),
                      title: Text(Translate.text(context, data['productName'] ?? "منتج", "Unnamed Product"), style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                      subtitle: Text(Translate.text(context, "الكمية: ${data['quantity']}", "Quantity: ${data['quantity']}"), style: TextStyle(color: theme.hintColor)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // --- بقية الدوال (approveOrder, Success, Error) تبقى كما هي مع التأكد من استخدام context.mounted ---
  // (تم اختصارها هنا لضمان التركيز على الـ UI)
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


Future<void> _approveOrder(String orderId, Map<String, dynamic> data) async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  WriteBatch batch = FirebaseFirestore.instance.batch();
  double totalInvoicedAmount = 0.0;
  List<Map<String, dynamic>> finalInvoiceItems = [];

  try {
    String customerId = data['customerId'];
    
    // 1. 🔥 جلب بيانات العميل (عشان نجيب المندوب المربوط بيه زي دالة الـ Invoice)
    DocumentSnapshot custDoc = await FirebaseFirestore.instance.collection('customers').doc(customerId).get();
    Map<String, dynamic> custData = custDoc.data() as Map<String, dynamic>;
    
    String customerName = custData['name'] ?? Translate.text(context, "عميل غير معروف", "Unknown Customer");
    
    // سحب بيانات المندوب من ملف العميل لضمان ظهورها
    String agentId = custData['agentId'] ?? (data['agentId'] ?? 'unknown_agent');
    String agentName = custData['addedByAgent'] ?? (data['agentName'] ?? Translate.text(context, "إدارة المكتب", "Office Management"));

    List items = data['items'] ?? [];
    
    for (var item in items) {
      String pId = item['productId'];
      String pName = item['productName'];
      int requestedQty = (item['qty'] ?? 0).toInt();
      double price = (item['price'] ?? 0.0).toDouble();

      var productDoc = await FirebaseFirestore.instance.collection('products').doc(pId).get();
      String category = productDoc.exists ? (productDoc.get('category') ?? Translate.text(context, "عام", "General")) : Translate.text(context, "عام", "General");
      String subCategory = productDoc.exists ? (productDoc.get('subCategory') ?? Translate.text(context, "عام", "General")) : Translate.text(context, "عام", "General");

      // منطق خصم المخزن
      var invSnapshot = await FirebaseFirestore.instance
          .collection('products').doc(pId).collection('inventory')
          .where('quantity', isGreaterThan: 0)
          .limit(1).get();

      int currentStock = 0;
      DocumentReference? invRef;
      if (invSnapshot.docs.isNotEmpty) {
        currentStock = (invSnapshot.docs.first.data()['quantity'] ?? 0) as int;
        invRef = invSnapshot.docs.first.reference;
      }

      int qtyToInvoice = (requestedQty <= currentStock) ? requestedQty : currentStock;
      
      if (qtyToInvoice > 0 && invRef != null) {
        batch.update(invRef, {'quantity': FieldValue.increment(-qtyToInvoice)});
        batch.update(FirebaseFirestore.instance.collection('products').doc(pId), {
          'totalQuantity': FieldValue.increment(-qtyToInvoice)
        });
        
        finalInvoiceItems.add({
          'productId': pId,
          'productName': pName,
          'category': category,
          'subCategory': subCategory,
          'qty': qtyToInvoice,
          'price': price,
          'totalPrice': qtyToInvoice * price,
        });
        
        totalInvoicedAmount += (qtyToInvoice * price);
      }
    }

    if (finalInvoiceItems.isEmpty) throw Translate.text(context, "لا يوجد مخزون كافٍ", "Insufficient inventory");

    // 2. تسجيل الفاتورة
    DocumentReference invDocRef = FirebaseFirestore.instance.collection('invoices').doc();
    batch.set(invDocRef, {
      'invoiceId': invDocRef.id,
      'customerId': customerId,
      'customerName': customerName,
      'items': finalInvoiceItems,
      'totalAmount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'shippingStatus': 'ready',
      'agentId': agentId,
      'agentName': agentName, // ✅ هيتسجل هنا
    });

    // 3. التسجيل في الكوليكشن الموحد (التقارير)
    DocumentReference globalTransDoc = FirebaseFirestore.instance.collection('global_transactions').doc();
    batch.set(globalTransDoc, {
      'transactionId': globalTransDoc.id,
      'type': 'invoice',
      'source': 'agent',
      'amount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'customerId': customerId,
      'customerName': customerName,
      'agentId': agentId,
      'agentName': agentName, // ✅ هيتسجل هنا وهينطق في الكارت
      'items': finalInvoiceItems, 
      'invoiceRef': invDocRef.id,
    });

    // 4. تحديث رصيد العميل وسجل معاملاته
    batch.update(FirebaseFirestore.instance.collection('customers').doc(customerId), {
      'balance': FieldValue.increment(totalInvoicedAmount)
    });

    DocumentReference localTransRef = FirebaseFirestore.instance
        .collection('customers').doc(customerId).collection('transactions').doc();
    batch.set(localTransRef, {
      'type': 'invoice',
      'amount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'agentName': agentName,
      'agentId': agentId,
      'items': finalInvoiceItems,
    });

    // 5. تحديث حالة الطلب
    batch.update(FirebaseFirestore.instance.collection('agent_orders').doc(orderId), {'status': 'approved'});

    await batch.commit();
    if (mounted) _showSuccess(Translate.text(context, "تم الاعتماد بنجاح ✅", "Successfully Approved ✅"));

  } catch (e) {
    if (mounted) _showError(Translate.text(context, "خطأ: $e", "Error: $e"));
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}
}