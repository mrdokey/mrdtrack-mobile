import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/traccar_service.dart';
import '../utils/formatters.dart';

const _emerald = Color(0xFF10B981);

class ServiceModalSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  final Map<String, dynamic>? position;
  final void Function(Map<String, dynamic> updated) onDeviceUpdated;
  final bool isDark;

  const ServiceModalSheet({
    super.key,
    required this.device,
    required this.position,
    required this.onDeviceUpdated,
    required this.isDark,
  });

  @override
  State<ServiceModalSheet> createState() => _ServiceModalSheetState();
}

class _ServiceModalSheetState extends State<ServiceModalSheet> {
  bool _editLimits = false;
  bool _saving = false;
  late TextEditingController _oilCtrl;
  late TextEditingController _cvtCtrl;
  late TextEditingController _brakeCtrl;

  @override
  void initState() {
    super.initState();
    final attrs = widget.device['attributes'] as Map<String, dynamic>? ?? {};
    _oilCtrl = TextEditingController(text: '${attrs['limitOilKm'] ?? 2000}');
    _cvtCtrl = TextEditingController(text: '${attrs['limitCvtKm'] ?? 8000}');
    _brakeCtrl = TextEditingController(text: '${attrs['limitBrakeKm'] ?? 15000}');
  }

  Future<void> _reset(String key, String label, int km) async {
    final okConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset $label'),
        content: Text('Catat ${widget.device['name']} sudah $label pada KM $km?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (okConfirm != true) return;
    final id = (widget.device['id'] as num).toInt();
    final ok = await TraccarService.instance.updateDeviceAttribute(id, {key: km});
    if (ok && mounted) {
      final attrs = Map<String, dynamic>.from(widget.device['attributes'] as Map? ?? {});
      attrs[key] = km;
      widget.onDeviceUpdated({...widget.device, 'attributes': attrs});
      Navigator.pop(context);
    }
  }

  Future<void> _saveLimits() async {
    setState(() => _saving = true);
    final id = (widget.device['id'] as num).toInt();
    final next = {
      'limitOilKm': int.tryParse(_oilCtrl.text) ?? 2000,
      'limitCvtKm': int.tryParse(_cvtCtrl.text) ?? 8000,
      'limitBrakeKm': int.tryParse(_brakeCtrl.text) ?? 15000,
    };
    final ok = await TraccarService.instance.updateDeviceAttribute(id, next);
    if (ok && mounted) {
      final attrs = Map<String, dynamic>.from(widget.device['attributes'] as Map? ?? {});
      attrs.addAll(next);
      widget.onDeviceUpdated({...widget.device, 'attributes': attrs});
      setState(() => _editLimits = false);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final box = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final attrs = widget.device['attributes'] as Map<String, dynamic>? ?? {};
    final km = AppFmt.odometerKm(widget.position);

    final items = [
      ('lastOilKm', 'Oli Mesin', (attrs['limitOilKm'] as num?)?.toInt() ?? 2000, (attrs['lastOilKm'] as num?)?.toInt() ?? 0),
      ('lastCvtKm', 'Servis CVT & Belt', (attrs['limitCvtKm'] as num?)?.toInt() ?? 8000, (attrs['lastCvtKm'] as num?)?.toInt() ?? 0),
      ('lastBrakeKm', 'Ban & Rem', (attrs['limitBrakeKm'] as num?)?.toInt() ?? 15000, (attrs['lastBrakeKm'] as num?)?.toInt() ?? 0),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.device['name']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
                    Text('Odometer: $km km', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editLimits = !_editLimits),
                  icon: const Icon(Icons.settings, size: 16),
                  label: Text(_editLimits ? 'Tutup' : 'Atur Batas KM', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (_editLimits) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _oilCtrl, keyboardType: TextInputType.number, style: TextStyle(color: text, fontSize: 12), decoration: const InputDecoration(labelText: 'Oli (KM)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _cvtCtrl, keyboardType: TextInputType.number, style: TextStyle(color: text, fontSize: 12), decoration: const InputDecoration(labelText: 'CVT (KM)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _brakeCtrl, keyboardType: TextInputType.number, style: TextStyle(color: text, fontSize: 12), decoration: const InputDecoration(labelText: 'Ban (KM)'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveLimits,
                        child: Text(_saving ? 'Menyimpan...' : 'Simpan Batas KM'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...items.map((it) {
              final used = (km - it.$4).clamp(0, 999999);
              final pct = (used / it.$3).clamp(0.0, 1.0);
              final c = used >= it.$3 ? Colors.red : (pct >= 0.8 ? Colors.amber : _emerald);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${it.$2} (Batas ${it.$3} km)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
                            Text('Jalan: $used / ${it.$3} km', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _reset(it.$1, it.$2, km),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                          child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: pct, color: c, backgroundColor: Colors.grey.withOpacity(0.2), minHeight: 5, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class UnitAlarmModalSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  final void Function(double lat, double lng, String title) onLocateIncident;
  final bool isDark;

  const UnitAlarmModalSheet({
    super.key,
    required this.device,
    required this.onLocateIncident,
    required this.isDark,
  });

  @override
  State<UnitAlarmModalSheet> createState() => _UnitAlarmModalSheetState();
}

class _UnitAlarmModalSheetState extends State<UnitAlarmModalSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  Map<int, String> _geos = {};
  Map<int, Map<String, dynamic>> _posMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devId = (widget.device['id'] as num).toInt();
    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 24));
    final to = now.add(const Duration(minutes: 5));

    final results = await Future.wait([
      TraccarService.instance.getEvents(from, to, [devId]),
      TraccarService.instance.getGeofencesLight(),
    ]);
    final evs = (results[0] as List<Map<String, dynamic>>).reversed.toList();
    final geos = results[1] as Map<int, String>;
    final posIds = evs.map((e) => (e['positionId'] as num?)?.toInt()).whereType<int>().toSet().toList();
    final posList = await TraccarService.instance.getPositionsByIds(posIds);
    final pMap = {for (final p in posList) if (p['id'] != null) (p['id'] as num).toInt(): p};

    if (mounted) {
      setState(() {
        _events = evs;
        _geos = geos;
        _posMap = pMap;
        _loading = false;
      });
    }
  }

  (String, String?, bool) _label(Map<String, dynamic> ev) {
    final t = '${ev['type'] ?? ''}';
    if (t == 'geofenceEnter') return ('Masuk Wilayah', _geos[(ev['geofenceId'] as num?)?.toInt()] ?? 'Area Geofence', false);
    if (t == 'geofenceExit') return ('Keluar Wilayah', _geos[(ev['geofenceId'] as num?)?.toInt()] ?? 'Area Geofence', true);
    if (t == 'alarm') {
      final a = '${(ev['attributes'] as Map?)?['alarm'] ?? ''}';
      const names = {
        'powerCut': 'Kabel Aki Diputus / Dilepas!',
        'lowBattery': 'Baterai GPS Lemah',
        'vibration': 'Getaran Terdeteksi',
        'sos': 'Tombol SOS Ditekan',
        'tow': 'Kendaraan Diderek',
      };
      return (names[a] ?? 'Alarm: $a', null, true);
    }
    const map = {
      'ignitionOn': 'Mesin / ACC Menyala',
      'ignitionOff': 'Mesin / ACC Mati',
      'deviceOnline': 'Unit Online',
      'deviceOffline': 'Unit Offline',
      'deviceOverspeed': 'Kecepatan Berlebih',
    };
    return (map[t] ?? t, null, t == 'deviceOffline' || t == 'deviceOverspeed');
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final box = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.device['name']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
          const Text('Notifikasi 24 Jam Terakhir', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('Tidak ada notifikasi 24 jam terakhir', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final ev = _events[i];
                          final (title, sub, danger) = _label(ev);
                          final pid = (ev['positionId'] as num?)?.toInt();
                          final pos = pid != null ? _posMap[pid] : null;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: danger ? Colors.redAccent : text))),
                                    Text(AppFmt.dateTime(ev['eventTime']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                if (sub != null) Text('Lokasi: $sub', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                if (pos != null && pos['address'] != null) Text('${pos['address']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                if (pos != null && pos['latitude'] != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onLocateIncident(
                                          (pos['latitude'] as num).toDouble(),
                                          (pos['longitude'] as num).toDouble(),
                                          '${widget.device['name']}: $title',
                                        );
                                      },
                                      icon: const Icon(Icons.location_on, size: 14),
                                      label: const Text('Lihat Titik Lokasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class RenewalModalSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;
  final VoidCallback onOpenTokenOrder;
  final bool isDark;

  const RenewalModalSheet({
    super.key,
    required this.device,
    required this.user,
    required this.onSuccess,
    required this.onOpenTokenOrder,
    required this.isDark,
  });

  @override
  State<RenewalModalSheet> createState() => _RenewalModalSheetState();
}

class _RenewalModalSheetState extends State<RenewalModalSheet> {
  bool _loading = true;
  bool _tokenBusy = false;
  int _tokenBalance = 0;
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _invoice;
  String _plan = 'YEARLY';
  String _planType = 'YEARLY';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devId = (widget.device['id'] as num).toInt();
    final uid = (widget.user['id'] as num).toInt();
    final res = await Future.wait([
      TraccarService.instance.getTokenBalance(uid),
      TraccarService.instance.getRenewalInfo(devId),
    ]);
    if (mounted) {
      setState(() {
        _tokenBalance = res[0] as int;
        _info = res[1] as Map<String, dynamic>?;
        _loading = false;
      });
    }
  }

  int get _yearlyFee {
    final attrs = widget.device['attributes'] as Map<String, dynamic>? ?? {};
    final custom = int.tryParse('${attrs['subscriptionFee'] ?? 0}') ?? 0;
    if (custom > 0) return custom;
    return (_info?['yearlyFee'] as num?)?.toInt() ?? (_info?['fee'] as num?)?.toInt() ?? 350000;
  }

  int get _monthlyFee {
    final attrs = widget.device['attributes'] as Map<String, dynamic>? ?? {};
    final custom = int.tryParse('${attrs['monthlyFee'] ?? 0}') ?? 0;
    if (custom > 0) return custom;
    return (_info?['monthlyFee'] as num?)?.toInt() ?? 40000;
  }

  int get _fee => (_info?['isDirectPusat'] == true && _planType == 'MONTHLY') ? _monthlyFee : _yearlyFee;

  Future<void> _useToken() async {
    setState(() => _tokenBusy = true);
    try {
      final d = await TraccarService.instance.renewWithToken(
        (widget.device['id'] as num).toInt(),
        (widget.user['id'] as num).toInt(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${d['message'] ?? 'Selesai'}')));
      if (d['success'] == true) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _tokenBusy = false);
    }
  }

  Future<void> _createInvoice() async {
    setState(() => _loading = true);
    final inv = await TraccarService.instance.createRenewalInvoice(
      (widget.device['id'] as num).toInt(),
      '${widget.device['name'] ?? ''}',
      _fee,
      planType: _planType,
    );
    if (mounted) {
      setState(() {
        if (inv['success'] == true) _invoice = inv;
        _loading = false;
      });
    }
  }

  Future<void> _copy(String txt, String label) async {
    await Clipboard.setData(ClipboardData(text: txt));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label disalin!')));
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final box = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final isPusat = _info?['isDirectPusat'] == true;
    final dist = _info?['distributor'] as Map<String, dynamic>?;
    final distName = '${dist?['name'] ?? _info?['distributorName'] ?? 'Distributor Resmi'}';
    final distBankName = dist?['bankName']?.toString();
    final distBankAcc = dist?['bankAccount']?.toString();
    final distBankHolder = dist?['bankHolder']?.toString() ?? distName;
    final hasDistBank = distBankAcc != null && distBankAcc.isNotEmpty;
    final rawPhone = '${dist?['phone'] ?? _info?['contactPhone'] ?? '62895428400665'}'.replaceAll(RegExp(r'\D'), '');
    final waPhone = rawPhone.startsWith('0') ? '62${rawPhone.substring(1)}' : rawPhone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Perpanjang Layanan (+1 Tahun)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.device['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                  Text('IMEI: ${widget.device['uniqueId']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('Tarif: ${AppFmt.rupiah(_fee)} / ${(_info?['isDirectPusat'] == true && _planType == 'MONTHLY') ? 'Bulan' : 'Tahun'}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: text)),
                ],
              ),
            ),
            if (_tokenBalance > 0 && _invoice == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _emerald.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stok Token Anda', style: TextStyle(fontWeight: FontWeight.w800, color: _emerald)),
                        Text('$_tokenBalance Token', style: const TextStyle(fontWeight: FontWeight.w900, color: _emerald)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _tokenBusy ? null : _useToken,
                        style: ElevatedButton.styleFrom(backgroundColor: _emerald, foregroundColor: Colors.white),
                        child: Text(_tokenBusy ? 'Memproses...' : 'Potong 1 Token & Aktifkan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (!isPusat && _info != null) ...[
              Text('Dikelola oleh: $distName', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
              const SizedBox(height: 8),
              if (hasDistBank)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(distBankName ?? 'Transfer Bank', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                          Text(distBankAcc, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
                          Text('a.n $distBankHolder', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _copy(distBankAcc, 'Nomor Rekening'),
                        child: const Text('Salin'),
                      ),
                    ],
                  ),
                )
              else
                const Text('Distributor belum mengisi rekening bank. Hubungi WhatsApp di bawah ini.', style: TextStyle(fontSize: 12, color: Colors.amber)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  final msg = Uri.encodeComponent('Halo Admin $distName, saya ingin perpanjang GPS ${widget.device['name']} (${widget.device['uniqueId']}) sebesar ${AppFmt.rupiah(_fee)}.');
                  launchUrl(Uri.parse('https://wa.me/$waPhone?text=$msg'), mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Hubungi WhatsApp Distributor', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ] else ...[
              if (_invoice == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Bulanan (${AppFmt.rupiah(_monthlyFee)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        selected: _planType == 'MONTHLY',
                        onSelected: (_) => setState(() => _planType = 'MONTHLY'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Tahunan (${AppFmt.rupiah(_yearlyFee)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        selected: _planType == 'YEARLY',
                        onSelected: (_) => setState(() => _planType = 'YEARLY'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _createInvoice,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Buat Tagihan ${_planType == 'MONTHLY' ? 'Bulanan' : 'Tahunan'} OCBC', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ]
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          const Text('TRANSFER TEPAT HINGGA 3 DIGIT TERAKHIR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amber)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(AppFmt.rupiah((_invoice!['amount'] as num)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                              IconButton(onPressed: () => _copy('${_invoice!['amount']}', 'Nominal'), icon: const Icon(Icons.copy, size: 18)),
                            ],
                          ),
                          Text('Invoice: ${_invoice!['invoiceCode']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_invoice!['bank'] is Map)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_invoice!['bank']['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                                Text('${_invoice!['bank']['account']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
                                Text('a.n ${_invoice!['bank']['holder']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () => _copy('${_invoice!['bank']['account']}', 'Rekening'),
                              child: const Text('Salin'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
            if (_tokenBalance == 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenTokenOrder();
                },
                child: const Text('Mau beli stok Token Lisensi? Klik di sini'),
              ),
          ],
        ),
      ),
    );
  }
}

class TokenOrderModalSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;
  final bool isDark;

  const TokenOrderModalSheet({
    super.key,
    required this.user,
    required this.onSuccess,
    required this.isDark,
  });

  @override
  State<TokenOrderModalSheet> createState() => _TokenOrderModalSheetState();
}

class _TokenOrderModalSheetState extends State<TokenOrderModalSheet> {
  int _qty = 1;
  bool _loading = false;
  Map<String, dynamic>? _order;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final box = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final text = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final attrs = widget.user['attributes'] as Map<String, dynamic>? ?? {};
    final price = int.tryParse('${attrs['tokenPrice'] ?? 400000}') ?? 400000;
    final rawDist = '${attrs['distributorPhone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    final waDist = rawDist.startsWith('0') ? '62${rawDist.substring(1)}' : rawDist;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Beli Kuota Token Lisensi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
          const SizedBox(height: 10),
          if (_order == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
              child: Text('Tarif: ${AppFmt.rupiah(price)} / Token (1 Tahun)', style: const TextStyle(fontWeight: FontWeight.w900, color: _emerald)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Jumlah Token:', style: TextStyle(fontWeight: FontWeight.w800, color: text)),
                Row(
                  children: [
                    IconButton(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    Text('$_qty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: text)),
                    IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
              ],
            ),
            Text('Total: ${AppFmt.rupiah(_qty * price)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
            const SizedBox(height: 12),
            if (waDist.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  final msg = Uri.encodeComponent('Halo Admin, saya ingin order $_qty Token Lisensi untuk ${widget.user['name']} (${AppFmt.rupiah(_qty * price)}).');
                  launchUrl(Uri.parse('https://wa.me/$waDist?text=$msg'), mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.chat_rounded),
                label: Text('Pesan $_qty Token via WA Distributor'),
              )
            else
              ElevatedButton(
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  final res = await TraccarService.instance.orderTokens((widget.user['id'] as num).toInt(), _qty);
                  if (mounted) {
                    setState(() {
                      if (res['success'] == true) {
                        _order = res;
                        widget.onSuccess();
                      }
                      _loading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_loading ? 'Membuat Tagihan...' : 'Bayar Transfer OCBC'),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: box, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const Text('TRANSFER TEPAT KODE UNIK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amber)),
                  Text(AppFmt.rupiah((_order!['amount'] as num)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                  const SizedBox(height: 6),
                  Text('OCBC NISP: 693819570385\na.n Dody Fauzi Aprianto, ST', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: text)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          ],
        ],
      ),
    );
  }
}
