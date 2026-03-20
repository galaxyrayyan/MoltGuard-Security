import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/security_report.dart';

class ThreatReportScreen extends StatefulWidget {
  final List<SecurityReport> reports;
  final VoidCallback onRefresh;

  const ThreatReportScreen({
    super.key,
    required this.reports,
    required this.onRefresh,
  });

  @override
  State<ThreatReportScreen> createState() => _ThreatReportScreenState();
}

class _ThreatReportScreenState extends State<ThreatReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateStats() {
    int total = widget.reports.length;
    int critical = widget.reports.where((r) => r.riskLevel == 'CRITICAL').length;
    int high = widget.reports.where((r) => r.riskLevel == 'HIGH').length;
    int medium = widget.reports.where((r) => r.riskLevel == 'MEDIUM').length;
    int low = widget.reports.where((r) => r.riskLevel == 'LOW' || r.riskLevel == 'MINIMAL').length;
    
    double avgRiskScore = widget.reports.isEmpty 
        ? 0 
        : widget.reports.map((r) => r.overallRiskScore).reduce((a, b) => a + b) / widget.reports.length;

    return {
      'total': total,
      'critical': critical,
      'high': high,
      'medium': medium,
      'low': low,
      'avgRiskScore': avgRiskScore,
    };
  }

    String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Intelligence', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF64FFDA),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.history_rounded), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              widget.onRefresh();
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) setState(() => _isLoading = false);
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF64FFDA)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(stats),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard('Total Scans', '${stats['total']}', Icons.radar, Colors.blueAccent),
              _buildStatCard('Critical', '${stats['critical']}', Icons.gpp_maybe, Colors.redAccent),
              _buildStatCard('Medium Risk', '${stats['medium']}', Icons.warning_amber_rounded, Colors.orangeAccent),
              _buildStatCard('Safe/Low', '${stats['low']}', Icons.check_circle_outline, Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 20),
                   _buildRiskScoreCard(stats['avgRiskScore']),
          const SizedBox(height: 20),
          _buildThreatDistribution(stats),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
                    const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildRiskScoreCard(double score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average Risk Score', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
             Text('${score.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Icon(Icons.trending_up, color: score > 50 ? Colors.redAccent : Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.white10,
              color: score > 50 ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatDistribution(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Threat Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15),
        _distRow('Critical', stats['critical'], stats['total'], Colors.redAccent),
        _distRow('High', stats['high'], stats['total'], Colors.orangeAccent),
        _distRow('Medium', stats['medium'], stats['total'], Colors.yellowAccent),
        _distRow('Low', stats['low'], stats['total'], Colors.greenAccent),
      ],
    );
  }

  Widget _distRow(String label, int val, int total, Color color) {
    double pct = total == 0 ? 0 : (val / total);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60))),
          Expanded(
            child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white10, color: color, minHeight: 4),
          ),
          const SizedBox(width: 10),
          Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (widget.reports.isEmpty) return const Center(child: Text('No analysis history available.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.reports.length,
      itemBuilder: (context, index) {
        final report = widget.reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Icon(Icons.security, color: report.riskColor),
            title: Text(report.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_formatDate(report.timestamp), style: const TextStyle(fontSize: 10)),
            trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: report.riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
              child: Text(report.riskLevel, style: TextStyle(color: report.riskColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            onTap: () => _showDetails(report),
          ),
        );
      },
    );
  }

  void _showDetails(SecurityReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(25),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(report.riskLevel, style: TextStyle(fontSize: 28, fontWeight:
                                                    FontWeight.bold, color: report.riskColor)),
            Text('Security Agent: ${report.agentName}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const Divider(height: 40, color: Colors.white10),
            _detailItem('Summary', report.summary, Icons.description_outlined),
            _detailItem('Recommendations', report.recommendations ?? 'No specific advice provided.', Icons.lightbulb_outline),
            if (report.vulnerabilities.isNotEmpty) ...[
              const Text('Detected Vulnerabilities', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64FFDA))),
              const SizedBox(height: 10),
              ...report.vulnerabilities.map((v) => _vulnTile(v)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 16, color: const Color(0xFF64FFDA)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _vulnTile(Vulnerability v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: v.severityColor.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(v.type, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(v.severity, style: TextStyle(color: v.severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text(v.description, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }
}
  
                                                    

  
