import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MaterialRequestPage extends StatefulWidget {
  const MaterialRequestPage({super.key});

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  List<Map<String, dynamic>> requestedItems = [];
  String? selectedWarehouseId;
  String? selectedWarehouseName;
  bool isLoading = false;

  // جلب اسم الموظف الحالي
  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "موظف إنتاج";
    var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.exists ? (doc.data()?['username'] ?? "موظف") : "موظف";
  }

  // إضافة صنف للقائمة
  void _addItem() {
    String? matId;
    String? matName;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة خامة للطلب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // قائمة الخامات (Dropdown)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('raw_materials').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "اختر الخامة",
                    border: OutlineInputBorder(),
                  ),
                  items: snap.data!.docs.map((doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text("${doc['materialName']} (رصيد: ${doc['stock'] ?? 0})"),
                  )).toList(),
                  onChanged: (val) {
                    matId = val;
                    matName = snap.data!.docs.firstWhere((d) => d.id == val)['materialName'];
                  },
                );
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: "الكمية المطلوبة",
                border: OutlineInputBorder(),
                suffixText: "وحدة"
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (matId != null && qtyCtrl.text.isNotEmpty) {
                setState(() {
                  requestedItems.add({
                    'materialId': matId,
                    'materialName': matName,
                    'qty': double.tryParse(qtyCtrl.text) ?? 1,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text("إضافة", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // إرسال الطلب للمخزن
  Future<void> _submitRequest() async {
    if (requestedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إضافة خامات أولاً")));
      return;
    }
    if (selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء اختيار المخزن الموجه له الطلب")));
      return;
    }

    setState(() => isLoading = true);

    try {
      String name = await _getUserName();
      
      await FirebaseFirestore.instance.collection('material_requests').add({
        'items': requestedItems,
        'status': 'waiting_warehouse', // الحالة المبدئية
        'requestedBy': name,
        'requestedAt': FieldValue.serverTimestamp(),
        'warehouseId': selectedWarehouseId,
        'warehouseName': selectedWarehouseName,
        'productionNote': 'تشغيل إنتاج',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم إرسال الطلب للمخزن بنجاح ✅"), 
          backgroundColor: Colors.green
        ));
        setState(() {
          requestedItems.clear();
          selectedWarehouseId = null; 
          selectedWarehouseName = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلب خامات إنتاج"),
        centerTitle: true,
        backgroundColor: Colors.orange[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. اختيار المخزن
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200)
              ),
              child: // استبدل الـ StreamBuilder القديم بهذا الكود الآمن
StreamBuilder<QuerySnapshot>(
  // التعديل: قراءة من storage_locations بدلاً من warehouses
  stream: FirebaseFirestore.instance.collection('storage_locations').snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const LinearProgressIndicator();
    
    // فلترة المستندات الفارغة أو التي لا تحتوي على اسم
    var locations = snapshot.data!.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return data.containsKey('name');
    }).toList();

    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(labelText: "اختر المخزن", border: OutlineInputBorder()),
      initialValue: selectedWarehouseId,
      items: locations.map((doc) {
        return DropdownMenuItem(
          value: doc.id,
          // قراءة حقل name كما هو موجود في الصورة
          child: Text(doc['name']), 
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          selectedWarehouseId = val;
          selectedWarehouseName = locations.firstWhere((d) => d.id == val)['name'];
        });
      },
    );
  },
)
           
           
           
            ),
            const SizedBox(height: 15),

            // 2. زر الإضافة
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("إضافة خامة للقائمة"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // 3. قائمة الطلبات الحالية
            Expanded(
              child: requestedItems.isEmpty 
              ? Center(child: Text("لم يتم إضافة خامات بعد", style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  itemCount: requestedItems.length,
                  itemBuilder: (ctx, i) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100], 
                        child: Text("${i+1}", style: const TextStyle(color: Colors.orange)),
                      ),
                      title: Text(requestedItems[i]['materialName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("الكمية: ${requestedItems[i]['qty']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => requestedItems.removeAt(i)),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
            ),

            // 4. زر الإرسال النهائي
            if (requestedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("إرسال الطلب للمخازن", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}