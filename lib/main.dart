import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/ai_service.dart';
import 'services/storage_service.dart';
import 'models/security_report.dart';
import 'screens/threat_report_screen.dart';
import 'services/export_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found");
  }
  runApp(const MoltGuardApp());
}

class MoltGuardApp extends StatelessWidget {
  const MoltGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64FFDA),
          secondary: Color(0xFF00BFA5),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final TextEditingController _controller = TextEditingController();

  List<SecurityReport> _history = [];
  SecurityReport? _currentReport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final data = await _storageService.loadHistory();
    setState(() {
      _history = data.map((e) => SecurityReport.fromJson(e)).toList();
    });
  }

  Future<void> _analyze() async {
    if (_controller.text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _currentReport = null;
    });

    try {
      final report = await _aiService.analyzeThreat(_controller.text);
      setState(() {
        _currentReport = report;
        _history.insert(0, report);
        _controller.clear();
      });
      await _storageService.saveHistory(_history.map((e) => e.toJson()).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Analysis Error: Check API Key or Connection")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MOLTGUARD AI",
          style: TextStyle(letterSpacing: 3, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Color(0xFF64FFDA)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ThreatReportScreen(
                  reports: _history,
                  onRefresh: _initData,
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildInputArea(),
          Expanded(
            child: _isLoading 
                ? _buildLuxLoading() 
                : (_currentReport != null ? _buildResultView() : _buildHistoryList()),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Paste suspicious link or code...",
            hintStyle: const TextStyle(color: Colors.white24),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(20),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.radar, color: Color(0xFF64FFDA)),
                onPressed: _analyze,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white12),
                ),
              ),
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64FFDA)),
                ),
              ),
              const Icon(Icons.shield_outlined, color: Color(0xFF64FFDA), size: 30),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            "RISK ANALYSIS IN PROGRESS",
            style: TextStyle(
              color: Color(0xFF64FFDA), 
              letterSpacing: 4, 
              fontSize: 10, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "AI IS SCANNING FOR MALICIOUS PATTERNS...",
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final report = _currentReport!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: report.riskColor.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: report.riskColor.withOpacity(0.2), width: 2),
            ),
            child: Column(
              children: [
                Text(
                  "${report.overallRiskScore.toInt()}%",
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: report.riskColor),
                ),
                Text(
                  report.riskLevel,
                  style: TextStyle(
                    letterSpacing: 2, 
                    fontWeight: FontWeight.bold, 
                    color: report.riskColor, 
                    fontSize: 12
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildInfoTile("THREAT SUMMARY", report.summary),
          _buildInfoTile("AI RECOMMENDATION", report.recommendations ?? "No specific action required."),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ElevatedButton.icon(
              onPressed: () => ExportService.exportToPdf(report),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.black, size: 20),
              label: const Text(
                "GENERATE PROFESSIONAL PDF",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64FFDA),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
                shadowColor: const Color(0xFF64FFDA).withOpacity(0.3),
              ),
            ),
          ),

          TextButton.icon(
            onPressed: () => setState(() => _currentReport = null),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("NEW SCAN"),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          )
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, 
            style: const TextStyle(
              color: Color(0xFF64FFDA), 
              fontWeight: FontWeight.bold, 
              fontSize: 10, 
              letterSpacing: 1.5
            )
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Text("SECURE ENVIRONMENT\nNO THREATS DETECTED", 
          textAlign: TextAlign.center, 
          style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12, letterSpacing: 2)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _history.length,
      itemBuilder: (context, i) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(Icons.shield_outlined, color: _history[i].riskColor, size: 20),
          title: Text(_history[i].summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(_history[i].riskLevel, 
            style: TextStyle(
              color: _history[i].riskColor.withOpacity(0.7), 
              fontSize: 10, 
              fontWeight: FontWeight.bold
            )
          ),
          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white10),
          onTap: () => setState(() => _currentReport = _history[i]),
        ),
      ),
    );
  }
}
