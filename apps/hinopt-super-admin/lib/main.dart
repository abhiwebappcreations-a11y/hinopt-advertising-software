import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const HinoptSuperAdminApp());
}

class HinoptSuperAdminApp extends StatelessWidget {
  const HinoptSuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HINOPT Super-Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFFD97706), // HINOPT Gold
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD97706),
          secondary: Color(0xFF1B365D), // HINOPT Navy
          surface: Color(0xFF1E293B),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
      home: const AdminHomeScreen(),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final String supabaseUrl = 'https://yqmczojypjzsvbngipwd.supabase.co/rest/v1';
  final String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxbWN6b2p5cGp6c3ZibmdpcHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzY4ODcsImV4cCI6MjExMTExMjg4N30._B6VY5pwF7ODJyh5vh1rJ3GprIMkcAvNbxjLn5vt5BQ';

  Map<String, String> get _headers => {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  List<dynamic> tenants = [];
  List<dynamic> screens = [];
  List<String> notifications = [];
  bool isLoading = false;
  String? selectedTenantId;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    fetchData();
    // Background polling for real-time alerts every 15 seconds
    pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkForAlerts());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final tRes = await http.get(
        Uri.parse('$supabaseUrl/hinopt_tenants?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (tRes.statusCode == 200) {
        tenants = jsonDecode(tRes.body) as List<dynamic>;
      }

      final url = selectedTenantId == null
          ? '$supabaseUrl/hinopt_screens?select=*&order=created_at.desc'
          : '$supabaseUrl/hinopt_screens?tenant_id=eq.$selectedTenantId&select=*&order=created_at.desc';
      final sRes = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      if (sRes.statusCode == 200) {
        screens = jsonDecode(sRes.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint("Supabase API error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> checkForAlerts() async {
    try {
      final sRes = await http.get(
        Uri.parse('$supabaseUrl/hinopt_screens?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (sRes.statusCode == 200) {
        final List<dynamic> updated = jsonDecode(sRes.body) as List<dynamic>;
        final now = DateTime.now().millisecondsSinceEpoch;

        for (var s in updated) {
          final lastHb = s['last_heartbeat_at'];
          if (lastHb != null) {
            final hbTime = DateTime.parse(lastHb).millisecondsSinceEpoch;
            // Alert if screen has been silent for > 5 minutes
            if (now - hbTime > 300000 && s['enrollment_status'] == 'ACTIVE') {
              final msg = '⚠️ Screen "${s['screen_name']}" is OFFLINE (No heartbeat for >5 min)';
              if (!notifications.contains(msg)) {
                _triggerNotification(msg);
              }
            }
          }
          if (s['battery_level_percent'] != null && (s['battery_level_percent'] as int) < 20) {
            final msg = '🔋 Low Battery Alert: "${s['screen_name']}" is at ${s['battery_level_percent']}%';
            if (!notifications.contains(msg)) {
              _triggerNotification(msg);
            }
          }
        }
        setState(() => screens = updated);
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
          backgroundColor: const Color(0xFFDC2626), // Alert Red
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> preAuthorizeScreen(String code, String tenantId, String name, String tier, int days) async {
    try {
      final expiry = DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();
      final res = await http.post(
        Uri.parse('$supabaseUrl/hinopt_screens'),
        headers: _headers,
        body: jsonEncode({
          'activation_code': code.toUpperCase(),
          'tenant_id': tenantId,
          'enrollment_status': 'PRE_AUTHORIZED',
          'screen_name': name,
          'hardware_model': 'PENDING_DISCOVERY',
          'serial_number': 'PENDING',
          'license_tier': tier,
          'license_expires_at': expiry,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        _triggerNotification('✅ Screen "$name" successfully pre-authorized with code $code');
        fetchData();
      } else {
        _showErrorDialog('Authorization failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> revokeScreen(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Screen License?'),
        content: Text('Are you sure you want to revoke "$name"? Playback will be stopped immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke License'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await http.patch(
        Uri.parse('$supabaseUrl/hinopt_screens?id=eq.$id'),
        headers: _headers,
        body: jsonEncode({'enrollment_status': 'REVOKED'}),
      );
      _triggerNotification('🔒 Screen "$name" has been revoked.');
      fetchData();
    }
  }

  Future<void> createTenant(String name, String email, int quota) async {
    final res = await http.post(
      Uri.parse('$supabaseUrl/hinopt_tenants'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'contact_email': email,
        'max_screens': quota,
        'status': 'ACTIVE',
      }),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      _triggerNotification('✅ Client "$name" registered in Supabase Cloud!');
    } else {
      _showErrorDialog('Failed to create tenant (${res.statusCode}): ${res.body}');
    }
    fetchData();
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

  void _showPairingDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedTId = tenants.isNotEmpty ? tenants.first['id'] : '';
    String selectedTier = 'PRO';
    int durationDays = 730; // 2 years free pilot

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.tv, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Pair New Display Screen'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter 6-Digit Activation Code displayed on screen:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                  decoration: InputDecoration(
                    hintText: 'A9X4B2',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Screen Designation / Vehicle ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Auto-Rickshaw #01 (HITEC City)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Assign to Tenant:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButtonFormField<String>(
                  value: selectedTId.isNotEmpty ? selectedTId : null,
                  items: tenants.map<DropdownMenuItem<String>>((t) {
                    return DropdownMenuItem(value: t['id'].toString(), child: Text(t['name']));
                  }).toList(),
                  onChanged: (v) => setDlgState(() => selectedTId = v ?? ''),
                ),
                const SizedBox(height: 12),
                const Text('License Tier & Duration:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedTier,
                        items: const [
                          DropdownMenuItem(value: 'CORE', child: Text('CORE')),
                          DropdownMenuItem(value: 'PRO', child: Text('PRO (Auto Kiosk)')),
                          DropdownMenuItem(value: 'ENTERPRISE', child: Text('ENTERPRISE')),
                        ],
                        onChanged: (v) => setDlgState(() => selectedTier = v ?? 'PRO'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: durationDays,
                        items: const [
                          DropdownMenuItem(value: 730, child: Text('2 Years (₹0 Pilot)')),
                          DropdownMenuItem(value: 365, child: Text('1 Year')),
                          DropdownMenuItem(value: 90, child: Text('90 Days')),
                        ],
                        onChanged: (v) => setDlgState(() => durationDays = v ?? 730),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () {
                if (codeCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty && selectedTId.isNotEmpty) {
                  Navigator.pop(ctx);
                  preAuthorizeScreen(codeCtrl.text, selectedTId, nameCtrl.text, selectedTier, durationDays);
                }
              },
              child: const Text('Issue License & Pair', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewTenantDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final quotaCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Commercial Tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client Company Name (e.g. Metro Media, Prime Ads)')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Contact Email')),
            TextField(controller: quotaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authorized Screen Quota')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              createTenant(nameCtrl.text, emailCtrl.text, int.tryParse(quotaCtrl.text) ?? 10);
            },
            child: const Text('Register Tenant'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: const Text('</> HINOPT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
            ),
            const SizedBox(width: 12),
            const Text('Sovereign Authority Admin', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: 'Refresh Fleet',
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: notifications.isNotEmpty,
              label: Text('${notifications.length}'),
              child: const Icon(Icons.notifications),
            ),
            onPressed: () => _showNotificationsSheet(),
            tooltip: 'Live Alerts & Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_to_queue),
        label: const Text('Pair Screen', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showPairingDialog,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
          : RefreshIndicator(
              onRefresh: fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Zero Demo Notice banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sovereign Zero-Demo Instance: Operating in 100% clean production mode. Only registered commercial fleets and authorized physical screens will appear.',
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Telemetry Overview Metrics
                  _buildMetricCards(),
                  const SizedBox(height: 16),

                  // Commercial Tenants Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Commercial Tenants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Tenant'),
                        onPressed: _showNewTenantDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTenantsSection(),
                  const SizedBox(height: 20),

                  // Screen Fleet Table Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Enrolled Screens & Hardware Telemetry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${screens.length} total screens', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildScreensList(),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCards() {
    final activeCount = screens.where((s) => s['enrollment_status'] == 'ACTIVE').length;
    final preAuthCount = screens.where((s) => s['enrollment_status'] == 'PRE_AUTHORIZED').length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final onlineCount = screens.where((s) {
      if (s['last_heartbeat_at'] == null) return false;
      return (now - DateTime.parse(s['last_heartbeat_at']).millisecondsSinceEpoch) < 600000;
    }).length;

    return Row(
      children: [
        Expanded(
          child: _metricCard('Total Screens', '${screens.length}', Icons.tv, Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard('Online Now', '$onlineCount', Icons.wifi, Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard('Pending Pair', '$preAuthCount', Icons.pending_actions, Colors.amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard('Active Licenses', '$activeCount', Icons.verified_user, Colors.purple),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantsSection() {
    if (tenants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Zero commercial tenants registered. Click "+ Add Tenant" to register a client advertising agency.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Fleets'),
            selected: selectedTenantId == null,
            onSelected: (_) {
              setState(() => selectedTenantId = null);
              fetchData();
            },
          ),
          const SizedBox(width: 8),
          ...tenants.map((t) {
            final isSel = selectedTenantId == t['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${t['name']} (Max: ${t['max_screens']})'),
                selected: isSel,
                onSelected: (_) {
                  setState(() => selectedTenantId = t['id']);
                  fetchData();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScreensList() {
    if (screens.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: const [
              Icon(Icons.tv_off, size: 40, color: Colors.grey),
              SizedBox(height: 12),
              Text('Zero Display Screens Enrolled', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Clean database state. Turn on an auto display and click "Pair Screen" below.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: screens.length,
      itemBuilder: (ctx, i) {
        final s = screens[i];
        final now = DateTime.now().millisecondsSinceEpoch;
        final bool isOnline = s['last_heartbeat_at'] != null &&
            (now - DateTime.parse(s['last_heartbeat_at']).millisecondsSinceEpoch) < 600000;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOnline ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              child: Icon(Icons.tv, color: isOnline ? Colors.green : Colors.grey),
            ),
            title: Text(s['screen_name'] ?? 'Unnamed Screen', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Model: ${s['hardware_model']} | SN: ${s['serial_number']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (s['battery_level_percent'] != null)
                      Text('🔋 ${s['battery_level_percent']}%', style: const TextStyle(fontSize: 11)),
                    if (s['soc_temperature_celsius'] != null) ...[
                      const SizedBox(width: 8),
                      Text('🌡️ ${s['soc_temperature_celsius']}°C', style: const TextStyle(fontSize: 11)),
                    ],
                    const SizedBox(width: 8),
                    Text('Tier: ${s['license_tier']}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                  ],
                ),
              ],
            ),
            trailing: s['enrollment_status'] == 'ACTIVE'
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => revokeScreen(s['id'], s['screen_name']),
                    tooltip: 'Revoke License',
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Code: ${s['activation_code']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Alerts & Push Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  child: Text('No active alert notifications. Fleet is operating normally.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155)),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.notifications_active, color: Colors.amber, size: 20),
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
