import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class AlertsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> devices;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic> device) onSelectDevice;

  const AlertsScreen({
    super.key,
    required this.events,
    required this.devices,
    required this.isDark,
    required this.onRefresh,
    required this.onSelectDevice,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final devMap = {for (final d in devices) (d['id'] as num).toInt(): d};

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Notifikasi 24 Jam', style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 17)),
        actions: [
          IconButton(onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, color: text)),
        ],
      ),
      body: events.isEmpty
          ? const Center(child: Text('Belum ada notifikasi 24 jam terakhir', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ev = events[i];
                  final dev = devMap[(ev['deviceId'] as num?)?.toInt() ?? 0];
                  final t = '${ev['type'] ?? ''}';
                  final alarm = (ev['attributes'] as Map?)?['alarm'];
                  return Container(
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      onTap: dev != null ? () => onSelectDevice(dev) : null,
                      leading: const CircleAvatar(backgroundColor: Color(0x22EF4444), child: Icon(Icons.notifications_active_rounded, color: Colors.redAccent, size: 18)),
                      title: Text('${dev?['name'] ?? 'Unit #${ev['deviceId']}'}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: text)),
                      subtitle: Text(alarm != null ? '$t ($alarm)' : t, style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w700)),
                      trailing: Text(AppFmt.dateTime(ev['eventTime']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
