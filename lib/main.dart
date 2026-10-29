import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_settings.dart';
import 'core/daily_reminder_service.dart';
import 'core/localization.dart';
import 'core/security_service.dart';
import 'core/widget_service.dart';
import 'data/repository.dart';
import 'features/aset/aset_page.dart';
import 'features/keamanan/lock_screen.dart';
import 'features/lainnya/lainnya_page.dart';
import 'features/splash/splash_screen.dart';
import 'features/statistik/statistik_page.dart';
import 'features/transaksi/transaksi_page.dart';
import 'features/transaksi/tx_form_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  await AppSettings.instance.init();
  await SecurityService.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => Repo(),
      child: const KeuanganApp(),
    ),
  );
}

class KeuanganApp extends StatelessWidget {
  static final ValueNotifier<bool> splashComplete = ValueNotifier<bool>(false);
  static bool hasShownSplash = false;

  const KeuanganApp({super.key});

  static const _seed = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final langCode = AppSettings.instance.languageCode;
        return MaterialApp(
          key: ValueKey('app_$langCode'),
          title: 'Finku',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: _seed,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: AppSettings.instance.themeMode,
          locale: Locale(langCode, langCode == 'id' ? 'ID' : 'US'),
          supportedLocales: const [
            Locale('id', 'ID'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            return SecurityGuard(child: child ?? const SizedBox.shrink());
          },
          home: hasShownSplash ? const HomeShell() : const SplashScreen(),
        );
      },
    );
  }
}

class SecurityGuard extends StatefulWidget {
  final Widget child;
  const SecurityGuard({super.key, required this.child});

  @override
  State<SecurityGuard> createState() => _SecurityGuardState();
}

class _SecurityGuardState extends State<SecurityGuard>
    with WidgetsBindingObserver {
  final _sec = SecurityService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _sec.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _sec.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sec, KeuanganApp.splashComplete]),
      builder: (context, _) {
        // Layar kunci (PIN / Sidik Jari) hanya ditampilkan setelah splash screen selesai
        final showLock = KeuanganApp.splashComplete.value &&
            _sec.isLockEnabled &&
            _sec.isLocked;

        return Stack(
          children: [
            widget.child,
            if (showLock)
              const Positioned.fill(
                child: LockScreen(),
              ),
          ],
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _widgetChannel =
      MethodChannel('com.contoh.keuangan_saku/widget');
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _setupWidgetChannel();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final repo = context.read<Repo>();
        final processed = await repo.processDueAutoRecurring();
        if (processed > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('$processed transaksi rutin otomatis telah dicatat'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.teal,
            ),
          );
        }
        // Update data ke home screen widget saat app start
        await WidgetService.updateWidgets(repo);
        await DailyReminderService.schedule();
      } catch (e) {
        debugPrint('Auto recurring / widget sync error: $e');
      }
    });
  }

  void _setupWidgetChannel() {
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction') {
        final action = call.arguments as String?;
        if (action != null) {
          _handleQuickAction(action);
        }
      }
    });

    _widgetChannel.invokeMethod<String>('getInitialAction').then((action) {
      if (action != null && mounted) {
        _handleQuickAction(action);
      }
    }).catchError((_) {});
  }

  void _handleQuickAction(String action) {
    if (!mounted) return;
    if (action == 'expense') {
      openTxForm(context, initialType: 'expense');
    } else if (action == 'income') {
      openTxForm(context, initialType: 'income');
    } else if (action == 'add') {
      openTxForm(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TransaksiPage(),
          StatistikPage(),
          AsetPage(),
          LainnyaPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'Transaksi'.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: 'Statistik'.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: 'Aset'.tr,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_outlined),
            selectedIcon: const Icon(Icons.more_horiz),
            label: 'Lainnya'.tr,
          ),
        ],
      ),
    );
  }
}
