import 'package:aiom/accountant/CustomerPrintStatementPage.dart';
import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerAccountsPage extends StatefulWidget {
  const CustomerAccountsPage({super.key});

  @override
  State<CustomerAccountsPage> createState() => _CustomerAccountsPageState();
}

class _CustomerAccountsPageState extends State<CustomerAccountsPage> {
  String searchQuery = "";

  // دالة إرسال تنبيه واتساب للعميل
  void _sendWhatsAppReminder(String phone, double balance) async {
    if (balance <= 0) return;
    
    // تنسيق الرسالة
    String message = Translate.text(context, "تحية طيبة، نود تذكيركم بأن إجمالي المديونية المستحقة لديكم هي: $balance ج.م. يرجى التكرم بالسداد في أقرب وقت. شكراً لتعاونكم.", "Greetings, we would like to remind you that your total outstanding debt is: $balance EGP. Please kindly settle it at your earliest convenience. Thank you for your cooperation.");
    
    // تجهيز الرابط (تأكد أن الرقم يبدأ بكود الدولة بدون + إذا لزم الأمر)
    var url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint(Translate.text(context, "لا يمكن فتح واتساب", "Cannot open WhatsApp"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(Translate.text(context, "حسابات العملاء والمديونيات", "Customer Accounts and Debts")),
        backgroundColor: const Color(0xff692960),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. ملخص المديونيات الإجمالية لكل العملاء
          _buildTotalDebtSummary(),

          // 2. خانة البحث
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: Translate.text(context, "بحث عن عميل...", "Search for a customer....."),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // 3. قائمة العملاء
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                // تصفية العملاء بناءً على البحث
                var docs = snap.data!.docs.where((d) => d['name'].toString().contains(searchQuery)).toList();

                if (docs.isEmpty) return  Center(child: Text(Translate.text(context, "لا يوجد عملاء بهذا الاسم", "No customers found with this name")));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String id = docs[i].id;
                    String name = data['name'] ?? Translate.text(context, "بدون اسم", "No Name");
                    String phone = data['phone'] ?? "";
                    double balance = (data['balance'] ?? 0).toDouble();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (c) => CustomerStatementPage()
                        )),
                        leading: CircleAvatar(
                          backgroundColor: balance > 0 ? Colors.red[100] : Colors.green[100],
                          child: Icon(Icons.person, color: balance > 0 ? Colors.red : Colors.green),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Translate.text(context, "الهاتف: $phone", "Phone: $phone")),
                            Text(
                              Translate.text(context, "المديونية: $balance ج.م", "Debt: $balance EGP"),
                              style: TextStyle(
                                color: balance > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر التنبيه (واتساب)
                            IconButton(
                              icon: const Icon(Icons.notifications_active, color: Colors.orange),
                              onPressed: () => _sendWhatsAppReminder(phone, balance),
                              tooltip: Translate.text(context, "إرسال تنبيه مديونية", "Send Debt Reminder"),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

  // ويدجت تعرض إجمالي المديونية لكل العملاء في النظام
  Widget _buildTotalDebtSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var doc in snap.data!.docs) {
            total += (doc['balance'] ?? 0).toDouble();
          }
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xff692960), Color(0xffa23d93)]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 8)],
          ),
          child: Column(
            children: [
               Text(Translate.text(context, "إجمالي مديونيات السوق المستحقة", "Total Market Debts"), style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 5),
              Text(
                Translate.text(context, "${total.toStringAsFixed(2)} ج.م", "${total.toStringAsFixed(2)} EGP"),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}