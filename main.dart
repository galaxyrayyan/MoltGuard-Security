import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { 
    await dotenv.load(fileName: ".env"); 
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
  runApp(const MoltGuardApp());
}

class MoltGuardApp extends StatelessWidget {
  const MoltGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoltGuard Security',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.greenAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _currentReport;
  bool _isLoading = false;
  String _sessionKey = "init";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('molt_history') ?? [];
      setState(() {
        _history.clear();
        _history.addAll(data.map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (e) {
            return <String, dynamic>{'error': 'Invalid data'};
          }
        }));
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _analyze() async {
    if (_controller.text.isEmpty || _isLoading) return;
    
    setState(() { 
      _isLoading = true; 
      _currentReport = null;
      _errorMessage = null;
      _sessionKey = DateTime.now().millisecondsSinceEpoch.toString();
    });

    try {
      // التحقق من وجود API key
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found. Please check your .env file');
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: apiKey,
      );
      
      final prompt = """
      Analyze this security threat: '${_controller.text}'
      
      You are a cybersecurity expert. Analyze the given text and return a valid JSON object with exactly these fields:
      {
        "threat": "HIGH", "MEDIUM", or "LOW",
        "summary": "Brief description of the threat (max 100 words)",
        "recommendations": "Actionable security advice to mitigate the threat (max 100 words)"
      }
      
      Ensure all fields are strings. Return ONLY the JSON object, no other text or markdown formatting.
      """;
      
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from API');
      }
      
      final resText = response.text!;
      debugPrint('API Response: $resText'); // للتتبع
      
      // استخراج JSON من النص
      final jsonStart = resText.indexOf('{');
      final jsonEnd = resText.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Invalid JSON response format');
      }

      final jsonString = resText.substring(jsonStart, jsonEnd + 1);
      final Map<String, dynamic> rawData = jsonDecode(jsonString);
      
      // التحقق من صحة البيانات وتوحيدها
      final validatedData = {
        'threat': _validateThreatLevel(rawData['threat']),
        'summary': _validateString(rawData['summary'], 'No summary available'),
        'recommendations': _validateString(rawData['recommendations'], 'No recommendations available'),
        'timestamp': DateTime.now().toIso8601String(),
        'query': _controller.text,
      };

      setState(() { 
        _currentReport = validatedData; 
        _history.insert(0, validatedData);
        _controller.clear(); // مسح حقل الإدخال بعد التحليل
      });
      
      // حفظ في SharedPreferences
      await _saveHistory();
      
    } catch (e) {
      debugPrint('API Error: $e');
      
      setState(() {
        _errorMessage = e.toString();
      });
      
      // عرض رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _validateThreatLevel(dynamic value) {
    final threat = value?.toString().toUpperCase() ?? 'UNKNOWN';
    if (threat.contains('HIGH')) return 'HIGH';
    if (threat.contains('MEDIUM')) return 'MEDIUM';
    if (threat.contains('LOW')) return 'LOW';
    return 'UNKNOWN';
  }

  String _validateString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    final str = value.toString().trim();
    return str.isEmpty ? defaultValue : str;
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _history.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList('molt_history', historyList);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all analysis history?'),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      setState(() {
        _history.clear();
        _currentReport = null;
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('molt_history');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchArea(),
            Expanded(
              child: Container(
                key: ValueKey(_sessionKey),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "MOLTGUARD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontSize: 18,
                  color: Colors.greenAccent,
                ),
              ),
              Text(
                "SECURITY ANALYZER v2.8",
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white38),
                  onPressed: _clearHistory,
                  tooltip: 'Clear history',
                ),
              if (_currentReport != null)
                TextButton(
                  onPressed: () => setState(() => _currentReport = null),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: const Text("CLOSE", style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white70),
                decoration: InputDecoration(
                  hintText: "Enter security threat to analyze...",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _analyze(),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  _isLoading ? Icons.hourglass_empty : Icons.radar,
                  color: _isLoading ? Colors.grey : Colors.greenAccent,
                ),
                onPressed: _isLoading ? null : _analyze,
                tooltip: 'Analyze threat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoading();
    }
    
    if (_errorMessage != null) {
      return _buildError();
    }
    
    if (_currentReport != null) {
      return _buildResult();
    }
    
    return _buildHistory();
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 2),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "DECRYPTING...",
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.greenAccent,
              letterSpacing: 3,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Analyzing security threat",
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "ANALYSIS FAILED",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() => _errorMessage = null),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: Colors.white10,
            ),
            child: const Text("TRY AGAIN"),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_currentReport == null) return _buildHistory();
    
    // استخراج القيم مع قيم افتراضية
    final threat = _currentReport!['threat']?.toString() ?? 'UNKNOWN';
    final summary = _currentReport!['summary']?.toString() ?? 'No summary available';
    final recommendations = _currentReport!['recommendations']?.toString() ?? 'No recommendations available';
    final query = _currentReport!['query']?.toString();
    
    // تحديد اللون والأيقونة بناءً على مستوى التهديد
    Color threatColor;
    IconData threatIcon;
    String threatLabel;
    
    switch (threat) {
      case 'HIGH':
        threatColor = Colors.redAccent;
        threatIcon = Icons.warning_amber_rounded;
        threatLabel = 'CRITICAL THREAT';
        break;
      case 'MEDIUM':
        threatColor = Colors.orangeAccent;
        threatIcon = Icons.error_outline;
        threatLabel = 'MODERATE THREAT';
        break;
      case 'LOW':
        threatColor = Colors.greenAccent;
        threatIcon = Icons.check_circle_outline;
        threatLabel = 'LOW THREAT';
        break;
      default:
        threatColor = Colors.blueAccent;
        threatIcon = Icons.help_outline;
        threatLabel = 'THREAT LEVEL UNKNOWN';
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Threat Level Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  threatColor.withOpacity(0.2),
                  threatColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: threatColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(threatIcon, color: threatColor, size: 40),
                const SizedBox(height: 10),
                Text(
                  threatLabel,
                  style: TextStyle(
                    color: threatColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  threat,
                  style: TextStyle(
                    color: threatColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (query != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '"$query"',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          
          // Summary Section
          _buildInfoBlock(
            title: "THREAT SUMMARY",
            icon: Icons.summarize,
            content: summary,
          ),
          
          // Recommendations Section
          _buildInfoBlock(
            title: "SECURITY RECOMMENDATIONS",
            icon: Icons.security,
            content: recommendations,
          ),
          
          // Timestamp
          if (_currentReport!['timestamp'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.white24),
                  const SizedBox(width: 4),
                  Text(
                    DateTime.parse(_currentReport!['timestamp']).toString().substring(0, 16),
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock({required String title, required IconData icon, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.6,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
              child: const Icon(
                Icons.history,
                size: 40,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Analysis History',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a security threat above to start',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.history, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'RECENT ANALYSES (${_history.length})',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _history.length,
            itemBuilder: (ctx, i) {
              final item = _history[i];
              final threat = item['threat']?.toString() ?? 'UNKNOWN';
              final summary = item['summary']?.toString() ?? 'Unknown threat';
              final timestamp = item['timestamp'];
              
              Color threatColor;
              switch (threat) {
                case 'HIGH': threatColor = Colors.redAccent; break;
                case 'MEDIUM': threatColor = Colors.orangeAccent; break;
                case 'LOW': threatColor = Colors.greenAccent; break;
                default: threatColor = Colors.blueAccent;
              }
              
              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white24),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: threatColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: timestamp != null 
                      ? Text(
                          DateTime.parse(timestamp).toString().substring(0, 16),
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        )
                      : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: threatColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      threat,
                      style: TextStyle(
                        color: threatColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => setState(() => _currentReport = item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}