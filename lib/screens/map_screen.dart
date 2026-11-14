import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/traccar_service.dart';
import '../utils/formatters.dart';
import '../widgets/vehicle_cockpit_sheet.dart';

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final Map<int, Map<String, dynamic>> positions;
  final Map<String, dynamic>? selectedDevice;
  final String filter;
  final bool isDark;
  final String mapLayer;
  final (double, double, String)? incidentPin;
  final void Function(Map<String, dynamic>?) onSelectDevice;
  final void Function(String) onChangeMapLayer;
  final VoidCallback onToggleTheme;
  final void Function(Map<String, dynamic>) onOpenService;
  final void Function(Map<String, dynamic>) onOpenAlarms;
  final void Function(Map<String, dynamic>) onOpenRenewal;
  final void Function(Map<String, dynamic>) onDeviceUpdated;

  const MapScreen({
    super.key,
    required this.devices,
    required this.positions,
    required this.selectedDevice,
    required this.filter,
    required this.isDark,
    required this.mapLayer,
    required this.incidentPin,
    required this.onSelectDevice,
    required this.onChangeMapLayer,
    required this.onToggleTheme,
    required this.onOpenService,
    required this.onOpenAlarms,
    required this.onOpenRenewal,
    required this.onDeviceUpdated,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  bool _showLabels = true;
  bool _didFit = false;
  double _zoom = 12;

  Map<String, dynamic>? _playbackDev;
  String _pbRange = 'today';
  DateTimeRange? _customRange;
  int _pbSpeed = 1; // 1, 2, 4, 8
  List<Map<String, dynamic>> _route = [];
  int _pbIdx = 0;
  bool _playing = false;
  bool _loadingPb = false;
  Timer? _pbTimer;

  @override
  void dispose() {
    _pbTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_didFit && widget.devices.isNotEmpty && widget.positions.isNotEmpty) {
      _didFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
    if (widget.incidentPin != null && widget.incidentPin != oldWidget.incidentPin) {
      _mapCtrl.move(LatLng(widget.incidentPin!.$1, widget.incidentPin!.$2), 16.5);
    }
    if (widget.selectedDevice != null && widget.selectedDevice?['id'] != oldWidget.selectedDevice?['id']) {
      final pos = widget.positions[(widget.selectedDevice!['id'] as num).toInt()];
      if (pos?['latitude'] != null && pos?['longitude'] != null) {
        _mapCtrl.move(LatLng((pos!['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble()), 15.5);
      }
    }
  }

  void _fitAll() {
    final pts = <LatLng>[];
    for (final dev in widget.devices) {
      final pos = widget.positions[(dev['id'] as num?)?.toInt() ?? 0];
      if (pos?['latitude'] != null && pos?['longitude'] != null) {
        pts.add(LatLng((pos!['latitude'] as num).toDouble(), (pos['longitude'] as num).toDouble()));
      }
    }
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapCtrl.move(pts.first, 15);
    } else {
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(60)));
    }
  }

  Future<void> _startPlayback(Map<String, dynamic> dev, String range, {DateTimeRange? custom}) async {
    _pbTimer?.cancel();
    setState(() {
      _playbackDev = dev;
      _pbRange = range;
      if (custom != null) _customRange = custom;
      _loadingPb = true;
      _playing = false;
      _pbIdx = 0;
    });
    widget.onSelectDevice(null);

    final now = DateTime.now();
    DateTime from = DateTime(now.year, now.month, now.day);
    DateTime to = now;
    if (range == '6h') {
      from = now.subtract(const Duration(hours: 6));
    } else if (range == 'yesterday') {
      from = from.subtract(const Duration(days: 1));
      to = from.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (range == 'custom' && (custom ?? _customRange) != null) {
      final r = custom ?? _customRange!;
      from = DateTime(r.start.year, r.start.month, r.start.day, 0, 0, 0);
      to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    }

    final pts = await TraccarService.instance.getRoute((dev['id'] as num).toInt(), from, to);
    if (!mounted) return;
    setState(() {
      _route = pts;
      _loadingPb = false;
    });
    if (pts.length > 1) {
      final latLngs = pts.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList();
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(latLngs), padding: const EdgeInsets.all(60)));
    }
  }

  Future<void> _pickCustomDateRange() async {
    if (_playbackDev == null) return;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now),
    );
    if (picked != null) {
      _startPlayback(_playbackDev!, 'custom', custom: picked);
    }
  }

  void _startTimer() {
    _pbTimer?.cancel();
    final ms = (400 / _pbSpeed).round().clamp(40, 400);
    _pbTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (_pbIdx >= _route.length - 1) {
        _pbTimer?.cancel();
        if (mounted) setState(() => _playing = false);
      } else if (mounted) {
        setState(() => _pbIdx++);
        final pt = _route[_pbIdx];
        if (pt['latitude'] != null && pt['longitude'] != null) {
          _mapCtrl.move(LatLng((pt['latitude'] as num).toDouble(), (pt['longitude'] as num).toDouble()), _zoom);
        }
      }
    });
  }

  void _togglePlay() {
    if (_playing) {
      _pbTimer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    _startTimer();
  }

  void _cycleSpeed() {
    final next = _pbSpeed == 1 ? 2 : (_pbSpeed == 2 ? 4 : (_pbSpeed == 4 ? 8 : 1));
    setState(() => _pbSpeed = next);
    if (_playing) _startTimer();
  }

  String get _tileUrl {
    if (widget.mapLayer == 'google_sat') return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
    if (widget.mapLayer == 'minimal') {
      return widget.isDark
          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
          : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    }
    return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.devices.where((dev) {
      final pos = widget.positions[(dev['id'] as num?)?.toInt() ?? 0];
      if (pos?['latitude'] == null || pos?['longitude'] == null) return false;
      final online = AppFmt.isOnline(dev);
      final moving = AppFmt.isMoving(dev, pos);
      if (widget.filter == 'moving') return moving;
      if (widget.filter == 'parked') return online && !moving;
      if (widget.filter == 'offline') return !online;
      if (widget.filter == 'sleep') return AppFmt.isGpsSleep(dev, pos);
      if (widget.filter == 'always_on') return AppFmt.isGpsAlwaysOn(dev, pos);
      return true;
    }).toList();

    final markers = <Marker>[];
    for (final dev in visible) {
      final pos = widget.positions[(dev['id'] as num).toInt()]!;
      final lat = (pos['latitude'] as num).toDouble();
      final lng = (pos['longitude'] as num).toDouble();
      final online = AppFmt.isOnline(dev);
      final moving = AppFmt.isMoving(dev, pos);
      final c = moving ? const Color(0xFF10B981) : (online ? const Color(0xFFF59E0B) : const Color(0xFF64748B));
      final photo = (dev['attributes'] as Map?)?['unitPhoto']?.toString() ?? '';
      final selected = widget.selectedDevice?['id'] == dev['id'];

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: _showLabels && _zoom >= 13 ? 110 : 40,
          height: _showLabels && _zoom >= 13 ? 58 : 40,
          child: GestureDetector(
            onTap: () => widget.onSelectDevice(dev),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photo.isNotEmpty)
                  Container(
                    width: selected ? 38 : 30,
                    height: selected ? 38 : 30,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white, width: 2)),
                    child: ClipOval(
                      child: Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c)),
                    ),
                  )
                else
                  Container(
                    width: selected ? 24 : 18,
                    height: selected ? 24 : 18,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                if (_showLabels && _zoom >= 13)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '${dev['name'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.incidentPin != null) {
      markers.add(
        Marker(
          point: LatLng(widget.incidentPin!.$1, widget.incidentPin!.$2),
          width: 140,
          height: 50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                child: Text(widget.incidentPin!.$3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
              const Icon(Icons.location_on, color: Colors.red, size: 28),
            ],
          ),
        ),
      );
    }

    if (_playbackDev != null && _route.isNotEmpty && _pbIdx < _route.length) {
      final pt = _route[_pbIdx];
      markers.add(
        Marker(
          point: LatLng((pt['latitude'] as num).toDouble(), (pt['longitude'] as num).toDouble()),
          width: 30,
          height: 30,
          child: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.play_arrow, color: Colors.white, size: 18)),
        ),
      );
    }

    final polyPts = _route.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: const LatLng(-8.65, 115.19),
            initialZoom: 12,
            onPositionChanged: (camera, _) => _zoom = camera.zoom,
          ),
          children: [
            TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'id.mrdtrack.mobile'),
            if (polyPts.length > 1)
              PolylineLayer(polylines: [Polyline(points: polyPts, color: Colors.blueAccent, strokeWidth: 4.5)]),
            MarkerLayer(markers: markers.take(180).toList()),
          ],
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 12,
          child: Column(
            children: [
              _MapFab(
                icon: Icons.layers_rounded,
                isDark: widget.isDark,
                onTap: () {
                  final next = widget.mapLayer == 'google_road' ? 'google_sat' : (widget.mapLayer == 'google_sat' ? 'minimal' : 'google_road');
                  widget.onChangeMapLayer(next);
                },
              ),
              const SizedBox(height: 8),
              _MapFab(icon: widget.isDark ? Icons.light_mode : Icons.dark_mode, isDark: widget.isDark, onTap: widget.onToggleTheme),
              const SizedBox(height: 8),
              _MapFab(icon: Icons.label_rounded, isDark: widget.isDark, active: _showLabels, onTap: () => setState(() => _showLabels = !_showLabels)),
              const SizedBox(height: 8),
              _MapFab(icon: Icons.my_location_rounded, isDark: widget.isDark, onTap: _fitAll),
            ],
          ),
        ),
        if (widget.selectedDevice != null && _playbackDev == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VehicleCockpitSheet(
              device: widget.selectedDevice!,
              position: widget.positions[(widget.selectedDevice!['id'] as num).toInt()],
              isDark: widget.isDark,
              onClose: () => widget.onSelectDevice(null),
              onOpenPlayback: () => _startPlayback(widget.selectedDevice!, 'today'),
              onOpenService: () => widget.onOpenService(widget.selectedDevice!),
              onOpenAlarms: () => widget.onOpenAlarms(widget.selectedDevice!),
              onOpenRenewal: () => widget.onOpenRenewal(widget.selectedDevice!),
              onDeviceUpdated: widget.onDeviceUpdated,
            ),
          ),
        if (_playbackDev != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Playback: ${_playbackDev!['name']}', style: TextStyle(fontWeight: FontWeight.w900, color: widget.isDark ? Colors.white : Colors.black)),
                          Text('${_route.length} titik perjalanan', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      IconButton(onPressed: () { _pbTimer?.cancel(); setState(() { _playbackDev = null; _route = []; }); }, icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _PbRangeChip('6 Jam', _pbRange == '6h', () => _startPlayback(_playbackDev!, '6h')),
                      const SizedBox(width: 6),
                      _PbRangeChip('Hari Ini', _pbRange == 'today', () => _startPlayback(_playbackDev!, 'today')),
                      const SizedBox(width: 6),
                      _PbRangeChip('Kemarin', _pbRange == 'yesterday', () => _startPlayback(_playbackDev!, 'yesterday')),
                      const SizedBox(width: 6),
                      _PbRangeChip('Tgl Custom', _pbRange == 'custom', _pickCustomDateRange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPb)
                    const LinearProgressIndicator()
                  else if (_route.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Tidak ada data rute di rentang waktu ini', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  else ...[
                    Row(
                      children: [
                        IconButton.filled(onPressed: _togglePlay, icon: Icon(_playing ? Icons.pause : Icons.play_arrow)),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: _cycleSpeed,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                          child: Text('${_pbSpeed}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        Expanded(
                          child: Slider(
                            value: _pbIdx.toDouble(),
                            min: 0,
                            max: (_route.length - 1).toDouble().clamp(1, 999999),
                            onChanged: (v) => setState(() => _pbIdx = v.round()),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppFmt.dateTime(_route[_pbIdx]['fixTime']?.toString()), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
                        Text('${AppFmt.speedKmh(_route[_pbIdx])} km/h', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PbRangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PbRangeChip(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.grey.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey)),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool active;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.isDark, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF0F172A) : Colors.white),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: active ? Colors.white : (isDark ? Colors.white : Colors.black87))),
      ),
    );
  }
}
