import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/traccar_service.dart';
import '../utils/formatters.dart';

class VehicleCockpitSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  final Map<String, dynamic>? position;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onOpenPlayback;
  final VoidCallback onOpenService;
  final VoidCallback onOpenAlarms;
  final VoidCallback onOpenRenewal;
  final void Function(Map<String, dynamic> updated) onDeviceUpdated;

  const VehicleCockpitSheet({
    super.key,
    required this.device,
    required this.position,
    required this.isDark,
    required this.onClose,
    required this.onOpenPlayback,
    required this.onOpenService,
    required this.onOpenAlarms,
    required this.onOpenRenewal,
    required this.onDeviceUpdated,
  });

  @override
  State<VehicleCockpitSheet> createState() => _VehicleCockpitSheetState();
}

class _VehicleCockpitSheetState extends State<VehicleCockpitSheet> {
  String? _address;
  bool _loadingAddr = false;
  double _slideVal = 0.0;
  bool _sendingCutOff = false;

  @override
  void didUpdateWidget(covariant VehicleCockpitSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device['id'] != widget.device['id']) {
      _address = widget.position?['address']?.toString();
      _slideVal = 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _address = widget.position?['address']?.toString();
  }

  Future<void> _openShareTokenDialog() async {
    final hours = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Bagikan Live Tracking (Token)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            ListTile(leading: const Icon(Icons.timer), title: const Text('Berlaku 1 Jam'), onTap: () => Navigator.pop(c, 1)),
            ListTile(leading: const Icon(Icons.today), title: const Text('Berlaku 24 Jam'), onTap: () => Navigator.pop(c, 24)),
            ListTile(leading: const Icon(Icons.date_range), title: const Text('Berlaku 7 Hari'), onTap: () => Navigator.pop(c, 24 * 7)),
            ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Berlaku 30 Hari'), onTap: () => Navigator.pop(c, 24 * 30)),
          ],
        ),
      ),
    );
    if (hours == null || !mounted) return;
    try {
      final exp = DateTime.now().add(Duration(hours: hours));
      final url = await TraccarService.instance.shareDevice((widget.device['id'] as num).toInt(), exp);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Link Share Token Siap'),
          content: SelectableText(url, style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Tutup')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dCtx);
                final txt = Uri.encodeComponent('Pantau lokasi unit *${widget.device['name']}* secara live di sini: $url');
                launchUrl(Uri.parse('https://wa.me/?text=$txt'), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Kirim WA'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal buat token share: $e')));
    }
  }

  Future<void> _fetchAddress() async {
    final lat = widget.position?['latitude'];
    final lng = widget.position?['longitude'];
    if (lat == null || lng == null || _loadingAddr) return;
    setState(() => _loadingAddr = true);
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18'),
        headers: {'User-Agent': 'MRDTrackMobile/1.0'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (mounted && d['display_name'] != null) setState(() => _address = '${d['display_name']}');
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAddr = false);
  }

  Future<void> _executeCutOff(bool isCurrentlyCutOff) async {
    if (!AppFmt.isOnline(widget.device)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit sedang OFFLINE. Perintah ditahan agar tidak membebani antrean server.')),
      );
      setState(() => _slideVal = 0);
      return;
    }
    setState(() => _sendingCutOff = true);
    try {
      final next = !isCurrentlyCutOff;
      final id = (widget.device['id'] as num).toInt();
      await TraccarService.instance.sendCommand(id, next ? 'engineStop' : 'engineResume');
      await TraccarService.instance.updateDeviceAttribute(id, {'isCutOff': next});
      final attrs = Map<String, dynamic>.from(widget.device['attributes'] as Map? ?? {});
      attrs['isCutOff'] = next;
      widget.onDeviceUpdated({...widget.device, 'attributes': attrs});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next ? 'Perintah MATIKAN MESIN terkirim!' : 'Perintah HIDUPKAN MESIN terkirim!')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() { _sendingCutOff = false; _slideVal = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final box = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final attrs = widget.device['attributes'] as Map<String, dynamic>? ?? {};
    final pAttrs = widget.position?['attributes'] as Map<String, dynamic>? ?? {};
    final online = AppFmt.isOnline(widget.device);
    final moving = AppFmt.isMoving(widget.device, widget.position);
    final kmh = AppFmt.speedKmh(widget.position);
    final km = AppFmt.odometerKm(widget.position);
    final volt = pAttrs['power'] != null ? '${(pAttrs['power'] as num).toStringAsFixed(1)}V' : 'Normal';
    final isCutOff = attrs['isCutOff'] == true || pAttrs['out1'] == true || pAttrs['blocked'] == true;
    final serviceDue = AppFmt.isServiceDue(widget.device, widget.position);

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.device['name'] ?? ''}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: text)),
                    Text('${attrs['vehicleModel'] ?? widget.device['model'] ?? 'Armada GPS'}', style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Badge(moving ? 'Jalan' : (online ? 'Parkir' : 'Offline'), moving ? Colors.green : (online ? Colors.amber : Colors.grey)),
                        if (pAttrs['ignition'] != null)
                          _Badge('ACC ${pAttrs['ignition'] == true ? 'ON' : 'OFF'}', pAttrs['ignition'] == true ? Colors.blue : Colors.grey),
                        if (isCutOff) const _Badge('Cut-Off', Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    Text('$kmh', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: moving ? Colors.green : text)),
                    Text('KM/H', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(onPressed: widget.onClose, icon: Icon(Icons.close_rounded, color: muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (attrs['renterName'] != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Penyewa: ${attrs['renterName']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: text)),
                        Text('Selesai: ${attrs['rentEnd'] ?? '-'}', style: TextStyle(fontSize: 10, color: muted)),
                      ],
                    ),
                  ),
                  if (attrs['renterPhone'] != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        final raw = '${attrs['renterPhone']}'.replaceAll(RegExp(r'\D'), '');
                        final wa = raw.startsWith('0') ? '62${raw.substring(1)}' : raw;
                        launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('WA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
            ),
          InkWell(
            onTap: _fetchAddress,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(14)),
              child: Text(
                _address ?? (_loadingAddr ? 'Mengambil alamat...' : 'Tap untuk tampilkan alamat lengkap'),
                style: TextStyle(fontSize: 11, color: _address != null ? text : Colors.blueAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniBox('Daya / Aki', volt, box, text, muted, null)),
              const SizedBox(width: 8),
              Expanded(child: _MiniBox('Odometer', '$km km', box, text, muted, null)),
              const SizedBox(width: 8),
              Expanded(child: _MiniBox('Masa Aktif', AppFmt.shortDate(widget.device['expirationTime']?.toString()), box, Colors.amber, muted, widget.onOpenRenewal)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: !online ? Colors.grey.withOpacity(0.2) : (isCutOff ? Colors.green.withOpacity(0.18) : Colors.red.withOpacity(0.18)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  !online ? Icons.wifi_off : (isCutOff ? Icons.play_circle_fill : Icons.power_settings_new),
                  color: !online ? Colors.grey : (isCutOff ? Colors.green : Colors.redAccent),
                ),
                Expanded(
                  child: Slider(
                    value: _slideVal,
                    activeColor: isCutOff ? Colors.green : Colors.redAccent,
                    onChanged: _sendingCutOff ? null : (v) => setState(() => _slideVal = v),
                    onChangeEnd: (v) {
                      if (v >= 0.85) {
                        _executeCutOff(isCutOff);
                      } else {
                        setState(() => _slideVal = 0);
                      }
                    },
                  ),
                ),
                Text(
                  !online ? 'OFFLINE' : (isCutOff ? 'GESER HIDUPKAN' : 'GESER MATIKAN'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: !online ? Colors.grey : (isCutOff ? Colors.green : Colors.redAccent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(Icons.notifications_active_rounded, 'Alarm', Colors.redAccent, widget.onOpenAlarms),
              _ActionBtn(Icons.build_rounded, serviceDue ? 'Servis!' : 'Servis', serviceDue ? Colors.redAccent : Colors.amber, widget.onOpenService),
              _ActionBtn(Icons.history_rounded, 'Playback', Colors.blueAccent, widget.onOpenPlayback),
              _ActionBtn(Icons.directions_rounded, 'Rute', Colors.blue, () {
                final lat = widget.position?['latitude'];
                final lng = widget.position?['longitude'];
                if (lat != null && lng != null) {
                  launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);
                }
              }),
              _ActionBtn(Icons.share_rounded, 'Bagikan', muted, _openShareTokenDialog),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _MiniBox extends StatelessWidget {
  final String label;
  final String val;
  final Color bg;
  final Color valColor;
  final Color muted;
  final VoidCallback? onTap;
  const _MiniBox(this.label, this.val, this.bg, this.valColor, this.muted, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: muted)),
            const SizedBox(height: 2),
            Text(val, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: valColor)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
