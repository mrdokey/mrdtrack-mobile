import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/brand_config.dart';
import 'services/traccar_service.dart';
import 'screens/login_screen.dart';
import 'screens/cockpit_home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/units_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/account_screen.dart';
import 'widgets/unit_modals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MrdTrackApp());
}

class MrdTrackApp extends StatefulWidget {
  const MrdTrackApp({super.key});

  @override
  State<MrdTrackApp> createState() => _MrdTrackAppState();
}

class _MrdTrackAppState extends State<MrdTrackApp> {
  bool _booting = true;
  bool _isDark = true;
  String _mapLayer = 'google_road';
  int _tabIndex = 0;
  String _filter = 'all';
  String _search = '';

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _devices = [];
  Map<int, Map<String, dynamic>> _positions = {};
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _selectedDevice;
  (double, double, String)? _incidentPin;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('mrd_is_dark') ?? true;
    _mapLayer = prefs.getString('mrd_map_layer') ?? 'google_road';
    final session = await TraccarService.instance.getSession();
    if (session != null && session['id'] != null) {
      _user = session;
      await _loadData();
      _connectSocket();
    }
    if (mounted) setState(() => _booting = false);
  }

  Future<void> _loadData() async {
    final devs = await TraccarService.instance.getDevices();
    final posList = await TraccarService.instance.getPositions();
    final posMap = <int, Map<String, dynamic>>{};
    for (final p in posList) {
      final did = (p['deviceId'] as num?)?.toInt();
      if (did != null) posMap[did] = p;
    }
    if (mounted) {
      setState(() {
        _devices = devs;
        _positions = posMap;
      });
    }
    await _loadEvents(devs);
  }

  Future<void> _loadEvents(List<Map<String, dynamic>> devs) async {
    if (devs.isEmpty) return;
    final ids = devs.take(60).map((d) => (d['id'] as num).toInt()).toList();
    final now = DateTime.now();
    final evs = await TraccarService.instance.getEvents(now.subtract(const Duration(hours: 24)), now.add(const Duration(minutes: 5)), ids);
    if (mounted) {
      setState(() => _events = evs.reversed.toList());
    }
  }

  void _connectSocket() {
    TraccarService.instance.connectSocket(
      onPositions: (list) {
        if (!mounted) return;
        setState(() {
          for (final p in list) {
            final did = (p['deviceId'] as num?)?.toInt();
            if (did != null) _positions[did] = p;
          }
        });
      },
      onDevices: (list) {
        if (!mounted) return;
        setState(() {
          final map = {for (final d in _devices) (d['id'] as num).toInt(): d};
          for (final d in list) {
            final id = (d['id'] as num?)?.toInt();
            if (id != null) map[id] = {...?map[id], ...d};
          }
          _devices = map.values.toList();
        });
      },
      onEvents: (list) {
        if (!mounted) return;
        setState(() => _events = [...list.reversed, ..._events].take(120).toList());
      },
    );
  }

  Future<void> _toggleTheme() async {
    final next = !_isDark;
    setState(() => _isDark = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mrd_is_dark', next);
  }

  Future<void> _changeLayer(String layer) async {
    setState(() => _mapLayer = layer);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mrd_map_layer', layer);
  }

  void _updateDevice(Map<String, dynamic> updated) {
    setState(() {
      if (_selectedDevice?['id'] == updated['id']) _selectedDevice = updated;
      _devices = _devices.map((d) => d['id'] == updated['id'] ? updated : d).toList();
    });
  }

  void _openService(BuildContext ctx, Map<String, dynamic> dev) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceModalSheet(
        device: dev,
        position: _positions[(dev['id'] as num).toInt()],
        onDeviceUpdated: _updateDevice,
        isDark: _isDark,
      ),
    );
  }

  void _openAlarms(BuildContext ctx, Map<String, dynamic> dev) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnitAlarmModalSheet(
        device: dev,
        isDark: _isDark,
        onLocateIncident: (lat, lng, title) {
          setState(() {
            _selectedDevice = null;
            _incidentPin = (lat, lng, title);
            _tabIndex = 1;
          });
        },
      ),
    );
  }

  void _openTokenOrder(BuildContext ctx) {
    if (_user == null) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TokenOrderModalSheet(user: _user!, onSuccess: _loadData, isDark: _isDark),
    );
  }

  void _openRenewal(BuildContext ctx, Map<String, dynamic> dev) {
    if (_user == null) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RenewalModalSheet(
        device: dev,
        user: _user!,
        onSuccess: _loadData,
        onOpenTokenOrder: () => _openTokenOrder(ctx),
        isDark: _isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: BrandConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: BrandConfig.primaryColor,
        brightness: _isDark ? Brightness.dark : Brightness.light,
      ),
      home: _booting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
              ? LoginScreen(
                  isDark: _isDark,
                  onToggleTheme: _toggleTheme,
                  onLoginSuccess: (u) async {
                    setState(() => _user = u);
                    await _loadData();
                    _connectSocket();
                  },
                )
              : Builder(
                  builder: (ctx) => Scaffold(
                    body: IndexedStack(
                      index: _tabIndex,
                      children: [
                        CockpitHomeScreen(
                          user: _user,
                          devices: _devices,
                          positions: _positions,
                          isDark: _isDark,
                          onToggleTheme: _toggleTheme,
                          onOpenFilteredMap: (f) => setState(() { _filter = f; _tabIndex = 1; }),
                          onSelectDevice: (d) => setState(() { _selectedDevice = d; _incidentPin = null; _tabIndex = 1; }),
                          onOpenRenewal: (d) => _openRenewal(ctx, d),
                          onRefresh: _loadData,
                        ),
                        MapScreen(
                          devices: _devices,
                          positions: _positions,
                          selectedDevice: _selectedDevice,
                          filter: _filter,
                          isDark: _isDark,
                          mapLayer: _mapLayer,
                          incidentPin: _incidentPin,
                          onSelectDevice: (d) => setState(() { _selectedDevice = d; _incidentPin = null; }),
                          onChangeMapLayer: _changeLayer,
                          onToggleTheme: _toggleTheme,
                          onOpenService: (d) => _openService(ctx, d),
                          onOpenAlarms: (d) => _openAlarms(ctx, d),
                          onOpenRenewal: (d) => _openRenewal(ctx, d),
                          onDeviceUpdated: _updateDevice,
                        ),
                        UnitsScreen(
                          devices: _devices,
                          positions: _positions,
                          filter: _filter,
                          search: _search,
                          onFilterChange: (f) => setState(() => _filter = f),
                          onSearchChange: (q) => setState(() => _search = q),
                          onSelectUnit: (d) => setState(() { _selectedDevice = d; _incidentPin = null; _tabIndex = 1; }),
                          isDark: _isDark,
                        ),
                        AlertsScreen(
                          events: _events,
                          devices: _devices,
                          isDark: _isDark,
                          onRefresh: () => _loadEvents(_devices),
                          onSelectDevice: (d) => setState(() { _selectedDevice = d; _tabIndex = 1; }),
                        ),
                        AccountScreen(
                          user: _user!,
                          devices: _devices,
                          isDark: _isDark,
                          mapLayer: _mapLayer,
                          onToggleTheme: _toggleTheme,
                          onChangeMapLayer: _changeLayer,
                          onOpenTokenOrder: () => _openTokenOrder(ctx),
                          onOpenRenewal: (d) => _openRenewal(ctx, d),
                          onLogout: () async {
                            await TraccarService.instance.logout();
                            setState(() {
                              _user = null;
                              _devices = [];
                              _positions = {};
                              _selectedDevice = null;
                              _tabIndex = 0;
                            });
                          },
                        ),
                      ],
                    ),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: _tabIndex,
                      onDestinationSelected: (i) => setState(() => _tabIndex = i),
                      destinations: [
                        const NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Kokpit'),
                        const NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Peta'),
                        const NavigationDestination(icon: Icon(Icons.two_wheeler_rounded), label: 'Armada'),
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: _events.isNotEmpty,
                            label: Text('${_events.length > 99 ? '99+' : _events.length}'),
                            child: const Icon(Icons.notifications_rounded),
                          ),
                          label: 'Notif',
                        ),
                        const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Akun'),
                      ],
                    ),
                  ),
                ),
    );
  }
}
