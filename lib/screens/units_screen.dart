import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class UnitsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Map<int, Map<String, dynamic>> positions;
  final String filter;
  final String search;
  final void Function(String) onFilterChange;
  final void Function(String) onSearchChange;
  final void Function(Map<String, dynamic>) onSelectUnit;
  final bool isDark;

  const UnitsScreen({
    super.key,
    required this.devices,
    required this.positions,
    required this.filter,
    required this.search,
    required this.onFilterChange,
    required this.onSearchChange,
    required this.onSelectUnit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filtered = devices.where((dev) {
      final pos = positions[(dev['id'] as num?)?.toInt() ?? 0];
      final online = AppFmt.isOnline(dev);
      final moving = AppFmt.isMoving(dev, pos);
      if (filter == 'moving' && !moving) return false;
      if (filter == 'parked' && !(online && !moving)) return false;
      if (filter == 'offline' && online) return false;
      if (filter == 'sleep' && !AppFmt.isGpsSleep(dev, pos)) return false;
      if (filter == 'always_on' && !AppFmt.isGpsAlwaysOn(dev, pos)) return false;
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        final attrs = dev['attributes'] as Map<String, dynamic>? ?? {};
        final name = '${dev['name'] ?? ''}'.toLowerCase();
        final model = '${attrs['vehicleModel'] ?? dev['model'] ?? ''}'.toLowerCase();
        final renter = '${attrs['renterName'] ?? ''}'.toLowerCase();
        return name.contains(q) || model.contains(q) || renter.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: onSearchChange,
                style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Cari plat, model, penyewa...',
                  hintStyle: TextStyle(color: muted),
                  prefixIcon: Icon(Icons.search_rounded, color: muted),
                  filled: true,
                  fillColor: card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChipBtn('Semua', 'all', filter, onFilterChange, isDark),
                  const SizedBox(width: 8),
                  _FilterChipBtn('Jalan', 'moving', filter, onFilterChange, isDark),
                  const SizedBox(width: 8),
                  _FilterChipBtn('Parkir', 'parked', filter, onFilterChange, isDark),
                  const SizedBox(width: 8),
                  _FilterChipBtn('Offline', 'offline', filter, onFilterChange, isDark),
                  const SizedBox(width: 8),
                  _FilterChipBtn('💤 Sleep', 'sleep', filter, onFilterChange, isDark),
                  const SizedBox(width: 8),
                  _FilterChipBtn('⚡ Always-On (Boros Aki)', 'always_on', filter, onFilterChange, isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final dev = filtered[i];
                  final pos = positions[(dev['id'] as num?)?.toInt() ?? 0];
                  final online = AppFmt.isOnline(dev);
                  final moving = AppFmt.isMoving(dev, pos);
                  final isSleep = AppFmt.isGpsSleep(dev, pos);
                  final isAlwaysOn = AppFmt.isGpsAlwaysOn(dev, pos);
                  final volt = AppFmt.powerVolt(pos);
                  final mins = AppFmt.minutesSinceFix(dev, pos);
                  final attrs = dev['attributes'] as Map<String, dynamic>? ?? {};
                  final photo = attrs['unitPhoto']?.toString() ?? '';
                  final stColor = moving ? const Color(0xFF10B981) : (online ? const Color(0xFFF59E0B) : const Color(0xFF64748B));

                  return InkWell(
                    onTap: () => onSelectUnit(dev),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          _UnitAvatar(photoUrl: photo, statusColor: stColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${dev['name'] ?? ''}', style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 14)),
                                Text('${attrs['vehicleModel'] ?? dev['model'] ?? 'Armada'} • ${dev['uniqueId'] ?? ''}', overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (isAlwaysOn)
                                      const _MiniTag('⚡ Always-On', Colors.redAccent)
                                    else if (isSleep)
                                      _MiniTag('💤 Sleep (${mins}m)', Colors.blueAccent),
                                    if (volt != null && volt > 1.0)
                                      _MiniTag('🔋 ${volt.toStringAsFixed(1)}V', volt < 12.0 ? Colors.redAccent : Colors.teal),
                                    if (attrs['renterName'] != null)
                                      _MiniTag('👤 ${attrs['renterName']}', Colors.indigoAccent),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: stColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(moving ? '${AppFmt.speedKmh(pos)} km/h' : (online ? 'Parkir' : 'Offline'), style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _UnitAvatar extends StatelessWidget {
  final String photoUrl;
  final Color statusColor;
  const _UnitAvatar({required this.photoUrl, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: statusColor, width: 2.5)),
        child: ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _dot())),
      );
    }
    return Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withOpacity(0.12)), child: _dot());
  }

  Widget _dot() => Container(width: 16, height: 16, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)));
}

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;
  final bool isDark;
  const _FilterChipBtn(this.label, this.value, this.current, this.onTap, this.isDark);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
      selected: active,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      onSelected: (_) => onTap(value),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
