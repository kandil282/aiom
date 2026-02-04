import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePaymentSheet extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CreatePaymentSheet({super.key, required this.customerId, required this.customerName});

  @override
  State<CreatePaymentSheet> createState() => _CreatePaymentSheetState();
}

class _CreatePaymentSheetState extends State<CreatePaymentSheet> {
  final TextEditingController _amountController = TextEditingController();

  Future<void> _savePayment() async {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    // توليد رقم السند
    String receiptNo = "PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // 1. تسجيل السند في كولكشن المدفوعات
    DocumentReference payRef = FirebaseFirestore.instance.collection('payments').doc();
    batch.set(payRef, {
      'receiptNo': receiptNo,
      'customerId': widget.customerId,
      'customerName': widget.customerName,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
    });

    // 2. خصم المبلغ من مديونية العميل
    DocumentReference custRef = FirebaseFirestore.instance.collection('customers').doc(widget.customerId);
    batch.update(custRef, {'balance': FieldValue.increment(-amount)});

    await batch.commit();
    Navigator.pop(context); // إغلاق الشيت بعد الحفظ
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم حفظ السند رقم $receiptNo بنجاح ✅"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // لرفع الشيت فوق الكيبورد
        top: 25, left: 25, right: 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("تحصيل مبلغ من: ${widget.customerName}", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: "المبلغ المحصل",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _savePayment,
            child: const Text("تأكيد وحفظ السند", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}