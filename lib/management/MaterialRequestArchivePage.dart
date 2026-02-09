import 'package:aiom/translate/translationhelper.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiom/configer/settings_provider.dart';
class MaterialArchivePage extends StatefulWidget {
  const MaterialArchivePage({super.key});

  @override
  State<MaterialArchivePage> createState() => _MaterialArchivePageState();
}

class _MaterialArchivePageState extends State<MaterialArchivePage> {
  DateTime? selectedDate;
  bool isDescending = true;

  // دالة الطباعة (نسخة مستقرة تدعم العربية والبيانات الكاملة)

// ... داخل الكلاس الخاص بالأرشيف ...

Future<void> _printReport(List<QueryDocumentSnapshot> docs) async {
  try {
    // 1. استخدام خط "Cairo" لأنه الأفضل في الربط التلقائي للحروف العربية في PDF
    final arabicFont = await PdfGoogleFonts.cairoMedium();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // 2. تطبيق الخط على الثيم بالكامل لضمان قراءة الحروف العربية
        theme: pw.ThemeData.withFont(base: arabicFont),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl, // تحديد الاتجاه من اليمين لليسار
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(Translate.text(context as BuildContext, "تقرير أرشيف حركة المخزن", "Material Request Archive Report"), 
                      style: pw.TextStyle(fontSize: 22, font: arabicFont)),
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(),
                    cellAlignment: pw.Alignment.centerRight,
                    headerStyle: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold),
                    context: context,
                    data: <List<String>>[
                      [Translate.text(context as BuildContext, "التاريخ", "Date"), Translate.text(context as BuildContext, "طلب بواسطة", "Requested By"), Translate.text(context as BuildContext, "الخامات والكميات", "Materials & Quantities"), Translate.text(context as BuildContext, "صرف بواسطة", "Dispatched By")],
                      ...docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        List items = data['items'] ?? [];
                        
                        // تجميع الخامات
                        String itemsText = items.map((it) => 
                          "${it['materialName']} (${it['qty']})"
                        ).join("\n");
                        
                        return [
                          data['dispatchedAt']?.toDate().toString().split(' ')[0] ?? '',
                          data['requestedBy'] ?? Translate.text(context as BuildContext, "غير معروف", "Unknown"),
                          itemsText,
                          data['dispatchedBy'] ?? Translate.text(context as BuildContext, "غير معروف", "Unknown"),
                        ];
                      })
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  } catch (e) {
    debugPrint(Translate.text(context, "خطأ في الطباعة: $e", "Error printing: $e"));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Translate.text(context , "لم يتمكن النظام من فتح الطباعة: $e", "System failed to open print: $e")))
    );
  }
}
  // دالة اختيار التاريخ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    // الاستعلام (Query)
    Query query = FirebaseFirestore.instance
        .collection('material_requests')
        .where('status', isEqualTo: 'issued')
        .orderBy('dispatchedAt', descending: isDescending);

    if (selectedDate != null) {
      DateTime startOfDay = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.where('dispatchedAt', isGreaterThanOrEqualTo: startOfDay)
                   .where('dispatchedAt', isLessThan: endOfDay);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(Translate.text(context, "سجل الحركات المنتهية", "Finished Material Requests Archive")),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(isDescending ? Icons.sort : Icons.history),
            onPressed: () => setState(() => isDescending = !isDescending),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(Translate.text(context, "يجب تفعيل الفهرس (Index) في الفايربيز", "You must enable Index in Firebase")));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snap.data!.docs;

          return Column(
            children: [
              if (docs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _printReport(docs),
                    icon: const Icon(Icons.print),
                    label: Text(Translate.text(context, "طباعة التقرير الحالي", "Print Current Report")),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ExpansionTile(
                        title: Text(Translate.text(context, "إذن: ${docs[i].id.substring(0, 5)} - ${data['requestedBy']}", "Request: ${docs[i].id.substring(0, 5)} - ${data['requestedBy']}")),
                        subtitle: Text(Translate.text(context, "التاريخ: ${data['dispatchedAt']?.toDate().toString().split('.')[0] ?? ''}", "Date: ${data['dispatchedAt']?.toDate().toString().split('.')[0] ?? ''}")),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Translate.text(context, "👤 طلب بواسطة: ${data['requestedBy']}", "👤 Requested by: ${data['requestedBy']}")),
                                // Text("💰 اعتماد مالي: ${data['approvedBy']}"),
                                Text(Translate.text(context, "📦 صرف مخزني: ${data['dispatchedBy']}", "📦 Dispatched by: ${data['dispatchedBy']}")),
                                const Divider(),
                                 Text(Translate.text(context, "الأصناف:", "Items"), style: TextStyle(fontWeight: FontWeight.bold)),
                                ...(data['items'] as List).map((item) => Text("• ${item['materialName']} (${item['qty']})")),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}