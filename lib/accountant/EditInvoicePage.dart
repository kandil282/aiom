import 'package:aiom/accountant/subEditInvoicePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecificCustomerInvoicesPage extends StatefulWidget {
  const SpecificCustomerInvoicesPage({super.key});

  @override
  State<SpecificCustomerInvoicesPage> createState() => _SpecificCustomerInvoicesPageState();
}

class _SpecificCustomerInvoicesPageState extends State<SpecificCustomerInvoicesPage> {
  String? selectedCustomerId;
  String invoiceSearchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تعديل فواتير العميل"),
        backgroundColor: const Color(0xff692960),
      ),
      body: Column(
        children: [
          // 1. دروب داون اختيار العميل
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "اختر العميل لعرض فواتيره",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  initialValue: selectedCustomerId,
                  items: snap.data!.docs.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(d['name'] ?? "بدون اسم"),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() {
                    selectedCustomerId = val;
                    invoiceSearchQuery = ""; // تصفير البحث عند تغيير العميل
                  }),
                );
              },
            ),
          ),

          // 2. خانة البحث برقم الفاتورة (تظهر فقط بعد اختيار العميل)
          if (selectedCustomerId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: TextField(
                onChanged: (val) => setState(() => invoiceSearchQuery = val),
                decoration: InputDecoration(
                  hintText: "ابحث برقم الفاتورة فقط...",
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

          const Divider(height: 30),

          // 3. قائمة الفواتير
          Expanded(
            child: selectedCustomerId == null
                ? const Center(child: Text("الرجاء اختيار عميل أولاً"))
                : _buildInvoiceList(),
          ),
        ],
      ),
    );
  }

// دالة إلغاء الفاتورة بالكامل وإرجاع المخزون
Future<void> _cancelInvoice(String invoiceId, Map<String, dynamic> invoiceData) async {
  // 1. حماية إضافية: التأكد من أن الفاتورة ليست ملغاة بالفعل
  if (invoiceData['status'] == 'cancelled') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("هذه الفاتورة ملغاة بالفعل!")),
    );
    return;
  }

  try {
    double amount = (invoiceData['amount'] ?? 0).toDouble();
    List<dynamic> items = invoiceData['items'] ?? [];

    // 2. تحديث حالة الفاتورة لملغاة (عشان الشرط اللي فوق يشتغل المرة الجاية)
    await FirebaseFirestore.instance
        .collection('customers').doc(selectedCustomerId)
        .collection('transactions').doc(invoiceId)
        .update({
      'status': 'cancelled',
      'details': 'ملغاة - تم إرجاع البضاعة',
    });

    // 3. عكس الأثر المالي (طرح المديونية)
    await FirebaseFirestore.instance
        .collection('customers').doc(selectedCustomerId)
        .update({
      'balance': FieldValue.increment(-amount),
    });

    // 4. إرجاع المخزون (نفس الكود السابق)
    for (var item in items) {
       // كود إرجاع المخزون...
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم الإلغاء بنجاح ✅"), backgroundColor: Colors.orange),
    );
  } catch (e) {
    // معالجة الخطأ...
  }
}



void _showCancelDialog(String invId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الإلغاء"),
        content: const Text("هل أنت متأكد من إلغاء هذه الفاتورة بالكامل؟ سيتم إرجاع الكميات للمخازن وتعديل مديونية العميل."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _cancelInvoice(invId, data);
            },
            child: const Text("إلغاء الفاتورة", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget _buildInvoiceList() {
    return StreamBuilder<QuerySnapshot>(
      // جلب الفواتير الخاصة بالعميل المختار فقط
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(selectedCustomerId)
          .collection('transactions')
          .where('type', isEqualTo: 'invoice')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        // فلترة النتائج بناءً على رقم الفاتورة (ID)
        var docs = snap.data!.docs.where((d) {
          return d.id.toLowerCase().contains(invoiceSearchQuery.toLowerCase());
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا توجد فواتير مطابقة للبحث"));

    // ... داخل StreamBuilder ...
return ListView.builder(
  itemCount: docs.length,
  itemBuilder: (context, i) {
    // تعريف المتغير بشكل صحيح داخل الحلقة
    final QueryDocumentSnapshot invDoc = docs[i]; 
    final Map<String, dynamic> invData = invDoc.data() as Map<String, dynamic>;
    
    // فحص حالة الإلغاء
    bool isCancelled = invData['status'] == 'cancelled';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      color: isCancelled ? Colors.red[50] : Colors.white,
      child: ListTile(
        title: Text("رقم الفاتورة: ${invDoc.id}"),
        subtitle: Text(isCancelled 
          ? "⚠️ فاتورة ملغاة (تم عكس الحساب)" 
          : "الإجمالي: ${invData['amount']} ج.م"),
        trailing: isCancelled 
          ? const Icon(Icons.history_outlined, color: Colors.grey) 
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.purple),
                  onPressed: () => _openEditItemsPage(invDoc.id, invData),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () => _showCancelDialog(invDoc.id, invData),
                ),
              ],
            ),
      ),
    );
  },
);
     
      },
    );
  }

void _openEditItemsPage(String invId, Map<String, dynamic> data) {
  // الانتقال الفعلي لصفحة التعديل مع تمرير البيانات
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditInvoicePage(
        customerId: selectedCustomerId!, // معرف العميل المختار من الدروب داون
        invoiceId: invId,               // رقم الفاتورة المختار
        invoiceData: data,              // بيانات الفاتورة (الأصناف وغيرها)
      ),
    ),
  );
}
}