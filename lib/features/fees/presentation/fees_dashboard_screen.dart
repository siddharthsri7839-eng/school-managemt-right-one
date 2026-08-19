import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'package:school_erp_staff_app/features/fees/data/fees_dashboard_repository.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

// --- State ---
class FeesDashboardState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? errorMessage;
  final bool isSendingReminder;

  FeesDashboardState({
    this.data,
    this.isLoading = true,
    this.errorMessage,
    this.isSendingReminder = false,
  });

  FeesDashboardState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? errorMessage,
    bool? isSendingReminder,
  }) {
    return FeesDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSendingReminder: isSendingReminder ?? this.isSendingReminder,
    );
  }
}

// --- Controller ---
class FeesDashboardController extends StateNotifier<FeesDashboardState> {
  final FeesDashboardRepository _repository;

  FeesDashboardController(this._repository) : super(FeesDashboardState()) {
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repository.getFeesDashboardData();
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      String message = 'Failed to load dashboard';
      if (e is ApiException) {
        message = e.message;
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<void> sendReminder(BuildContext context, String studentId) async {
    state = state.copyWith(isSendingReminder: true);
    try {
      await _repository.sendFeeReminder(studentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String msg = 'Failed to send reminder';
        if (e is ApiException) msg = e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      state = state.copyWith(isSendingReminder: false);
    }
  }
}

final feesDashboardControllerProvider = StateNotifierProvider<FeesDashboardController, FeesDashboardState>((ref) {
  return FeesDashboardController(ref.watch(feesDashboardRepositoryProvider));
});

// --- Screen ---
class FeesDashboardScreen extends ConsumerWidget {
  const FeesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feesDashboardControllerProvider);
    final controller = ref.read(feesDashboardControllerProvider.notifier);

    return MainScaffold(
      title: 'Fees Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          tooltip: 'Fees Reports',
          onPressed: () => context.push('/dashboard/fees-reports/finance-reports'),
        ),
      ],
      body: _buildBody(context, state, controller, ref.watch(terminologyProvider).classLabel),
    );
  }

  Widget _buildBody(BuildContext context, FeesDashboardState state, FeesDashboardController controller, String classLabel) {
    if (state.isLoading && state.data == null) {
      return SkeletonLoaders.dashboard();
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.fetchDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.data == null) {
      return const Center(child: Text('No data available'));
    }

    final summary = state.data!['summary'];
    final charts = state.data!['charts'];
    final lists = state.data!['lists'];
    final currencySymbol = state.data!['currency_symbol']?.toString() ?? '\$';

    return RefreshIndicator(
      onRefresh: () => controller.fetchDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Summary Cards Grid
            _buildSummaryGrid(summary, currencySymbol),
            const SizedBox(height: 24),

            // 2. Collection Progress Bar
            _buildCollectionProgress(summary),
            const SizedBox(height: 24),

            // 3. Line Chart: 15-Day Trend
            _buildSectionHeader('Collection Trend (15 Days)', Icons.trending_up, Colors.blue),
            const SizedBox(height: 16),
            _buildTrendChart(charts['trend']),
            const SizedBox(height: 24),

            // 4. Donut Charts Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionHeader('By Fee Type', Icons.pie_chart, Colors.orange),
                      const SizedBox(height: 16),
                      _buildDonutChart(charts['feeType']),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildSectionHeader('By Payment Mode', Icons.donut_large, Colors.green),
                      const SizedBox(height: 16),
                      _buildDonutChart(charts['paymentMode']),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 5. Horizontal Bar Chart: Due vs Paid by Class
            _buildSectionHeader('Due vs Paid by $classLabel', Icons.bar_chart, Colors.purple),
            const SizedBox(height: 16),
            _buildClassBarChart(charts['classDue']),
            const SizedBox(height: 24),

            // 6. Top Defaulters List
            _buildSectionHeader('Top Defaulters', Icons.warning_amber_rounded, Colors.red),
            const SizedBox(height: 16),
            _buildDefaultersList(lists['topDefaulters'], controller, context, currencySymbol),
            const SizedBox(height: 24),

            // 7. Recent Payments Timeline
            _buildSectionHeader('Recent Payments', Icons.history, Colors.indigo),
            const SizedBox(height: 16),
            _buildRecentPayments(lists['recentPayments'], currencySymbol),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Summary Grid ---
  Widget _buildSummaryGrid(Map<String, dynamic> summary, String currencySymbol) {
    final currency = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Total Assigned', currency.format(summary['totalAssigned'] ?? 0), Colors.blue),
        _buildStatCard('Total Collected', currency.format(summary['totalCollected'] ?? 0), Colors.green),
        _buildStatCard('Total Due', currency.format(summary['totalDue'] ?? 0), Colors.red),
        _buildStatCard('Collected Today', currency.format(summary['collectedToday'] ?? 0), Colors.indigo),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _buildCollectionProgress(Map<String, dynamic> summary) {
    final assigned = num.tryParse(summary['totalAssigned']?.toString() ?? '0') ?? 0;
    final collected = num.tryParse(summary['totalCollected']?.toString() ?? '0') ?? 0;
    final progress = assigned > 0 ? (collected / assigned) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Collection Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(progress > 0.7 ? Colors.green : (progress > 0.4 ? Colors.orange : Colors.red)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(Map<String, dynamic> trendData) {
    final labels = List<String>.from(trendData['labels'] ?? []);
    final amounts = List<dynamic>.from(trendData['amounts'] ?? []).map((e) => num.tryParse(e?.toString() ?? '0')?.toDouble() ?? 0.0).toList();

    if (amounts.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No trend data')));
    }

    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);
    final spots = amounts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < labels.length && idx % 3 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(labels[idx], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (amounts.length - 1).toDouble(),
          minY: 0,
          maxY: maxAmount > 0 ? maxAmount * 1.2 : 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Donut Chart ---
  Widget _buildDonutChart(List<dynamic> items) {
    if (items.isEmpty) {
      return const SizedBox(height: 150, child: Center(child: Text('No data')));
    }

    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal];
    final pieSections = items.asMap().entries.map((e) {
      final item = e.value;
      return PieChartSectionData(
        color: colors[e.key % colors.length],
        value: num.tryParse(item['total']?.toString() ?? '0')?.toDouble() ?? 0.0,
        title: '',
        radius: 30,
      );
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: pieSections,
            ),
          ),
          // Legend below or inside. For simplicity, just pie.
        ],
      ),
    );
  }

  // --- Horizontal Bar Chart ---
  Widget _buildClassBarChart(List<dynamic> classData) {
    if (classData.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No class data')));
    }

    // Limit to top 5 for better UI if too many
    final items = classData.take(5).toList();
    
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: null,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < items.length) {
                    final label = items[idx]['label'] as String;
                    // truncate label if needed
                    final shortLabel = label.length > 8 ? '${label.substring(0, 6)}..' : label;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(shortLabel, style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: items.asMap().entries.map((e) {
            final item = e.value;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(toY: num.tryParse(item['paid']?.toString() ?? '0')?.toDouble() ?? 0.0, color: Colors.green, width: 12, borderRadius: BorderRadius.circular(4)),
                BarChartRodData(toY: num.tryParse(item['due']?.toString() ?? '0')?.toDouble() ?? 0.0, color: Colors.red, width: 12, borderRadius: BorderRadius.circular(4)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Top Defaulters ---
  Widget _buildDefaultersList(List<dynamic> defaulters, FeesDashboardController controller, BuildContext context, String currencySymbol) {
    if (defaulters.isEmpty) {
      return const Text('No defaulters found.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: defaulters.length,
      itemBuilder: (context, index) {
        final def = defaulters[index];
        return InkWell(
          onTap: () => context.push('/dashboard/student-search/profile/${def['student_id']}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red.shade50,
                child: const Icon(Icons.person, size: 20, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${def['first_name']} ${def['last_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${def['class_name']} - ${def['section_name']}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('DUE', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(
                    '$currencySymbol${def['total_due']}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => controller.sendReminder(context, def['student_id'].toString()),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_active, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('Remind', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ));
      },
    );
  }

  // --- Recent Payments ---
  Widget _buildRecentPayments(List<dynamic> payments, String currencySymbol) {
    if (payments.isEmpty) {
      return const Text('No recent payments.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final pay = payments[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.1),
            child: const Icon(Icons.receipt_long, color: Colors.green),
          ),
          title: Text(pay['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(pay['meta'], style: const TextStyle(fontSize: 12)),
          trailing: Text(
            '+$currencySymbol${pay['amount']}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      },
    );
  }
}
