import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierStatementPage extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierStatementPage({
    super.key, 
    required this.supplierId, 
    required this.supplierName
  });

  @override
  State<SupplierStatementPage> createState() => _SupplierStatementPageState();
}

class _SupplierStatementPageState extends State<SupplierStatementPage> {
  
  // دالة تسجيل عملية دفع (سند صرف) + تسجيلها في المصاريف
 // دالة تسجيل عملية دفع (سند صرف) مربوطة بالخزينة
  void _showPaymentDialog(double currentBalance) {
    final amountCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B), // متوافق مع الدارك مود
        title: Text("سداد للمورد: ${widget.supplierName}", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // عرض رصيد الخزنة الحالي للمستخدم قبل الصرف (اختياري)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('vault').doc('main_vault').snapshots(),
              builder: (context, vSnap) {
                double vaultBalance = 0;
                if (vSnap.hasData && vSnap.data!.exists) {
                  vaultBalance = (vSnap.data!['balance'] ?? 0).toDouble();
                }
                return Text("المتاح في الخزنة: ${vaultBalance.toStringAsFixed(2)} ج.م",
                    style: TextStyle(color: vaultBalance <= 0 ? Colors.red : Colors.greenAccent, fontSize: 13));
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "المبلغ المدفوع",
                labelStyle: TextStyle(color: Colors.white70),
                suffixText: "ج.م",
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () async {
              if (amountCtrl.text.isEmpty) return;
              
              double amountToPay = double.parse(amountCtrl.text);
              if (amountToPay <= 0) return;

              // --- بدء عملية التحقق والخصم ---
              try {
                // 1. الحصول على رصيد الخزنة الحالي
                DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
                DocumentSnapshot vaultDoc = await vaultRef.get();
                
                double currentVaultBalance = 0;
                if (vaultDoc.exists) {
                  currentVaultBalance = (vaultDoc['balance'] ?? 0).toDouble();
                }

                // 2. التحقق من كفاية الرصيد
                if (amountToPay > currentVaultBalance) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("❌ الرصيد في الخزنة غير كافٍ!"), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                // 3. تنفيذ العمليات في Batch واحد
                WriteBatch batch = FirebaseFirestore.instance.batch();

                // أ- خصم من الخزنة
                batch.update(vaultRef, {
                  'balance': FieldValue.increment(-amountToPay),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // ب- تسجيل حركة في سجل الخزنة
                DocumentReference vaultTransRef = FirebaseFirestore.instance.collection('vault_transactions').doc();
                batch.set(vaultTransRef, {
                  'type': 'expense', // صادر
                  'category': 'دفعات موردين',
                  'amount': amountToPay,
                  'description': 'سداد للمورد: ${widget.supplierName}',
                  'date': FieldValue.serverTimestamp(),
                });

                // ج- تسجيل الحركة في كشف حساب المورد (purchases)
                DocumentReference payRef = FirebaseFirestore.instance.collection('purchases').doc();
                batch.set(payRef, {
                  'supplierId': widget.supplierId,
                  'supplierName': widget.supplierName,
                  'totalAmount': amountToPay,
                  'type': 'payment',
                  'date': FieldValue.serverTimestamp(),
                  'note': 'سداد نقدي من الخزنة الرئيسية'
                });

                // د- تحديث مديونية المورد
                DocumentReference supRef = FirebaseFirestore.instance.collection('suppliers').doc(widget.supplierId);
                batch.update(supRef, {
                  'balance': FieldValue.increment(-amountToPay)
                });

                // هـ- تسجيل في المصاريف العامة (اختياري حسب نظامك)
                DocumentReference expRef = FirebaseFirestore.instance.collection('expenses').doc();
                batch.set(expRef, {
                  'title': 'دفعة للمورد: ${widget.supplierName}',
                  'amount': amountToPay,
                  'category': 'دفعات موردين',
                  'date': FieldValue.serverTimestamp(),
                });

                await batch.commit();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ تم السداد وخصم المبلغ من الخزنة"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ في العملية: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("تأكيد السداد والخصم"),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("كشف حساب: ${widget.supplierName}"),
        backgroundColor: const Color(0xff134e4a),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. كارت الملخص المالي العلوي
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('suppliers').doc(widget.supplierId).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              var data = snap.data!.data() as Map<String, dynamic>? ?? {};
              double balance = (data['balance'] ?? 0).toDouble();
              
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xff134e4a),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))
                ),
                child: Column(
                  children: [
                    const Text("إجمالي المديونية المستحقة", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text("${balance.toStringAsFixed(2)} ج.م", 
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(balance),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text("تسجيل سداد نقدي", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800], 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                    )
                  ],
                ),
              );
            },
          ),

          // 2. سجل الحركات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('purchases')
                  .where('supplierId', isEqualTo: widget.supplierId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("خطأ: ${snap.error}"));
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text("لا توجد حركات مسجلة"));

                // الترتيب اليدوي (الأحدث أولاً)
                var docs = snap.data!.docs;
                List<DocumentSnapshot> sortedDocs = List.from(docs);
                sortedDocs.sort((a, b) {
                  Timestamp tA = (a.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
                  Timestamp tB = (b.data() as Map<String, dynamic>)['date'] ?? Timestamp.now();
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, i) {
                    var data = sortedDocs[i].data() as Map<String, dynamic>;
                    bool isPayment = data['type'] == 'payment';
                    double amount = (data['totalAmount'] ?? 0).toDouble();
                    
                    String formattedDate = "";
                    if (data['date'] != null && data['date'] is Timestamp) {
                      formattedDate = (data['date'] as Timestamp).toDate().toString().substring(0, 16);
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPayment ? Colors.green[100] : Colors.red[100],
                          child: Icon(
                            isPayment ? Icons.call_made : Icons.call_received, 
                            color: isPayment ? Colors.green[900] : Colors.red[900],
                          ),
                        ),
                        title: Text(
                          isPayment ? "سداد نقدية (صرف)" : "فاتورة مشتريات (مديونية)",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formattedDate),
                            if(data['note'] != null) Text(data['note'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Text(
                          "${isPayment ? '-' : '+'}${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isPayment ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                        onTap: isPayment ? null : () => _showInvoiceDetails(data['items'] ?? []),
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

  // نافذة عرض تفاصيل الفاتورة
  void _showInvoiceDetails(List items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              const Text("تفاصيل أصناف الفاتورة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index];
                    return Card(
                      color: Colors.grey[50],
                      child: ListTile(
                        title: Text(item['materialName'] ?? "خامة", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("الكمية: ${item['qty']}  ×  السعر: ${item['buyPrice']}"),
                        trailing: Text("${item['subTotal']} ج.م", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}