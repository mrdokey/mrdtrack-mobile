import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import '../config/brand_config.dart';

class TraccarService {
  static final TraccarService instance = TraccarService._();
  TraccarService._();

  String? _cookie;
  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _socketStopped = true;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_cookie != null && _cookie!.isNotEmpty) 'Cookie': _cookie!,
      };

  Future<void> initCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('mrd_session_cookie');
  }

  Future<void> _saveCookieFromResponse(http.Response res) async {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final match = RegExp(r'JSESSIONID=[^;,\s]+').firstMatch(raw);
    if (match != null) {
      _cookie = match.group(0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mrd_session_cookie', _cookie!);
    }
  }

  Future<Map<String, dynamic>?> getSession() async {
    await initCookie();
    if (_cookie == null || _cookie!.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse('${BrandConfig.baseUrl}/api/session'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/session'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'email': email.trim(), 'password': password},
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      await _saveCookieFromResponse(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(res.body.isNotEmpty ? res.body : 'Email atau password salah');
  }

  Future<void> logout() async {
    disconnectSocket();
    try {
      await http.delete(Uri.parse('${BrandConfig.baseUrl}/api/session'), headers: _headers);
    } catch (_) {}
    _cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mrd_session_cookie');
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final res = await http.get(Uri.parse('${BrandConfig.baseUrl}/api/devices'), headers: _headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPositions() async {
    final res = await http.get(Uri.parse('${BrandConfig.baseUrl}/api/positions'), headers: _headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getRoute(int deviceId, DateTime from, DateTime to) async {
    final uri = Uri.parse('${BrandConfig.baseUrl}/api/reports/route').replace(queryParameters: {
      'deviceId': '$deviceId',
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getEvents(DateTime from, DateTime to, List<int> deviceIds) async {
    final params = <String, dynamic>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'type': 'allEvents',
      'deviceId': deviceIds.map((e) => '$e').toList(),
    };
    final uri = Uri.parse('${BrandConfig.baseUrl}/api/reports/events').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPositionsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final uri = Uri.parse('${BrandConfig.baseUrl}/api/positions').replace(
      queryParameters: {'id': ids.map((e) => '$e').toList()},
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  Future<Map<int, String>> getGeofencesLight() async {
    try {
      final res = await http.get(Uri.parse('${BrandConfig.baseUrl}/api/custom/geofences-light'), headers: _headers);
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return {for (final g in list) if (g['id'] != null) (g['id'] as num).toInt(): '${g['name'] ?? ''}'};
      }
    } catch (_) {}
    return {};
  }

  Future<String> shareDevice(int deviceId, DateTime expiration) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/devices/share'),
      headers: {..._headers, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'deviceId': '$deviceId', 'expiration': expiration.toUtc().toIso8601String()},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = res.body.trim();
      return 'https://gps.mrdsolution.my.id?token=$token';
    }
    throw Exception(res.body.isNotEmpty ? res.body : 'Gagal membuat link share');
  }

  Future<void> sendCommand(int deviceId, String type) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/commands/send'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'type': type}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Gagal kirim perintah');
    }
  }

  Future<bool> updateDeviceAttribute(int deviceId, Map<String, dynamic> attributes) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/custom/device-attribute'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'attributes': attributes}),
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<Map<String, dynamic>?> getRenewalInfo(int deviceId) async {
    final res = await http.get(
      Uri.parse('${BrandConfig.baseUrl}/api/custom/device/renewal-info?deviceId=$deviceId'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) as Map<String, dynamic> : null;
  }

  Future<int> getTokenBalance(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('${BrandConfig.baseUrl}/api/custom/distributor-token/balance?userId=$userId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        return (d['balance'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<Map<String, dynamic>> renewWithToken(int deviceId, int userId) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/custom/device/renew-with-token'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'userId': userId, 'plan': 'YEARLY'}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRenewalInvoice(int deviceId, String deviceName, int fee, {String planType = 'YEARLY'}) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/custom/device/create-renewal-invoice'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'deviceName': deviceName, 'fee': fee, 'planType': planType}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> orderTokens(int userId, int packageTokens) async {
    final res = await http.post(
      Uri.parse('${BrandConfig.baseUrl}/api/custom/distributor-token/order'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'packageTokens': packageTokens}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void connectSocket({
    required void Function(List<Map<String, dynamic>>) onPositions,
    required void Function(List<Map<String, dynamic>>) onDevices,
    required void Function(List<Map<String, dynamic>>) onEvents,
  }) {
    _socketStopped = false;
    _reconnectTimer?.cancel();
    if (_cookie == null || _cookie!.isEmpty) return;

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(BrandConfig.wsUrl),
        headers: {'Cookie': _cookie!},
      );
      _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['positions'] is List) {
              onPositions(List<Map<String, dynamic>>.from(data['positions']));
            }
            if (data['devices'] is List) {
              onDevices(List<Map<String, dynamic>>.from(data['devices']));
            }
            if (data['events'] is List) {
              onEvents(List<Map<String, dynamic>>.from(data['events']));
            }
          } catch (_) {}
        },
        onDone: () {
          if (!_socketStopped) {
            _reconnectTimer = Timer(const Duration(seconds: 3), () {
              connectSocket(onPositions: onPositions, onDevices: onDevices, onEvents: onEvents);
            });
          }
        },
        onError: (_) {
          if (!_socketStopped) {
            _reconnectTimer = Timer(const Duration(seconds: 4), () {
              connectSocket(onPositions: onPositions, onDevices: onDevices, onEvents: onEvents);
            });
          }
        },
      );
    } catch (_) {}
  }

  void disconnectSocket() {
    _socketStopped = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
