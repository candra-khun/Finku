import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/localization.dart';

class MasterBahasaPage extends StatelessWidget {
  const MasterBahasaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Master Bahasa'.tr),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final currentCode = settings.languageCode;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Kartu Status Bahasa Aktif
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E2826) : const Color(0xFFE6F4EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.withValues(alpha: 0.2),
                        child: Text(
                          settings.currentLanguage.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bahasa Aplikasi Saat Ini'.tr,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),                            const SizedBox(height: 2),
                            Text(
                              settings.currentLanguage.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            Text(
                              '(${settings.currentLanguage.nativeName})',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: Colors.teal, size: 24),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'PILIHAN BAHASA'.tr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
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
                    for (int i = 0; i < AppSettings.supportedLanguages.length; i++)
                      Builder(
                        builder: (ctx) {
                          final lang = AppSettings.supportedLanguages[i];
                          final isSelected = lang.code == currentCode;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Colors.teal.withValues(alpha: 0.15)
                                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                                  child: Text(lang.flag, style: const TextStyle(fontSize: 20)),
                                ),
                                title: Text(
                                  lang.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.teal : null,
                                  ),
                                ),
                                subtitle: Text(lang.nativeName, style: const TextStyle(fontSize: 12)),
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: Colors.teal)
                                    : null,
                                onTap: () async {
                                  await settings.setLanguage(lang.code);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${'Bahasa diubah ke'.tr} ${lang.name}'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.teal,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (i < AppSettings.supportedLanguages.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 56,
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info & Catatan
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
                          'Pilihan bahasa akan menyesuaikan format penanggalan, hari, bulan, dan komponen standar di seluruh aplikasi Finku.'.tr,
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

