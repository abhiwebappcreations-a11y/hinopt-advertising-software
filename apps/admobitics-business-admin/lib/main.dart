import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const AdmobiticsAdminApp());
}

class AdmobiticsAdminApp extends StatelessWidget {
  const AdmobiticsAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admobitics Operations Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF2563EB), // Corporate Blue
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF0D9488), // Teal Accent
          surface: Color(0xFF111827),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937)),
          ),
        ),
      ),
      home: const AdmobiticsHomeScreen(),
    );
  }
}

class AdmobiticsHomeScreen extends StatefulWidget {
  const AdmobiticsHomeScreen({super.key});

  @override
  State<AdmobiticsHomeScreen> createState() => _AdmobiticsHomeScreenState();
}

class _AdmobiticsHomeScreenState extends State<AdmobiticsHomeScreen> {
  String adsBaseUrl = 'http://localhost:8082/v1';

  List<dynamic> campaigns = [];
  List<dynamic> advertisers = [];
  Map<String, dynamic> analytics = {
    'total_impressions': 0,
    'total_seconds_played': 0,
    'interrupted_impressions': 0,
  };
  List<String> notifications = [];
  bool isLoading = false;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    fetchData();
    pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => checkForAnalyticsSync());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final cRes = await http.get(Uri.parse('$adsBaseUrl/campaigns'));
      if (cRes.statusCode == 200) {
        campaigns = jsonDecode(cRes.body)['campaigns'] ?? [];
      }

      final aRes = await http.get(Uri.parse('$adsBaseUrl/advertisers'));
      if (aRes.statusCode == 200) {
        advertisers = jsonDecode(aRes.body)['advertisers'] ?? [];
      }

      final statRes = await http.get(Uri.parse('$adsBaseUrl/analytics/proof-of-play'));
      if (statRes.statusCode == 200) {
        analytics = jsonDecode(statRes.body);
      }
    } catch (e) {
      debugPrint("Ads API error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> checkForAnalyticsSync() async {
    try {
      final statRes = await http.get(Uri.parse('$adsBaseUrl/analytics/proof-of-play'));
      if (statRes.statusCode == 200) {
        final newStats = jsonDecode(statRes.body);
        final oldImp = analytics['total_impressions'] ?? 0;
        final newImp = newStats['total_impressions'] ?? 0;

        if (newImp > oldImp) {
          final diff = newImp - oldImp;
          _triggerNotification('📊 Daily PoP Sync: +$diff verified impressions logged from auto screens!');
        }
        setState(() => analytics = newStats);
      }
    } catch (_) {}
  }

  void _triggerNotification(String message) {
    setState(() {
      notifications.insert(0, '${DateFormat('HH:mm').format(DateTime.now())} - $message');
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> bookCampaign({
    required String name,
    required String advertiserId,
    required DateTime flightStart,
    required DateTime flightEnd,
    required int sovPercent,
    required String creativeName,
  }) async {
    try {
      final assets = creativeName.isNotEmpty
          ? [
              {
                'id': 'asset-${DateTime.now().millisecondsSinceEpoch}',
                'campaign_id': 'pending',
                'name': creativeName,
                'media_type': 'VIDEO_MP4',
                'file_size_bytes': 15000000,
                'duration_seconds': 15,
                'sha256_checksum': 'b7f32095f9c636f8634e0499e28f3a3bf29f79e564940f959f63567b545d9e5f',
                'storage_url': 'https://cdn.hinopt.com/media/$creativeName',
              }
            ]
          : [];

      final res = await http.post(
        Uri.parse('$adsBaseUrl/campaigns'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'advertiser_id': advertiserId,
          'name': name,
          'flight_start_date': flightStart.toIso8601String(),
          'flight_end_date': flightEnd.toIso8601String(),
          'share_of_voice_percent': sovPercent,
          'assets': assets,
        }),
      );

      if (res.statusCode == 201) {
        _triggerNotification('🚀 Campaign "$name" booked and published to auto fleet loops!');
        fetchData();
      } else {
        _showErrorDialog('Failed to book campaign. Status code: ${res.statusCode}');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<String?> createAdvertiser(String name, String email, String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$adsBaseUrl/advertisers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'contact_email': email,
          'phone': phone,
        }),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        fetchData();
        return data['id'];
      }
    } catch (_) {}
    return null;
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showBookCampaignDialog() {
    final nameCtrl = TextEditingController();
    final advNameCtrl = TextEditingController();
    final advEmailCtrl = TextEditingController();
    final creativeCtrl = TextEditingController(text: 'advertiser_1080p_15s.mp4');
    String? selectedAdvId = advertisers.isNotEmpty ? advertisers.first['id'] : null;
    bool isNewAdv = advertisers.isEmpty;
    int sov = 25;
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.campaign, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Book Commercial Ad Campaign'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Campaign Name (e.g. Hyderabad Mega Sale)'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Advertiser Client:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    if (advertisers.isNotEmpty)
                      TextButton(
                        onPressed: () => setDlgState(() => isNewAdv = !isNewAdv),
                        child: Text(isNewAdv ? 'Select Existing' : '+ New Client', style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                if (isNewAdv) ...[
                  TextField(controller: advNameCtrl, decoration: const InputDecoration(labelText: 'Business Name')),
                  TextField(controller: advEmailCtrl, decoration: const InputDecoration(labelText: 'Billing Email')),
                ] else
                  DropdownButtonFormField<String>(
                    value: selectedAdvId,
                    items: advertisers.map<DropdownMenuItem<String>>((a) {
                      return DropdownMenuItem(value: a['id'].toString(), child: Text(a['name']));
                    }).toList(),
                    onChanged: (v) => setDlgState(() => selectedAdvId = v),
                  ),
                const SizedBox(height: 16),
                Text('Share of Voice (SOV): $sov% of 2-minute loop', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                Slider(
                  min: 10,
                  max: 100,
                  divisions: 18,
                  value: sov.toDouble(),
                  onChanged: (v) => setDlgState(() => sov = v.toInt()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: creativeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Video Creative Asset (1080p MP4)',
                    helperText: 'Auto-cached locally on auto screens with zero-internet dependency',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                String? advId = selectedAdvId;
                if (isNewAdv) {
                  advId = await createAdvertiser(advNameCtrl.text, advEmailCtrl.text, '');
                }
                if (nameCtrl.text.isNotEmpty && advId != null) {
                  Navigator.pop(ctx);
                  bookCampaign(
                    name: nameCtrl.text,
                    advertiserId: advId,
                    flightStart: start,
                    flightEnd: end,
                    sovPercent: sov,
                    creativeName: creativeCtrl.text,
                  );
                }
              },
              child: const Text('Publish to Auto Fleet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: const Text('ADMOBITICS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            const SizedBox(width: 12),
            const Text('Auto Media Operations', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData, tooltip: 'Refresh Data'),
          IconButton(
            icon: Badge(
              isLabelVisible: notifications.isNotEmpty,
              label: Text('${notifications.length}'),
              child: const Icon(Icons.notifications),
            ),
            onPressed: () => _showNotificationsSheet(),
            tooltip: 'Live Campaign Alerts',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showBookCampaignDialog,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Partnership Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.verified, color: Color(0xFF2563EB)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Admobitics Auto Fleet: 100% of commercial ad revenues retained. Powered by HINOPT offline-first display player technology.',
                            style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Verified Proof-of-Play Metrics
                  const Text('Verified Proof-of-Play (PoP) Telemetry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildAnalyticsGrid(),
                  const SizedBox(height: 20),

                  // Active Campaigns
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Advertiser Campaigns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${campaigns.length} campaigns', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildCampaignsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalyticsGrid() {
    final int impressions = analytics['total_impressions'] ?? 0;
    final int seconds = analytics['total_seconds_played'] ?? 0;
    final int interrupted = analytics['interrupted_impressions'] ?? 0;
    final int completionPct = (impressions + interrupted) > 0
        ? ((impressions / (impressions + interrupted)) * 100).toInt()
        : 100;

    return Row(
      children: [
        Expanded(child: _metricCard('Delivered Plays', '$impressions', Icons.play_circle_fill, Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _metricCard('Airtime Hours', '${(seconds / 3600).toStringAsFixed(1)}h', Icons.timer, Colors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _metricCard('Interrupted', '$interrupted', Icons.power_off, Colors.orange)),
        const SizedBox(width: 10),
        Expanded(child: _metricCard('Completion', '$completionPct%', Icons.trending_up, Colors.purple)),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsList() {
    if (campaigns.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: const [
              Icon(Icons.campaign_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 12),
              Text('Zero Active Commercial Campaigns', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Clean database state. Click "Book Campaign" to schedule local advertisers.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: campaigns.length,
      itemBuilder: (ctx, i) {
        final c = campaigns[i];
        final start = DateTime.parse(c['flight_start_date']);
        final end = DateTime.parse(c['flight_end_date']);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.movie, color: Colors.white),
            ),
            title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Flight: ${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Share of Voice: ${c['share_of_voice_percent'] ?? 25}% of auto loop',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488))),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Admobitics Fleet Live Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => notifications.clear()),
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const Divider(),
            if (notifications.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No active alerts. All campaigns playing on schedule.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F2937)),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.notifications_active, color: Color(0xFF2563EB), size: 20),
                    title: Text(notifications[i], style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
