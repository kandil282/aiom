import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditInvoicePage extends StatefulWidget {
  final String customerId;
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const EditInvoicePage({
    super.key,
    required this.customerId,
    required this.invoiceId,
    required this.invoiceData,
  });

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
  late List<dynamic> items;
  late double oldTotal;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // نأخذ نسخة من الأصناف الحالية لتعديلها
    items = List.from(widget.invoiceData['items'] ?? []);
    oldTotal = (widget.invoiceData['amount'] ?? 0).toDouble();
  }

  // حساب الإجمالي الجديد بناءً على الكميات المعدلة
  double get newTotal => items.fold(0, (sum, item) => sum + (item['total'] ?? 0));

  void _updateItemQty(int index, int change) {
    setState(() {
      int currentQty = (items[index]['qty'] ?? 0).toInt();
      int updatedQty = currentQty + change;

      if (updatedQty >= 0) {
        items[index]['qty'] = updatedQty;
        // إعادة حساب إجمالي الصنف الواحد (الكمية × السعر)
        double price = (items[index]['price'] ?? 0).toDouble();
        items[index]['total'] = updatedQty * price;
      }
    });
  }

  Future<void> _saveInvoice() async {
    setState(() => isSaving = true);
    try {
      double difference = newTotal - oldTotal;

      // 1. تحديث بيانات الفاتورة نفسها
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('transactions')
          .doc(widget.invoiceId)
          .update({
        'items': items,
        'amount': newTotal,
        'lastEdit': FieldValue.serverTimestamp(),
      });

      // 2. تحديث مديونية العميل بالفرق (الزيادة أو النقص)
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .update({
        'balance': FieldValue.increment(difference),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحديث الفاتورة والحساب بنجاح ✅"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء الحفظ: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تعديل محتويات الفاتورة"),
        backgroundColor: const Color(0xff692960),
      ),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(items[i]['name'] ?? items[i]['productName'] ?? "صنف غير معروف"),
                          subtitle: Text("السعر: ${items[i]['price']} ج.م"),
                          trailing: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _updateItemQty(i, -1),
                          ),
                          // خانة إدخال العدد يدوياً
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              initialValue: items[i]['qty'].toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (val) {
                                int? newQty = int.tryParse(val);
                                if (newQty != null && newQty >= 0) {
                                  _setItemQtyDirectly(i, newQty);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () => _updateItemQty(i, 1),
                          ),
  ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildTotalSection(),
              ],
            ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("الإجمالي القديم:", style: TextStyle(color: Colors.grey)),
              Text("$oldTotal ج.م", style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("الإجمالي الجديد:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${newTotal.toStringAsFixed(2)} ج.م",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff692960))),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _saveInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff692960),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("حفظ التعديلات وتحديث المديونية", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
  void _setItemQtyDirectly(int index, int newQty) {
  setState(() {
    items[index]['qty'] = newQty;
    double price = (items[index]['price'] ?? 0).toDouble();
    items[index]['total'] = newQty * price;
  });
}
}