class AppFmt {
  static String rupiah(num value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final revIdx = s.length - i;
      buf.write(s[i]);
      if (revIdx > 1 && revIdx % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  static String shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Lifetime';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  static String dateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $hh:$mm';
  }

  static int speedKmh(Map<String, dynamic>? pos) {
    final spd = (pos?['speed'] as num?)?.toDouble() ?? 0.0;
    return (spd * 1.852).round();
  }

  static bool isOnline(Map<String, dynamic> dev) => dev['status'] == 'online';

  static bool isMoving(Map<String, dynamic> dev, Map<String, dynamic>? pos) {
    if (!isOnline(dev)) return false;
    final spd = (pos?['speed'] as num?)?.toDouble() ?? 0.0;
    return spd > 1.08;
  }

  static int minutesSinceFix(Map<String, dynamic> dev, Map<String, dynamic>? pos) {
    final raw = pos?['fixTime']?.toString() ?? dev['lastUpdate']?.toString();
    final dt = raw != null ? DateTime.tryParse(raw) : null;
    if (dt == null) return 99999;
    return DateTime.now().difference(dt.toUtc()).inMinutes.abs();
  }

  static double? powerVolt(Map<String, dynamic>? pos) {
    final attrs = pos?['attributes'] as Map<String, dynamic>? ?? {};
    return (attrs['power'] as num?)?.toDouble();
  }

  // GPS Sleep: diam & tidak kirim sinyal > 10 menit (tapi masih aktif < 24 jam)
  static bool isGpsSleep(Map<String, dynamic> dev, Map<String, dynamic>? pos) {
    if (isMoving(dev, pos)) return false;
    final mins = minutesSinceFix(dev, pos);
    return (!isOnline(dev) && mins <= 1440) || (isOnline(dev) && mins > 10);
  }

  // GPS Always-On / Nyedot Aki: tetap online aktif <= 5 mnt saat parkir, atau ACC ON saat parkir, atau voltase < 12V
  static bool isGpsAlwaysOn(Map<String, dynamic> dev, Map<String, dynamic>? pos) {
    if (isMoving(dev, pos)) return false;
    final online = isOnline(dev);
    final mins = minutesSinceFix(dev, pos);
    final attrs = pos?['attributes'] as Map<String, dynamic>? ?? {};
    final accOn = attrs['ignition'] == true;
    final volt = powerVolt(pos);
    final lowVolt = volt != null && volt > 1.0 && volt < 12.0;
    return (online && mins <= 5) || (online && accOn) || lowVolt;
  }

  static int odometerKm(Map<String, dynamic>? pos) {
    final attrs = pos?['attributes'] as Map<String, dynamic>? ?? {};
    final totalDist = (attrs['totalDistance'] as num?)?.toDouble() ?? 0.0;
    return (totalDist / 1000.0).round();
  }

  static bool isServiceDue(Map<String, dynamic> dev, Map<String, dynamic>? pos) {
    final attrs = dev['attributes'] as Map<String, dynamic>? ?? {};
    final km = odometerKm(pos);
    final lastOil = (attrs['lastOilKm'] as num?)?.toInt() ?? 0;
    final lastCvt = (attrs['lastCvtKm'] as num?)?.toInt() ?? 0;
    final lastBrake = (attrs['lastBrakeKm'] as num?)?.toInt() ?? 0;
    final limOil = (attrs['limitOilKm'] as num?)?.toInt() ?? 2000;
    final limCvt = (attrs['limitCvtKm'] as num?)?.toInt() ?? 8000;
    final limBrake = (attrs['limitBrakeKm'] as num?)?.toInt() ?? 15000;
    return (km - lastOil >= limOil) || (km - lastCvt >= limCvt) || (km - lastBrake >= limBrake);
  }
}
