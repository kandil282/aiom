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
  void _showPaymentDialog(double currentBalance) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("سداد للمورد: ${widget.supplierName}"),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(
            labelText: "المبلغ المدفوع", 
            suffixText: "ج.م",
            border: OutlineInputBorder()
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (amountCtrl.text.isNotEmpty) {
                double amount = double.parse(amountCtrl.text);
                WriteBatch batch = FirebaseFirestore.instance.batch();
                
                // 1. تسجيل الحركة في جدول المشتريات (لضبط كشف حساب المورد)
                DocumentReference payRef = FirebaseFirestore.instance.collection('purchases').doc();
                batch.set(payRef, {
                  'supplierId': widget.supplierId,
                  'supplierName': widget.supplierName,
                  'totalAmount': amount,
                  'type': 'payment',
                  'date': FieldValue.serverTimestamp(),
                  'note': 'سداد نقدي للمورد'
                });

                // 2. تحديث رصيد المورد الكلي في كولكشن الموردين
                DocumentReference supRef = FirebaseFirestore.instance.collection('suppliers').doc(widget.supplierId);
                batch.update(supRef, {
                  'balance': FieldValue.increment(-amount)
                });

                // 3. تسجيل الدفعة في كولكشن المصاريف (Expenses)
                DocumentReference expRef = FirebaseFirestore.instance.collection('expenses').doc();
                batch.set(expRef, {
                  'title': 'دفعة للمورد: ${widget.supplierName}',
                  'amount': amount,
                  'category': 'دفعات موردين',
                  'subCategory': widget.supplierName,
                  'date': FieldValue.serverTimestamp(),
                  'recordedBy': 'admin@system.com', // يمكن استبداله بإيميل المستخدم الحالي
                  'details': 'تم الخصم من حساب المورد وسدادها نقدياً',
                });

                await batch.commit();
                if (mounted) Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم تسجيل الدفع وتحديث المصاريف بنجاح"))
                );
              }
            },
            child: const Text("تأكيد الدفع"),
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