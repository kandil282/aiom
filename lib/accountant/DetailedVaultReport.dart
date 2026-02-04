import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DetailedVaultReport extends StatefulWidget {
  const DetailedVaultReport({super.key});

  @override
  State<DetailedVaultReport> createState() => _DetailedVaultReportState();
}

class _DetailedVaultReportState extends State<DetailedVaultReport> {
  DateTimeRange? selectedRange;
  String filterType = "الكل";

  // --- 1. دوال العمليات (Logic) ---

  // دالة الطباعة المصلحة (حل مشكلة List<String> الظاهرة في صورك)
  Future<void> _printPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoKufiArabicRegular();

    // تجهيز البيانات بشكل صحيح لتجنب خطأ InvalidType
    final List<List<String>> tableData = [
      ['التاريخ', 'الوصف', 'النوع', 'المبلغ'], // العناوين
    ];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      tableData.add([
        intl.DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate()),
        data['description']?.toString() ?? '',
        data['type'] == 'income' ? 'إيداع' : 'صرف',
        "${data['amount']} ج.م",
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.Center(child: pw.Text("كشف حساب الخزينة", style: pw.TextStyle(font: font, fontSize: 22))),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  data: tableData, // استخدام القائمة المجهزة مسبقاً
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // دالة التعديل (حل منطق الخزنة)
  Future<void> _updateTransaction(String docId, Map<String, dynamic> oldData, double newAmount, String newDesc) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference vaultRef = FirebaseFirestore.instance.collection('vault').doc('main_vault');
    DocumentReference transRef = FirebaseFirestore.instance.collection('vault_transactions').doc(docId);

    double oldAmount = (oldData['amount'] ?? 0).toDouble();
    bool isInc = oldData['type'] == 'income';

    batch.update(vaultRef, {'balance': FieldValue.increment(isInc ? -oldAmount : oldAmount)});
    batch.update(vaultRef, {'balance': FieldValue.increment(isInc ? newAmount : -newAmount)});
    batch.update(transRef, {'amount': newAmount, 'description': newDesc});

    await batch.commit();
  }

  // --- 2. بناء الواجهة (UI) ---

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('vault_transactions').orderBy('date', descending: true);
    
    if (selectedRange != null) {
      query = query.where('date', isGreaterThanOrEqualTo: selectedRange!.start)
                   .where('date', isLessThanOrEqualTo: selectedRange!.end.add(const Duration(days: 1)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("سجل الخزينة والطباعة"), backgroundColor: const Color(0xFF1E293B)),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text("لا توجد بيانات", style: TextStyle(color: Colors.white)));
                
                // فلترة النوع في التطبيق لتجنب الحاجة لـ Index إضافي
                var filteredDocs = snap.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (filterType == "الكل") return true;
                  return (filterType == "إيداع" && data['type'] == 'income') || (filterType == "صرف" && data['type'] == 'expense');
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _printPdf(filteredDocs),
                        icon: const Icon(Icons.print),
                        label: const Text("تحويل الملف لـ PDF وطباعته"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var data = filteredDocs[index].data() as Map<String, dynamic>;
                          bool isInc = data['type'] == 'income';
                          return Card(
                            color: const Color(0xFF1E293B),
                            child: ListTile(
                              leading: Icon(isInc ? Icons.add : Icons.remove, color: isInc ? Colors.green : Colors.red),
                              title: Text(data['description'] ?? "", style: const TextStyle(color: Colors.white)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("${data['amount']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), 
                                             onPressed: () => _showEditDialog(filteredDocs[index].id, data)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // نافذة التعديل
  void _showEditDialog(String docId, Map<String, dynamic> data) {
    TextEditingController amountCtrl = TextEditingController(text: data['amount'].toString());
    TextEditingController descCtrl = TextEditingController(text: data['description']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("تعديل الحركة", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
          TextField(controller: descCtrl, style: const TextStyle(color: Colors.white)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () {
            _updateTransaction(docId, data, double.parse(amountCtrl.text), descCtrl.text);
            Navigator.pop(context);
          }, child: const Text("حفظ")),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              dropdownColor: const Color(0xFF1E293B),
              value: filterType,
              style: const TextStyle(color: Colors.white),
              items: ["الكل", "إيداع", "صرف"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => filterType = v!),
            ),
          ),
          IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white), 
                     onPressed: () async {
                       final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
                       if (r != null) setState(() => selectedRange = r);
                     }),
        ],
      ),
    );
  }


  Future<void> _deleteTransaction(String docId, Map<String, dynamic> data) async {
    double amt = (data['amount'] ?? 0).toDouble();
    bool isInc = data['type'] == 'income';
    WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('vault').doc('main_vault'), 
                {'balance': FieldValue.increment(isInc ? -amt : amt)});
    batch.delete(FirebaseFirestore.instance.collection('vault_transactions').doc(docId));
    await batch.commit();
  }

  // --- 2. الواجهات (UI) ---

}