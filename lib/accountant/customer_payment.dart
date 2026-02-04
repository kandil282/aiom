import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentEntryPage extends StatefulWidget {
  final String userId;
  final String agentName;

  const PaymentEntryPage({super.key, required this.userId, required this.agentName});

  @override
  State<PaymentEntryPage> createState() => _PaymentEntryPageState();
}

class _PaymentEntryPageState extends State<PaymentEntryPage> {
  String? selectedCustomerId;
  String? selectedCustomerName;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  // --- دالة الطباعة (داخل الكلاس عشان تشوف widget) ---
  Future<void> _printReceipt(String receiptNo, String customer, String amount) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text("RECEIPT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text("No: $receiptNo"),
            pw.Text("Customer: $customer"),
            pw.Text("Amount: $amount EGP"),
            pw.Text("Agent: ${widget.agentName}"), // كدة widget مش هتعمل إيرور
            pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
            pw.SizedBox(height: 10),
            pw.Text("Thank You!"),
          ],
        ),
      ),
    
    
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveAndProcess() async {
    if (selectedCustomerId == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إدخال كافة البيانات")));
      return;
    }

    setState(() => _isLoading = true);
    String receiptNo = "PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    double amount = double.parse(_amountController.text);

    try {
      // استخدام Batch لضمان تنفيذ كل العمليات مع بعض أو لا شيء
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. إضافة الحركة لكشف حساب العميل (عشان تظهر في ListView الكشف)
      DocumentReference transRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(selectedCustomerId)
          .collection('transactions')
          .doc();

      batch.set(transRef, {
        'type': 'payment', // مهم جداً عشان التميز عن الـ invoice
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'details': "سند قبض نقدي رقم: $receiptNo",
        'agentName': widget.agentName,
        'receiptNo': receiptNo,
      });

      // 2. تحديث رصيد العميل (خصم المبلغ من المديونية)
      // لاحظ بنستخدم increment مع إشارة سالب عشان ننقص الرصيد
      DocumentReference customerRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(selectedCustomerId);

      batch.update(customerRef, {
        'balance': FieldValue.increment(-amount) 
      });

      // 3. حفظ نسخة في كوليكشن المدفوعات العام (اختياري كما كنت تفعل)
      DocumentReference paymentRef = FirebaseFirestore.instance.collection('payments').doc();
      batch.set(paymentRef, {
        'amount': amount,
        'customerId': selectedCustomerId,
        'customerName': selectedCustomerName,
        'agentId': widget.userId,
        'receiptNo': receiptNo,
        'date': FieldValue.serverTimestamp(),
      });

      // تنفيذ الـ Batch
      await batch.commit();

      // تشغيل الطباعة
      await _printReceipt(receiptNo, selectedCustomerName!, _amountController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ السند وتحديث الحساب ✅")));
        Navigator.pop(context); // اقفل الصفحة بعد النجاح
      }

    } catch (e) {
      print("Error in payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // خلفية هادية
      appBar: AppBar(
        title: const Text("إصدار سند قبض نقدية"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent[700],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // كارت اختيار العميل
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: Colors.blueAccent),
                            SizedBox(width: 10),
                            Text("بيانات العميل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                hintText: "اختر اسم العميل من القائمة",
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: snapshot.data!.docs.map((doc) => DropdownMenuItem(
                                value: doc.id,
                                child: Text(doc['name']),
                                onTap: () => selectedCustomerName = doc['name'],
                              )).toList(),
                              onChanged: (val) => setState(() => selectedCustomerId = val),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // كارت المبلغ
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.money, color: Colors.green),
                            SizedBox(width: 10),
                            Text("المبلغ والتحصيل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.attach_money),
                            hintText: "0.00",
                            suffixText: "جنية مصري",
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // زر الحفظ والطباعة (اللمسة النهائية)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _saveAndProcess,
                    icon: const Icon(Icons.print, size: 28),
                    label: const Text("حفظ وطباعة السند", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}