import 'package:aiom/configer/settingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageDashboard extends StatefulWidget {
  const StorageDashboard({super.key});

  @override
  State<StorageDashboard> createState() => _StorageDashboardState();
}

class _StorageDashboardState extends State<StorageDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120, pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(Translate.text(context, "المستودع المركزي", "Central Warehouse"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF102A43), Color(0xFF244A5F)]))),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF244A5F),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                tabs:  [Tab(text: Translate.text(context, "المنتجات", "Products"), icon: Icon(Icons.inventory_2)), Tab(text: Translate.text(context, "الخامات", "Raw Materials"), icon: Icon(Icons.construction))],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
                decoration: InputDecoration(hintText: Translate.text(context, "بحث...", "Search..."), prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').orderBy('category').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return  Center(child: Text(Translate.text(context, "حدث خطأ في عرض البيانات", "An error occurred while displaying data")));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  String currentTabType = _tabController.index == 0 ? "product" : "material";
                  
                  // التصفية الآمنة ضد الأخطاء
                  var filteredDocs = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String type = data.containsKey('itemType') ? data['itemType'] : "product";
                    String name = (data['productName'] ?? "").toString().toLowerCase();
                    return type == currentTabType && name.contains(_searchText);
                  }).toList();

                  Map<String, List<DocumentSnapshot>> grouped = {};
                  for (var d in filteredDocs) {
                    String cat = (d.data() as Map<String, dynamic>)['category'] ?? Translate.text(context, "عام", "General");
                    grouped.putIfAbsent(cat, () => []).add(d);
                  }

                  return ListView.builder(
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, index) {
                      String catName = grouped.keys.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.all(15), child: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ...grouped[catName]!.map((item) => _buildProductCard(item)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(data['productName'] ?? Translate.text(context, "صنف قديم", "Old Product")),
        subtitle: Text(data['subCategory'] ?? ""),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}