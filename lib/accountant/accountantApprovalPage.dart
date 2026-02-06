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
    // تعريف متغيرات الثيم للوصول السريع
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // لون الخلفية يستجيب للثيم
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("اعتماد مبيعات المناديب"),
        // إذا كان دارك مود نستخدم لون الكارت، وإذا لا نستخدم اللون البنفسجي
        backgroundColor: isDark ? theme.cardColor : const Color(0xff692960),
        centerTitle: true,
        elevation: 0,
        actions: [
          _buildProductionBadge(isDark),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          // ملخص سريع مستجيب للثيم
          _buildHeaderSummary(theme),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('agent_orders')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                if (snap.data!.docs.isEmpty) {
                  return Center(
                    child: Text("لا توجد طلبات مبيعات بانتظار الاعتماد", 
                      style: TextStyle(color: theme.hintColor)),
                  );
                }

                return ListView.builder(
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (context, i) {
                    var orderDoc = snap.data!.docs[i];
                    var orderData = orderDoc.data() as Map<String, dynamic>;
                    List items = orderData['items'] ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      // في الدارك مود نلغي الظل ونعتمد على تباين لون الكارت
                      elevation: isDark ? 0 : 2,
                      child: ExpansionTile(
                        iconColor: theme.primaryColor,
                        collapsedIconColor: theme.hintColor,
                        leading: CircleAvatar(
                          backgroundColor: isDark ? theme.primaryColor.withOpacity(0.2) : const Color(0xff692960),
                          child: Icon(Icons.person, color: isDark ? theme.primaryColor : Colors.white)
                        ),
                        title: Text("المندوب: ${orderData['agentName'] ?? 'بدون اسم'}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        subtitle: Text("إجمالي الفاتورة: ${orderData['totalAmount']} ج.م",
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w500)),
                        children: [
                          const Divider(),
                          ...items.map((item) => ListTile(
                            title: Text(item['productName'], style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                            trailing: Text("الكمية: ${item['qty']}", style: TextStyle(color: theme.hintColor)),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isProcessing ? null : () => _approveOrder(orderDoc.id, orderData),
                              icon: const Icon(Icons.check_circle),
                              label: const Text("اعتماد وتعديل الكميات", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
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
              Text("طلبات الإنتاج القائمة", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor)),
              const Divider(),
              if (docs.isEmpty) 
                const Padding(padding: EdgeInsets.all(20.0), child: Text("لا توجد طلبات تصنيع")),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.build_circle, color: Colors.orange),
                      title: Text(data['productName'] ?? "منتج", style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                      subtitle: Text("الكمية: ${data['quantity']}", style: TextStyle(color: theme.hintColor)),
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

  Widget _buildHeaderSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: theme.cardColor.withOpacity(0.5),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "عند الاعتماد: سيتم صرف المتاح فقط وتعديل الفاتورة آلياً بناءً على مخزونك الحالي.",
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
          ),
        ],
      ),
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
    String agentName = data['agentName'] ?? 'غير معروف';
    String agentId = data['agentId'] ?? 'unknown_agent'; // التأكد من وجود ID المندوب
    
    // جلب بيانات العميل
    DocumentSnapshot custDoc = await FirebaseFirestore.instance.collection('customers').doc(customerId).get();
    String customerName = custDoc.exists ? (custDoc.get('name') ?? 'عميل') : 'عميل';
    String customerPhone = custDoc.exists ? (custDoc.get('phone') ?? '') : '';

    List items = data['items'] ?? [];
    
    for (var item in items) {
      String pId = item['productId'];
      String pName = item['productName'];
      int requestedQty = (item['qty'] ?? 0).toInt();
      double price = (item['price'] ?? 0.0).toDouble();

      // جلب بيانات المنتج لضمان الفئات (Categories) للتقارير
      var productDoc = await FirebaseFirestore.instance.collection('products').doc(pId).get();
      String category = productDoc.exists ? (productDoc.get('category') ?? 'عام') : 'عام';
      String subCategory = productDoc.exists ? (productDoc.get('subCategory') ?? 'عام') : 'عام';

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

    if (finalInvoiceItems.isEmpty) throw "لا يوجد مخزون كافٍ لإتمام العملية";

    // 1. إضافة الفاتورة للشحن
    DocumentReference invDocRef = FirebaseFirestore.instance.collection('invoices').doc();
    batch.set(invDocRef, {
      'customerId': customerId,
      'customerName': customerName,
      'items': finalInvoiceItems,
      'totalAmount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'shippingStatus': 'ready',
      'source': 'agent_order',
      'agentId': agentId,
    });

    // 2. الكوليكشن الجديد الموحد (المصدر الأساسي للتقارير)
    DocumentReference globalTransDoc = FirebaseFirestore.instance.collection('global_transactions').doc();
    batch.set(globalTransDoc, {
      'transactionId': globalTransDoc.id,
      'type': 'invoice',
      'source': 'agent',          // لتوضيح أنها مبيعات مناديب
      'amount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'customerId': customerId,
      'customerName': customerName,
      'agentId': agentId,         // مهم جداً لتقرير مدير المبيعات
      'agentName': agentName,
      'items': finalInvoiceItems, 
      'invoiceRef': invDocRef.id,
      'orderRef': orderId,
    });

    // 3. تحديث مديونية العميل وسجل معاملاته المحلي
    batch.update(FirebaseFirestore.instance.collection('customers').doc(customerId), {
      'balance': FieldValue.increment(totalInvoicedAmount)
    });
    
    DocumentReference localTransRef = FirebaseFirestore.instance
        .collection('customers').doc(customerId)
        .collection('transactions').doc();
    batch.set(localTransRef, {
      'type': 'invoice',
      'amount': totalInvoicedAmount,
      'date': FieldValue.serverTimestamp(),
      'agentName': agentName,
      'items': finalInvoiceItems,
    });

    // 4. تحديث طلب المندوب الأصلي
    batch.update(FirebaseFirestore.instance.collection('agent_orders').doc(orderId), {
      'status': 'approved', 
      'finalAmount': totalInvoicedAmount,
      'processedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    if (mounted) _showSuccess("تم الاعتماد وتحديث التقارير المركزية ✅");

  } catch (e) {
    if (mounted) _showError("خطأ: $e");
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}


}