import 'package:flutter/material.dart';
import '../config/brand_config.dart';
import '../services/traccar_service.dart';
import '../utils/formatters.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> devices;
  final bool isDark;
  final String mapLayer;
  final VoidCallback onToggleTheme;
  final void Function(String) onChangeMapLayer;
  final VoidCallback onOpenTokenOrder;
  final void Function(Map<String, dynamic>) onOpenRenewal;
  final VoidCallback onLogout;

  const AccountScreen({
    super.key,
    required this.user,
    required this.devices,
    required this.isDark,
    required this.mapLayer,
    required this.onToggleTheme,
    required this.onChangeMapLayer,
    required this.onOpenTokenOrder,
    required this.onOpenRenewal,
    required this.onLogout,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _tokens = 0;

  @override
  void initState() {
    super.initState();
    TraccarService.instance.getTokenBalance((widget.user['id'] as num).toInt()).then((v) {
      if (mounted) setState(() => _tokens = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final card = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final now = DateTime.now();

    final expiring = widget.devices.where((d) {
      final exp = DateTime.tryParse('${d['expirationTime'] ?? ''}');
      return exp != null && exp.difference(now).inDays <= 30;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  CircleAvatar(radius: 26, backgroundColor: BrandConfig.primaryColor, child: const Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.user['name'] ?? 'Owner'}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
                        Text('${widget.user['email'] ?? '-'}', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KUOTA TOKEN LISENSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                      Text('$_tokens Token', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: widget.onOpenTokenOrder,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('+ Beli Token', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            if (expiring.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perlu Diperpanjang (${expiring.length})', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.amber)),
                    const SizedBox(height: 8),
                    ...expiring.take(10).map((d) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${d['name']}', style: TextStyle(fontWeight: FontWeight.w800, color: text)),
                          subtitle: Text('Exp: ${AppFmt.shortDate(d['expirationTime']?.toString())}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                          trailing: ElevatedButton(onPressed: () => widget.onOpenRenewal(d), child: const Text('Perpanjang', style: TextStyle(fontSize: 11))),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22)),
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.isDark,
                    onChanged: (_) => widget.onToggleTheme(),
                    title: Text('Mode Gelap (Dark Mode)', style: TextStyle(fontWeight: FontWeight.w800, color: text, fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tampilan Peta', style: TextStyle(fontWeight: FontWeight.w800, color: text, fontSize: 13)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'google_road', label: Text('Jalan', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 'google_sat', label: Text('Satelit', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 'minimal', label: Text('Min', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {widget.mapLayer},
                        onSelectionChanged: (s) => widget.onChangeMapLayer(s.first),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: widget.onLogout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('KELUAR AKUN', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
