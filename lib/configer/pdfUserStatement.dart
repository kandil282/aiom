import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfService {
  static Future<void> generateCustomerStatement({
    required String customerName,
    required List<QueryDocumentSnapshot> docs,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    double totalInvoices = 0;
    double totalPayments = 0;
    final List<List<String>> tableData = [];

    // المنطق الموحد: تصفية وحساب
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      
      // 1. استبعاد الملغي نهائياً (بكل حالات الأحرف)
      if (data['status']?.toString().toLowerCase() == 'cancelled') continue;

      double amount = (data['amount'] ?? 0).toDouble();
      bool isInvoice = data['type'] == 'invoice';
      
      if (isInvoice) {
        totalInvoices += amount;
      } else {
        totalPayments += amount;
      }

      // 2. إضافة البيانات للجدول
      tableData.add([
        data['date'] != null 
            ? intl.DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())
            : "",
        data['details'] ?? (isInvoice ? "فاتورة مبيعات" : "سند قبض"),
        "${amount.toStringAsFixed(2)} ج.م",
      ]);
    }

    double balance = totalInvoices - totalPayments;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          // الترويسة
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("كشف حساب تفصيلي", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
                  pw.Text("العميل: $customerName", style: pw.TextStyle(fontSize: 14)),
                  pw.Text("تاريخ التقرير: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}", style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Container(width: 60, height: 60, color: PdfColors.grey200), 
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // الجدول الموحد
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'البيان', 'المبلغ'],
            data: [
              ...tableData,
              ['', 'إجمالي المبيعات', '${totalInvoices.toStringAsFixed(2)} ج.م'],
              ['', 'إجمالي التحصيلات', '${totalPayments.toStringAsFixed(2)} ج.م'],
              ['', 'الرصيد المتبقي', '${balance.toStringAsFixed(2)} ج.م'],
            ],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
            cellAlignment: pw.Alignment.center,
          ),

          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("توقيع المستلم: ..................."),
              pw.Text("ختم الشركة: ..................."),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
