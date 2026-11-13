import 'package:flutter/material.dart';
import '../config/brand_config.dart';
import '../utils/formatters.dart';

class CockpitHomeScreen extends StatelessWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> devices;
  final Map<int, Map<String, dynamic>> positions;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final void Function(String filterKey) onOpenFilteredMap;
  final void Function(Map<String, dynamic> device) onSelectDevice;
  final void Function(Map<String, dynamic> device) onOpenRenewal;
  final Future<void> Function() onRefresh;

  const CockpitHomeScreen({
    super.key,
    required this.user,
    required this.devices,
    required this.positions,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenFilteredMap,
    required this.onSelectDevice,
    required this.onOpenRenewal,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final movingList = <Map<String, dynamic>>[];
    int parkedCount = 0;
    int offlineCount = 0;
    final serviceDueList = <Map<String, dynamic>>[];
    final expiringList = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final dev in devices) {
      final id = (dev['id'] as num?)?.toInt() ?? 0;
      final pos = positions[id];
      if (AppFmt.isMoving(dev, pos)) {
        movingList.add(dev);
      } else if (AppFmt.isOnline(dev)) {
        parkedCount++;
      } else {
        offlineCount++;
      }
      if (AppFmt.isServiceDue(dev, pos)) {
        serviceDueList.add(dev);
      }
      final exp = DateTime.tryParse('${dev['expirationTime'] ?? ''}');
      if (exp != null && exp.difference(now).inDays <= 30) {
        expiringList.add(dev);
      }
    }

    final bg = isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primary = BrandConfig.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.radar_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(BrandConfig.appName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: text)),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Halo, ${user?['name'] ?? 'Owner'} • ${devices.length} Unit',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleTheme,
                    style: IconButton.styleFrom(backgroundColor: card),
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.amber : primary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: [
                  _StatCard('Sedang Jalan', '${movingList.length}', const Color(0xFF10B981), Icons.navigation_rounded, card, text, () => onOpenFilteredMap('moving')),
                  _StatCard('Parkir Aman', '$parkedCount', const Color(0xFFF59E0B), Icons.local_parking_rounded, card, text, () => onOpenFilteredMap('parked')),
                  _StatCard('Unit Offline', '$offlineCount', const Color(0xFF64748B), Icons.wifi_off_rounded, card, text, () => onOpenFilteredMap('offline')),
                  _StatCard('Total Armada', '${devices.length}', primary, Icons.two_wheeler_rounded, card, text, () => onOpenFilteredMap('all')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Radar Unit Bergerak (${movingList.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
                  TextButton(onPressed: () => onOpenFilteredMap('moving'), child: const Text('Buka Peta')),
                ],
              ),
              if (movingList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
                  child: Text('Semua armada saat ini sedang parkir atau standby.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                )
              else
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: movingList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final dev = movingList[i];
                      final pos = positions[(dev['id'] as num?)?.toInt() ?? 0];
                      final kmh = AppFmt.speedKmh(pos);
                      final attrs = dev['attributes'] as Map<String, dynamic>? ?? {};
                      return InkWell(
                        onTap: () => onSelectDevice(dev),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 225,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark ? [const Color(0xFF0F172A), const Color(0xFF0B253A)] : [Colors.white, const Color(0xFFEFF6FF)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('${dev['name'] ?? ''}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                                    child: Text('$kmh km/h', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              Text('${attrs['vehicleModel'] ?? dev['model'] ?? 'Armada GPS'}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                              Row(
                                children: [
                                  Icon(Icons.person_rounded, size: 14, color: primary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      attrs['renterName'] != null ? '${attrs['renterName']}' : 'Tap untuk kontrol kokpit',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (serviceDueList.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Perlu Jadwal Servis (${serviceDueList.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
                const SizedBox(height: 8),
                ...serviceDueList.take(5).map((dev) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                      child: ListTile(
                        onTap: () => onSelectDevice(dev),
                        leading: const CircleAvatar(backgroundColor: Color(0x33F59E0B), child: Icon(Icons.build_rounded, color: Color(0xFFF59E0B), size: 18)),
                        title: Text('${dev['name'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: text)),
                        subtitle: Text('Sudah mencapai batas KM servis', style: TextStyle(fontSize: 11, color: muted)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    )),
              ],
              if (expiringList.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Masa Aktif Segera Habis (${expiringList.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
                const SizedBox(height: 8),
                ...expiringList.take(6).map((dev) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0x33EF4444), child: Icon(Icons.verified_user_rounded, color: Color(0xFFEF4444), size: 18)),
                        title: Text('${dev['name'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: text)),
                        subtitle: Text('Aktif s/d ${AppFmt.shortDate(dev['expirationTime']?.toString())}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
                        trailing: ElevatedButton(
                          onPressed: () => onOpenRenewal(dev),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Perpanjang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;

  const _StatCard(this.title, this.value, this.color, this.icon, this.cardColor, this.textColor, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withOpacity(0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
              ],
            ),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
