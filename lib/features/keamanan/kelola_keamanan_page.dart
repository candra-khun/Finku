import 'package:flutter/material.dart';

import '../../core/security_service.dart';
import 'atur_pin_page.dart';

class KelolaKeamananPage extends StatefulWidget {
  const KelolaKeamananPage({super.key});

  @override
  State<KelolaKeamananPage> createState() => _KelolaKeamananPageState();
}

class _KelolaKeamananPageState extends State<KelolaKeamananPage> {
  final _sec = SecurityService.instance;

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      // Buka setup PIN
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AturPinPage(mode: PinFlowMode.setup)),
      );
      if (ok == true && mounted) {
        setState(() {});
      }
    } else {
      // Verifikasi dulu sebelum mematikan
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AturPinPage(mode: PinFlowMode.verify)),
      );

      if (verified == true) {
        await _sec.disableLock();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunci aplikasi berhasil dinonaktifkan'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
      }
    }
  }

  Future<void> _changePin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AturPinPage(mode: PinFlowMode.change)),
    );
    if (ok == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _changeTimeout() async {
    final current = _sec.timeoutSeconds;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Kunci Otomatis'),
        children: [
          ListTile(
            title: const Text('Langsung'),
            subtitle: const Text('Saat aplikasi keluar atau berpindah'),
            trailing: current == 0 ? const Icon(Icons.check, color: Colors.teal) : null,
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            title: const Text('Setelah 1 Menit'),
            subtitle: const Text('Beri jeda 1 menit sebelum terkunci'),
            trailing: current == 60 ? const Icon(Icons.check, color: Colors.teal) : null,
            onTap: () => Navigator.pop(ctx, 60),
          ),
          ListTile(
            title: const Text('Setelah 5 Menit'),
            subtitle: const Text('Beri jeda 5 menit sebelum terkunci'),
            trailing: current == 300 ? const Icon(Icons.check, color: Colors.teal) : null,
            onTap: () => Navigator.pop(ctx, 300),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      await _sec.setTimeoutSeconds(selected);
      setState(() {});
    }
  }

  String _timeoutLabel(int seconds) {
    if (seconds == 0) return 'Langsung saat keluar';
    if (seconds == 60) return 'Setelah 1 menit';
    if (seconds == 300) return 'Setelah 5 menit';
    return '${seconds ~/ 60} menit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = _sec.isLockEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan & Kunci Aplikasi'),
      ),
      body: ListenableBuilder(
        listenable: _sec,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Kartu Status Utama
              Card(
                elevation: 0,
                color: isEnabled
                    ? (isDark ? const Color(0xFF1E3A34) : const Color(0xFFE6F4EA))
                    : (isDark ? const Color(0xFF23272F) : Colors.grey.shade100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isEnabled
                        ? Colors.teal.withValues(alpha: 0.4)
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isEnabled
                            ? Colors.teal.withValues(alpha: 0.2)
                            : (isDark ? Colors.white12 : Colors.black12),
                        child: Icon(
                          isEnabled ? Icons.shield : Icons.shield_outlined,
                          color: isEnabled ? Colors.teal : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEnabled ? 'Aplikasi Terkunci Aman' : 'Kunci Aplikasi Nonaktif',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isEnabled
                                  ? (_sec.isBiometricEnabled && _sec.hasBiometrics
                                      ? 'Dilindungi PIN 6 digit & Sidik Jari'
                                      : 'Dilindungi PIN 6 digit')
                                  : 'Aktifkan untuk melindungi data dari akses tanpa izin',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        onChanged: (val) => _toggleLock(val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (isEnabled) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'PENGATURAN KUNCI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      // Ubah PIN
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Ubah PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Ganti 6 digit PIN saat ini dengan PIN baru'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePin,
                      ),
                      Divider(height: 1, indent: 56, color: isDark ? Colors.white12 : Colors.black12),

                      // Buka dengan Sidik Jari / Biometrik
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Buka dengan Sidik Jari', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _sec.hasBiometrics
                              ? 'Buka cepat tanpa mengetik PIN'
                              : 'Perangkat tidak mendukung biometrik',
                        ),
                        value: _sec.isBiometricEnabled && _sec.hasBiometrics,
                        onChanged: _sec.hasBiometrics
                            ? (val) => _sec.setBiometricEnabled(val)
                            : null,
                      ),
                      Divider(height: 1, indent: 56, color: isDark ? Colors.white12 : Colors.black12),

                      // Batas Waktu Kunci Otomatis
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Kunci Otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_timeoutLabel(_sec.timeoutSeconds)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changeTimeout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tombol Uji Kunci
                OutlinedButton.icon(
                  onPressed: () {
                    _sec.lock();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Kunci Sekarang (Tes Layar Kunci)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // Info & Tips Privasi
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E232B) : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'PIN disimpan secara terenkripsi (SHA-256 salted hash) dan data biometrik dikelola secara native oleh sistem keamanan ponsel Anda. Tidak ada data sandi yang dikirim keluar.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
