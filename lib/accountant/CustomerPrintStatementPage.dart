import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerStatementPage extends StatefulWidget {
  const CustomerStatementPage({super.key});

  @override
  State<CustomerStatementPage> createState() => _CustomerStatementPageState();
}

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  String? selectedCustomerId;
  String? selectedCustomerName;
  double totalBalance = 0.0;
  
  // متغيرات البحث
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  

  

  // 1. دالة تحميل الخط العربي (مهم جداً للطباعة)
  Future<pw.Font> _getFont() async {
    return await PdfGoogleFonts.cairoRegular();
  }

  // 2. دالة مساعدة لجلب تصنيف المنتج (لتفاصيل الفاتورة)
  Future<Map<String, String>> _getProductDetails(String productId) async {
    if (productId.isEmpty) return {'cat': '-', 'sub': '-'};
    try {
      var doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (doc.exists) {
        return {
          'cat': doc.data()?['category']?.toString() ?? '-',
          'sub': doc.data()?['subCategory']?.toString() ?? '-',
        };
      }
    } catch (_) {}
    return {'cat': '-', 'sub': '-'};
  }

  // 3. طباعة الفاتورة الفردية (بعرض الصفحة وتصميم فخم)
// دالة طباعة حركة واحدة (فاتورة أو سند) بشكل احترافي
 Future<void> _printSingleTransaction(DocumentSnapshot doc) async {
  final data = doc.data() as Map<String, dynamic>;
  final String type = data['type'] ?? 'invoice';
  final ttf = await _getFont();
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4, // ده اللي بيخليها بعرض الصفحة
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            children: [
              pw.Text(type == 'invoice' ? Translate.text(context as BuildContext, "فاتورة مبيعات" , 'invoice'): Translate.text(context as BuildContext, "سند قبض", 'receipt'), 
                style: pw.TextStyle(font: ttf, fontSize: 25, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              
              // بيانات العميل
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(Translate.text(context as BuildContext, "العميل: $selectedCustomerName", 'customer')  , style: pw.TextStyle(font: ttf)),
                pw.Text(Translate.text(context as BuildContext, "التاريخ: ${data['date']?.toDate().toString().substring(0,16)}", 'date'), style: pw.TextStyle(font: ttf)),
              ]),
              pw.SizedBox(height: 20),

              // لو فاتورة نعرض الجدول بالتصنيفات
             // --- بداية التعديل ---
if (type == 'invoice') 
  pw.TableHelper.fromTextArray(
    context: context,
    cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
    headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
    // توزيع العرض بنسب مئوية عشان يملأ الصفحة A4
    columnWidths: {
      0: const pw.FlexColumnWidth(3), // الصنف
      1: const pw.FlexColumnWidth(2.5), // التصنيف (وسعناه شوية)
      2: const pw.FlexColumnWidth(1), // الكمية
      3: const pw.FlexColumnWidth(1.5), // السعر (أضفنا خانة السعر عشان يملأ العرض)
      4: const pw.FlexColumnWidth(2), // الإجمالي
    },
    headers: ['الصنف', 'التصنيف / الفرعي', 'الكمية', 'السعر', 'الإجمالي'],
    data: (data['items'] as List).map((item) {
      // معالجة البيانات الناقصة بذكاء
      String name = item['name'] ?? item['productName'] ?? 'صنف غير مسمى';
      String cat = (item['category'] != null && item['category'] != "") ? item['category'] : "عام";
      String sub = (item['subCategory'] != null && item['subCategory'] != "") ? item['subCategory'] : "افتراضي";
      
      return [
        name,
        "$cat / $sub",
        item['qty'].toString(),
        item['price'].toString(),
        item['total'].toString(),
      ];
    }).toList(),
  )
else
  // تصميم فخم لسند القبض بدل الجدول الفاضي
  pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(15),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.blueGrey, width: 2),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(Translate.text(context as BuildContext, "وصلنا من السيد: $selectedCustomerName", 'customer'), style: pw.TextStyle(font: ttf, fontSize: 14)),
            pw.Text(Translate.text(context as BuildContext, "مبلغ وقدره: ${data['amount']} ج.م", 'amount'), style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blueGrey),
        pw.SizedBox(height: 10),
        pw.Text(Translate.text(context as BuildContext, "وذلك عن: ${data['details'] ?? 'سند قبض نقدي لسيادتكم'}", 'details'), 
          style: pw.TextStyle(font: ttf, fontSize: 13, color: PdfColors.grey700)),
      ],
    ),
  ),

pw.SizedBox(height: 30), // مسافة قبل الإجمالي

pw.Align(
  alignment: pw.Alignment.centerLeft, 
  child: pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: const pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 5))
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(Translate.text(context as BuildContext, "الإجمالي المطلوب: ", 'total'), style: pw.TextStyle(font: ttf, fontSize: 14)),
        pw.Text("${data['amount']} ج.م", 
          style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      ],
    ),
  ),
),
// --- نهاية التعديل ---
            ],
          ),
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
  
  // 4. طباعة كشف الحساب المجمع (حل المشكلة السابقة)
// 4. طباعة كشف الحساب المجمع (تم إصلاح خطأ تعدد الصفحات + فلترة الملغي)
 Future<void> _printStatementDirectly() async {
  if (selectedCustomerId == null) return;

  showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

  try {
    var snap = await FirebaseFirestore.instance
        .collection('customers').doc(selectedCustomerId)
        .collection('transactions')
        .orderBy('date') // الترتيب الزمني ضروري جداً هنا
        .get();

    List<List<dynamic>> tableData = [];
    double runningBalance = 0.0; // الرصيد التراكمي يبدأ من الصفر

    for (var doc in snap.docs) {
      var d = doc.data();
      if (d['status'] == 'cancelled') continue; 

      double amount = double.tryParse(d['amount'].toString()) ?? 0;
      bool isInvoice = d['type'] == 'invoice';

      // تحديث الرصيد التراكمي: الفاتورة تزيد (+) والدفع ينقص (-)
      if (isInvoice) {
        runningBalance += amount;
      } else {
        runningBalance -= amount;
      }

      tableData.add([
        (d['date'] as Timestamp).toDate().toString().substring(0, 10), // التاريخ
        isInvoice ? Translate.text(context as BuildContext, "فاتورة", 'invoice') : Translate.text(context as BuildContext, "سند قبض", 'receipt'), // النوع
        d['details'] ?? '-', // البيان
        isInvoice ? amount.toStringAsFixed(1) : "", // مدين (عليه)
        !isInvoice ? amount.toStringAsFixed(1) : "", // دائن (له)
        runningBalance.toStringAsFixed(1), // الرصيد التراكمي بعد هذه الحركة
      ]);
    }

    final ttf = await _getFont();
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: ttf),
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text(Translate.text(context as BuildContext, "كشف حساب تفصيلي: $selectedCustomerName", 'statement'), style: pw.TextStyle(font: ttf, fontSize: 18))),
        
        pw.TableHelper.fromTextArray(
          context: context,
          headerStyle: pw.TextStyle(font: ttf, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
          // العناوين الجديدة للجدول
          headers: [
            Translate.text(context as BuildContext, "التاريخ", 'date'),
            Translate.text(context as BuildContext, "النوع", 'type'),
            Translate.text(context as BuildContext, "البيان", 'details'),
            Translate.text(context as BuildContext, "مدين (+)", 'debit'),
            Translate.text(context as BuildContext, "دائن (-)", 'credit'),
            Translate.text(context as BuildContext, "الرصيد", 'balance')
          ],
          data: tableData,
          columnWidths: {
            0: const pw.FlexColumnWidth(2), // التاريخ
            1: const pw.FlexColumnWidth(1.5), // النوع
            2: const pw.FlexColumnWidth(3), // البيان
            3: const pw.FlexColumnWidth(1.5), // مدين
            4: const pw.FlexColumnWidth(1.5), // دائن
            5: const pw.FlexColumnWidth(2), // الرصيد التراكمي
          },
        ),
        
        pw.SizedBox(height: 20),
        pw.Container(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            Translate.text(context as BuildContext, "صافي المديونية النهائية: ${runningBalance.toStringAsFixed(2)} ج.م", 'final_balance'),
            style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)
          ),
        )
      ],
    ));

    if(mounted) Navigator.pop(context);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());

  } catch (e) {
    if(mounted) Navigator.pop(context);
    print("PDF Error: $e");
  }
}


  // 5. عرض التفاصيل في كارت منبثق (BottomSheet)
  void _showTransactionDetails(Map<String, dynamic> data,DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // هنا بنفك البيانات للعرض فقط
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ليأخذ ارتفاع الشاشة حسب الحاجة
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85, // يفتح بنسبة 85% من الشاشة
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // رأس الكارت
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['type'] == 'invoice' ? Translate.text(context as BuildContext, "تفاصيل الفاتورة", 'invoice_details') : Translate.text(context as BuildContext, "تفاصيل السند", 'receipt_details'), 
                         style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(thickness: 2),
                
                // المحتوى
                Expanded(
                  child: data['type'] == 'invoice' && data['items'] != null
                  ? ListView.builder(
                      itemCount: (data['items'] as List).length,
                      itemBuilder: (context, index) {
                        var item = data['items'][index];
                        return FutureBuilder<Map<String, String>>(
                          future: _getProductDetails(item['productId'] ?? ''),
                          builder: (context, snapshot) {
                            var catData = snapshot.data ?? {'cat': '...', 'sub': '...'};
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(child: Text("${index + 1}")),
                                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(Translate.text(context as BuildContext, "تصنيف: ${catData['cat']} - ${catData['sub']}", 'category')),
                                    Text(Translate.text(context as BuildContext, "عدد: ${item['qty']}  ×  سعر: ${item['price']}", 'quantity_price'), style: const TextStyle(color: Colors.green)),
                                  ],
                                ),
                                trailing: Text(Translate.text(context as BuildContext, "${item['total']} ج.م", 'total_amount'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on, size: 80, color: Colors.green),
                          const SizedBox(height: 20),
                          Text(Translate.text(context as BuildContext, "${data['amount']} ج.م", 'amount'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(data['details'] ?? Translate.text(context as BuildContext, "لا يوجد تفاصيل", 'no_details'), style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                ),
                
                // زر الطباعة داخل الكارت
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900], 
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () {
                      Navigator.pop(context); // اقفل الكارت الأول
                      _printSingleTransaction(doc); // اطبع المستند اللي في إيدك ده "فوراً"
                    },
                    icon: const Icon(Icons.print),
                    label:  Text(Translate.text(context as BuildContext, "طباعة هذا المستند", 'print_document'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text(Translate.text(context as BuildContext, "حسابات العملاء", 'customers_accounts')), centerTitle: true),
      body: Column(
        children: [
          // 1. اختيار العميل
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: Translate.text(context as BuildContext, "اختر العميل", 'select_customer'), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person_search),
                    filled: true, fillColor: Colors.blue[50]
                  ),
                  items: snapshot.data!.docs.map((doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name'] ?? ""),
                    onTap: () => setState(() => selectedCustomerName = doc['name']),
                  )).toList(),
                  onChanged: (val) {
                     setState(() { 
                       selectedCustomerId = val; 
                       totalBalance = 0;
                       searchController.clear();
                       searchQuery = "";
                     });
                  },
                );
              },
            ),
          ),

          if (selectedCustomerId != null) ...[
            // 2. كارت الرصيد + زر كشف الحساب
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                color: const Color(0xFF2C3E50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         Text(Translate.text(context as BuildContext, "إجمالي المديونية", 'total_debt'), style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 5),
                        Text(Translate.text(context as BuildContext, "${totalBalance.toStringAsFixed(2)} ج.م", 'total_amount'), style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 24, fontWeight: FontWeight.bold)),
                      ]),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, 
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                        ),
                        onPressed: _printStatementDirectly, // الزر أصبح ينادي الدالة المباشرة
                        icon: const Icon(Icons.receipt_long),
                        label:  Text(Translate.text(context as BuildContext, "كشف حساب", 'account_statement')),
                      )
                    ],
                  ),
                ),
              ),
            ),

            // 3. خانة البحث
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
              child: TextField(
                controller: searchController,
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: InputDecoration(
                  hintText: Translate.text(context as BuildContext, "بحث في حركات العميل (رقم، مبلغ، تفاصيل)...", 'search_customer_transactions'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20)
                ),
              ),
            ),
          ],

          // 4. قائمة الحركات
          Expanded(
            child: selectedCustomerId == null 
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const Icon(Icons.people_alt, size: 60, color: Colors.grey), const SizedBox(height: 10), Text(Translate.text(context as BuildContext, "الرجاء اختيار عميل", 'please_select_customer'))],
              ))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customers').doc(selectedCustomerId).collection('transactions').orderBy('date', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  var docs = snapshot.data!.docs;
                  
                  // تصفية النتائج بناء على البحث
                  var filteredDocs = docs.where((doc) {
                    var d = doc.data() as Map<String, dynamic>;
                    String details = d['details']?.toString().toLowerCase() ?? '';
                    String amount = d['amount']?.toString() ?? '';
                    String search = searchQuery.toLowerCase();
                    return details.contains(search) || amount.contains(search);
                  }).toList();

                  // تحديث الرصيد مرة واحدة
                 // تحديث الرصيد مرة واحدة بذكاء
WidgetsBinding.instance.addPostFrameCallback((_) {
  double sum = 0;
  for (var d in docs) {
    var m = d.data() as Map<String, dynamic>;
    if (m['status'] != 'cancelled') {
      double val = double.tryParse(m['amount'].toString()) ?? 0;
      // إذا كانت فاتورة تزيد المديونية (+)، وإذا كان سند قبض تنقصها (-)
      if (m['type'] == 'invoice') {
        sum += val;
      } else if (m['type'] == 'payment') {
        sum -= val;
      }
    }
  }
  if ((totalBalance - sum).abs() > 0.1) setState(() => totalBalance = sum);
});
                  if (filteredDocs.isEmpty) return Center(child: Text(Translate.text(context as BuildContext, "لا توجد حركات تطابق بحثك", 'no_transactions_match_search')));

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 5, bottom: 20),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var data = filteredDocs[index].data() as Map<String, dynamic>;
                      bool isInvoice = data['type'] == 'invoice';
                      bool isCancelled = data['status'] == 'cancelled';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          onTap: () => _showTransactionDetails(data, filteredDocs[index]), // فتح الكارت عند الضغط
                          leading: CircleAvatar(
                            backgroundColor: isCancelled ? Colors.red[50] : (isInvoice ? Colors.blue[50] : Colors.green[50]),
                            child: Icon(
                              isCancelled ? Icons.block : (isInvoice ? Icons.inventory : Icons.attach_money),
                              color: isCancelled ? Colors.red : (isInvoice ? Colors.blue : Colors.green)
                            ),
                          ),
                          title: Text(
                            isCancelled ? Translate.text(context as BuildContext, "ملغاة - ${data['details']}", 'cancelled_details') : (data['details'] ?? (isInvoice ? Translate.text(context as BuildContext, "فاتورة مبيعات", 'sales_invoice') : Translate.text(context as BuildContext, "سند قبض", 'receipt'))),
                            style: TextStyle(
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                              color: isCancelled ? Colors.grey : Colors.black
                            )
                          ),
                          subtitle: Text(data['date']?.toDate().toString().substring(0, 16) ?? ""),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Translate.text(context as BuildContext, "${data['amount']} ج.م", 'amount_currency'), 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isCancelled ? Colors.grey : Colors.black)
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                            ],
                          ),
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
}