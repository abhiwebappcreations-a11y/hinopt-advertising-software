import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const HinoptBusinessAdminApp());
}

class HinoptBusinessAdminApp extends StatelessWidget {
  const HinoptBusinessAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HINOPT Business Admin',
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
      home: const BusinessHomeScreen(),
    );
  }
}

class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen> {
  final String supabaseUrl = 'https://yqmczojypjzsvbngipwd.supabase.co/rest/v1';
  final String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxbWN6b2p5cGp6c3ZibmdpcHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzY4ODcsImV4cCI6MjExMTExMjg4N30._B6VY5pwF7ODJyh5vh1rJ3GprIMkcAvNbxjLn5vt5BQ';

  Map<String, String> get _headers => {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  List<dynamic> campaigns = [];
  List<dynamic> advertisers = [];
  List<dynamic> tenants = [];
  List<dynamic> screens = [];
  Map<String, dynamic>? activeTenant;
  final TextEditingController _loginKeyCtrl = TextEditingController();
  bool isAuthenticating = false;
  final Set<String> _promptedScreenIds = {};
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
    pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (activeTenant != null) checkForAnalyticsSync();
    });
  }

  Future<void> loginWithLicenseKey(String key) async {
    final cleanKey = key.trim().toUpperCase();
    if (cleanKey.isEmpty) return;
    setState(() => isAuthenticating = true);
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/hinopt_tenants?tenant_id=eq.$cleanKey&select=*'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          setState(() {
            activeTenant = list.first as Map<String, dynamic>;
            tenants = list;
          });
          await fetchData();
          _triggerNotification('✅ Connected to HINOPT as ${activeTenant!['name']}');
        } else {
          _showErrorDialog('Invalid License Key "$cleanKey". Check HINOPT Super-Admin.');
        }
      } else {
        _showErrorDialog('Connection error (${res.statusCode})');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => isAuthenticating = false);
    }
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final cRes = await http.get(
        Uri.parse('$supabaseUrl/ads_campaigns?select=*,ads_creatives(*)&order=created_at.desc'),
        headers: _headers,
      );
      if (cRes.statusCode == 200) {
        campaigns = jsonDecode(cRes.body) as List<dynamic>;
      }

      final aRes = await http.get(
        Uri.parse('$supabaseUrl/ads_advertisers?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (aRes.statusCode == 200) {
        advertisers = jsonDecode(aRes.body) as List<dynamic>;
      }

      final statRes = await http.get(
        Uri.parse('$supabaseUrl/ads_proof_of_play?select=*'),
        headers: _headers,
      );
      if (statRes.statusCode == 200) {
        analytics = _aggregatePop(jsonDecode(statRes.body) as List<dynamic>);
      }

      final tUuid = activeTenant?['id'];
      final sUrl = tUuid != null
          ? '$supabaseUrl/hinopt_screens?tenant_id=eq.$tUuid&select=*&order=created_at.desc'
          : '$supabaseUrl/hinopt_screens?select=*&order=created_at.desc';
      final sRes = await http.get(Uri.parse(sUrl), headers: _headers);
      if (sRes.statusCode == 200) {
        screens = jsonDecode(sRes.body) as List<dynamic>;
        _checkApprovedScreensForPopup();
      }
    } catch (e) {
      debugPrint("Supabase Ads API error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _aggregatePop(List<dynamic> rows) {
    int imp = 0;
    int secs = 0;
    int interrupted = 0;
    for (final r in rows) {
      imp += (r['completed_impressions'] as num?)?.toInt() ?? 0;
      secs += (r['total_seconds_played'] as num?)?.toInt() ?? 0;
      interrupted += (r['interrupted_impressions'] as num?)?.toInt() ?? 0;
    }
    return {
      'total_impressions': imp,
      'total_seconds_played': secs,
      'interrupted_impressions': interrupted,
    };
  }

  Future<void> checkForAnalyticsSync() async {
    try {
      final statRes = await http.get(
        Uri.parse('$supabaseUrl/ads_proof_of_play?select=*'),
        headers: _headers,
      );
      if (statRes.statusCode == 200) {
        final newStats = _aggregatePop(jsonDecode(statRes.body) as List<dynamic>);
        final oldImp = analytics['total_impressions'] ?? 0;
        final newImp = newStats['total_impressions'] ?? 0;

        if (newImp > oldImp) {
          final diff = newImp - oldImp;
          _triggerNotification('📊 Daily PoP Sync: +$diff verified impressions logged from display screens!');
        }
        setState(() => analytics = newStats);
      }

      final tUuid = activeTenant?['id'];
      final sUrl = tUuid != null
          ? '$supabaseUrl/hinopt_screens?tenant_id=eq.$tUuid&select=*&order=created_at.desc'
          : '$supabaseUrl/hinopt_screens?select=*&order=created_at.desc';
      final sRes = await http.get(Uri.parse(sUrl), headers: _headers);
      if (sRes.statusCode == 200) {
        setState(() => screens = jsonDecode(sRes.body) as List<dynamic>);
        _checkApprovedScreensForPopup();
      }
    } catch (_) {}
  }

  void _checkApprovedScreensForPopup() {
    if (!mounted) return;
    for (final s in screens) {
      final sid = s['id'].toString();
      if (s['enrollment_status'] == 'APPROVED_READY_TO_SCAN' && !_promptedScreenIds.contains(sid)) {
        _promptedScreenIds.add(sid);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showConnectScreenPopup(s);
        });
        break;
      }
    }
  }

  Future<void> _connectScreen(String screenId, String screenName) async {
    final res = await http.patch(
      Uri.parse('$supabaseUrl/hinopt_screens?id=eq.$screenId'),
      headers: _headers,
      body: jsonEncode({
        'enrollment_status': 'CONNECTED',
        'activation_code': null,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _triggerNotification('✅ Screen "$screenName" connected! Ready to receive ad campaigns.');
      fetchData();
    } else {
      _showErrorDialog('Failed to connect screen (${res.statusCode}): ${res.body}');
    }
  }

  void _showConnectScreenPopup(Map<String, dynamic> screen) {
    final sName = screen['screen_name'] ?? 'Unnamed Screen';
    final qrCode = screen['activation_code'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Expanded(child: Text('Connect Approved Screen?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HINOPT approved your screen "$sName"!', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('QR Token: $qrCode', style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Confirm to link this screen to your Client Admin panel.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.link, color: Colors.white),
            label: const Text('Connect Screen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _connectScreen(screen['id'].toString(), sName.toString());
            },
          ),
        ],
      ),
    );
  }

  void _showManualScanDialog() {
    final qrCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan / Enter Screen QR Code'),
        content: TextField(
          controller: qrCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'QR Token (e.g. QR-A9X4B2)',
            hintText: 'QR-XXXXXX',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final token = qrCtrl.text.trim().toUpperCase();
              final match = screens.where((s) => (s['activation_code'] ?? '').toString().toUpperCase() == token).toList();
              Navigator.pop(ctx);
              if (match.isNotEmpty) {
                _showConnectScreenPopup(match.first);
              } else {
                _showErrorDialog('No HINOPT-approved screen found with QR token "$token".');
              }
            },
            child: const Text('Find & Connect'),
          ),
        ],
      ),
    );
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

  Future<String?> _uploadVideoToSupabase(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final uploadUrl = 'https://yqmczojypjzsvbngipwd.supabase.co/storage/v1/object/hinopt-media/$safeName';
      final res = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'video/mp4',
        },
        body: bytes,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return 'https://yqmczojypjzsvbngipwd.supabase.co/storage/v1/object/public/hinopt-media/$safeName';
      } else {
        _showErrorDialog('Video upload failed (${res.statusCode}). Make sure Supabase bucket "hinopt-media" is created.\n${res.body}');
      }
    } catch (e) {
      _showErrorDialog('Upload error: $e');
    }
    return null;
  }

  Future<void> bookCampaign({
    required String name,
    required String advertiserId,
    required DateTime flightStart,
    required DateTime flightEnd,
    required int sovPercent,
    required String creativeName,
    File? selectedVideoFile,
  }) async {
    try {
      String finalStorageUrl = creativeName.startsWith('http')
          ? creativeName
          : 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
      int fileSizeBytes = 15000000;

      if (selectedVideoFile != null) {
        _triggerNotification('⏳ Uploading video "$creativeName" to Supabase Storage...');
        final uploadedUrl = await _uploadVideoToSupabase(selectedVideoFile, creativeName);
        if (uploadedUrl == null) return;
        finalStorageUrl = uploadedUrl;
        fileSizeBytes = await selectedVideoFile.length();
      }

      final res = await http.post(
        Uri.parse('$supabaseUrl/ads_campaigns'),
        headers: _headers,
        body: jsonEncode({
          'advertiser_id': advertiserId,
          'name': name,
          'flight_start_date': flightStart.toUtc().toIso8601String(),
          'flight_end_date': flightEnd.toUtc().toIso8601String(),
          'share_of_voice_percent': sovPercent,
          'status': 'ACTIVE',
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final createdList = jsonDecode(res.body) as List<dynamic>;
        if (createdList.isNotEmpty && creativeName.isNotEmpty) {
          final campId = createdList.first['id'];
          await http.post(
            Uri.parse('$supabaseUrl/ads_creatives'),
            headers: _headers,
            body: jsonEncode({
              'campaign_id': campId,
              'name': creativeName,
              'media_type': 'VIDEO_MP4',
              'file_size_bytes': fileSizeBytes,
              'duration_seconds': 15,
              'sha256_checksum': 'b7f32095f9c636f8634e0499e28f3a3bf29f79e564940f959f63567b545d9e5f',
              'storage_url': finalStorageUrl,
            }),
          );
        }
        _triggerNotification('🚀 Campaign "$name" booked in Supabase Cloud!');
        fetchData();
      } else {
        _showErrorDialog('Failed to book campaign (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<String?> createAdvertiser(String name, String email, String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/ads_advertisers'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'contact_email': email,
          'phone': phone,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        fetchData();
        return list.isNotEmpty ? list.first['id'].toString() : null;
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
    File? pickedVideoFile;

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
                Text('Share of Voice (SOV): $sov% of screen loop', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                Slider(
                  min: 10,
                  max: 100,
                  divisions: 18,
                  value: sov.toDouble(),
                  onChanged: (v) => setDlgState(() => sov = v.toInt()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  icon: const Icon(Icons.video_file, color: Colors.white),
                  label: Text(
                    pickedVideoFile != null ? 'Selected: ${creativeCtrl.text}' : 'Import Video File (.mp4)',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.video);
                    if (result != null && result.files.single.path != null) {
                      setDlgState(() {
                        pickedVideoFile = File(result.files.single.path!);
                        creativeCtrl.text = result.files.single.name;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: creativeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Selected Video Name or Direct MP4 URL',
                    helperText: 'Pick an MP4 file above or paste an https://...mp4 video URL',
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
                    selectedVideoFile: pickedVideoFile,
                  );
                }
              },
              child: const Text('Publish to Screen Fleet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (activeTenant == null) {
      return Scaffold(
        body: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key, size: 48, color: Color(0xFF2563EB)),
                const SizedBox(height: 16),
                const Text('HINOPT Business Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Enter the Client License Key issued by HINOPT Super-Admin to access your screens & campaigns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _loginKeyCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'HNPT-XXXX-XXXX',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    onPressed: isAuthenticating ? null : () => loginWithLicenseKey(_loginKeyCtrl.text),
                    child: isAuthenticating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Connect to HINOPT Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              child: const Text('HINOPT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${activeTenant!['name']} • Business Admin', style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _showManualScanDialog, tooltip: 'Connect Screen (QR / Code)'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData, tooltip: 'Refresh Data'),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Switch Client License',
            onPressed: () => setState(() {
              activeTenant = null;
              screens = [];
              campaigns = [];
              _promptedScreenIds.clear();
            }),
          ),
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
                  // White-Label Banner
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
                            'Digital Signage Operations Portal: 100% of commercial ad revenues retained by screen operators. Powered by HINOPT display player technology.',
                            style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Client License Key & APK Card
                  _buildLicenseKeyCard(),
                  const SizedBox(height: 16),

                  // Connected Screens Summary
                  _buildConnectedScreensSection(),
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

  Widget _buildLicenseKeyCard() {
    if (tenants.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.vpn_key, color: Colors.amber),
          title: const Text('Waiting for HINOPT License Key'),
          subtitle: const Text('Ask HINOPT Super-Admin to register your agency and issue a License Key.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your HINOPT License Keys & Player APK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                TextButton.icon(
                  onPressed: _showManualScanDialog,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Connect Screen (QR / Code)'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...tenants.map((t) {
              final licKey = t['tenant_id'] ?? 'PENDING';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${t['name']}: $licKey (Max ${t['max_screens']} screens)',
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Colors.blueAccent),
                      tooltip: 'Copy License Key',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: licKey.toString()));
                        _triggerNotification('📋 Copied License Key: $licKey');
                      },
                    ),
                  ],
                ),
              );
            }),
            const Text('Install bin/hinopt-player-v1.0.0.apk on your screens and enter the License Key above.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedScreensSection() {
    final connected = screens.where((s) => s['enrollment_status'] == 'CONNECTED' || s['enrollment_status'] == 'ACTIVE').toList();
    final readyToScan = screens.where((s) => s['enrollment_status'] == 'APPROVED_READY_TO_SCAN').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Display Screens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${connected.length} connected', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        if (readyToScan.isNotEmpty)
          ...readyToScan.map((s) => Card(
                color: const Color(0xFF0F766E).withOpacity(0.35),
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2, color: Colors.tealAccent),
                  title: Text('${s['screen_name']} (Approved by HINOPT)'),
                  subtitle: Text('QR Token: ${s['activation_code']}'),
                  trailing: ElevatedButton(
                    onPressed: () => _showConnectScreenPopup(s),
                    child: const Text('Connect'),
                  ),
                ),
              )),
        if (connected.isEmpty && readyToScan.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No screens connected yet. Install Player APK, enter your License Key, and scan QR after HINOPT approval.',
                    style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ),
            ),
          )
        else
          ...connected.map((s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.tv, color: Colors.greenAccent),
                  title: Text(s['screen_name'] ?? 'Screen'),
                  subtitle: Text('Model: ${s['hardware_model']} • Status: CONNECTED'),
                ),
              )),
      ],
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
              Text('Clean database state. Click "Book Campaign" to schedule commercial advertisers.',
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
                Text('Share of Voice: ${c['share_of_voice_percent'] ?? 25}% of screen loop',
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
                const Text('Fleet Live Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
