import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class TaxInvoicePage extends StatelessWidget {
  const TaxInvoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("فاتورة ضريبية").tr(),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.print), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. رأس الفاتورة (بيانات الشركة والـ QR)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("اسم الشركة الخاصة بك", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text("الرقم الضريبي: 123-456-789"),
                    const Text("العنوان: القاهرة، مصر"),
                  ],
                ),
                // الـ QR Code (مهم جداً للفاتورة المصرية)
                Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.qr_code_2, size: 70),
                )
              ],
            ),
            const Divider(height: 30, thickness: 2),

            // 2. بيانات الفاتورة والعميل
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("رقم الفاتورة: #INV-2026-001"),
                Text("التاريخ: ${DateTime.now().toString().split(' ')[0]}"),
              ],
            ),
            const SizedBox(height: 10),
            const Text("بيانات العميل:", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("اسم العميل: شركة الأمل للتجارة"),
            const Text("الرقم الضريبي للعميل: 987-654-321"),
            
            const SizedBox(height: 20),

            // 3. جدول الأصناف
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                // رأس الجدول
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text("الصنف", style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text("الكمية", style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text("السعر", style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8), child: Text("الإجمالي", style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                // مثال لصنف
                _buildTableRow("منتج تجريبي 1", "2", "500", "1000"),
                _buildTableRow("منتج تجريبي 2", "1", "2000", "2000"),
              ],
            ),

            const SizedBox(height: 30),

            // 4. ملخص الحساب والضرائب
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 200,
                child: Column(
                  children: [
                    _buildSummaryRow("الإجمالي الفرعي:", "3000 ج.م"),
                    _buildSummaryRow("ضريبة القيمة المضافة (14%):", "420 ج.م"),
                    const Divider(thickness: 1),
                    _buildSummaryRow("الإجمالي النهائي:", "3420 ج.م", isTotal: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة بناء صفوف الجدول
  TableRow _buildTableRow(String name, String qty, String price, String total) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(name)),
      Padding(padding: const EdgeInsets.all(8), child: Text(qty)),
      Padding(padding: const EdgeInsets.all(8), child: Text(price)),
      Padding(padding: const EdgeInsets.all(8), child: Text(total)),
    ]);
  }

  // دالة بناء صفوف الملخص
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.blue : Colors.black)),
        ],
      ),
    );
  }
}
