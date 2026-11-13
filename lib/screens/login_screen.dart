import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/brand_config.dart';
import '../services/traccar_service.dart';

class LoginScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> user) onLoginSuccess;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('mrd_saved_email');
      if (saved != null && mounted) _emailCtrl.text = saved;
    });
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await TraccarService.instance.login(_emailCtrl.text, _passCtrl.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mrd_saved_email', _emailCtrl.text.trim());
      if (mounted) widget.onLoginSuccess(user);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primary = BrandConfig.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
                        ),
                        IconButton(
                          onPressed: widget.onToggleTheme,
                          icon: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: isDark ? Colors.amber : Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(BrandConfig.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: text)),
                    const SizedBox(height: 4),
                    Text('Fleet Cockpit & Smart GPS Control', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: text, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Email / Username',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(color: text, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('MASUK KE KOKPIT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
