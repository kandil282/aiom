import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AllDepartmentsCharts extends StatefulWidget {
  const AllDepartmentsCharts({super.key});

  @override
  State<AllDepartmentsCharts> createState() => _AllDepartmentsChartsState();
}

class _AllDepartmentsChartsState extends State<AllDepartmentsCharts> {
  bool isDark = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0f172a) : const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text("تحليلات الأقسام الشاملة"),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () => setState(() => isDark = !isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. قسم المبيعات والإنتاج (رسم بياني خطي مقارن)
            _buildChartSection(
              title: "أداء المبيعات مقابل الإنتاج",
              subtitle: "مقارنة شهرية للكميات",
              chart: _buildLineChart(),
              color: Colors.blueAccent,
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                // 2. قسم توزيع المخازن (رسم دائري)
                Expanded(
                  child: _buildChartSection(
                    title: "توزيع المخزون",
                    subtitle: "حسب التصنيف",
                    chart: _buildPieChart(),
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 15),
                // 3. قسم كفاءة الشحن (رسم أعمدة)
                Expanded(
                  child: _buildChartSection(
                    title: "كفاءة المناديب",
                    subtitle: "عمليات التسليم الناجحة",
                    chart: _buildBarChart(),
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 4. قسم المهام المتأخرة لكل الأقسام (Heatmap Style)
            _buildDelayedTasksGrid(),
          ],
        ),
      ),
    );
  }

  // --- مكونات الرسوم البيانية ---

  // 1. الرسم البياني الخطي (مبيعات وانتاج)
  Widget _buildLineChart() {
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // خط المبيعات
            LineChartBarData(
              spots: [const FlSpot(0, 3), const FlSpot(1, 4), const FlSpot(2, 2), const FlSpot(3, 5)],
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
            // خط الإنتاج
            LineChartBarData(
              spots: [const FlSpot(0, 2), const FlSpot(1, 3), const FlSpot(2, 4), const FlSpot(3, 3)],
              isCurved: true,
              color: Colors.purple,
              barWidth: 4,
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }

  // 2. الرسم البياني الدائري (المخازن)
  Widget _buildPieChart() {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 5,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(value: 40, color: Colors.blue, title: 'خامات', radius: 50, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
            PieChartSectionData(value: 35, color: Colors.orange, title: 'منتج تام', radius: 50, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
            PieChartSectionData(value: 25, color: Colors.grey, title: 'هالك', radius: 50, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // 3. رسم الأعمدة (الشحن والمناديب)
  Widget _buildBarChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: Colors.green, width: 15)]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: Colors.green, width: 15)]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: Colors.green, width: 15)]),
          ],
        ),
      ),
    );
  }

  // --- قالب تصميم الأقسام ---
  Widget _buildChartSection({required String title, required String subtitle, required Widget chart, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }

  // 4. شبكة المهام المتأخرة لكل الأقسام (Widget تفاعلي)
  Widget _buildDelayedTasksGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'delayed').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.withOpacity(0.8), Colors.redAccent]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("إجمالي المتأخرات بكل الأقسام", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("يوجد $count عمليات تتطلب تدخل فوري", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Icon(Icons.speed, color: Colors.white, size: 40),
            ],
          ),
        );
      }
    );
  }
}