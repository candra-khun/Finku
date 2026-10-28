import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _cashController = TextEditingController();
  final _bankController = TextEditingController();
  final _cardController = TextEditingController();
  int _page = 0;
  bool _isSaving = false;
  late final Future<List<Asset>> _assetsFuture;

  @override
  void initState() {
    super.initState();
    _assetsFuture = context.read<Repo>().assets();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cashController.dispose();
    _bankController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish(saveBalances: true);
  }

  Future<void> _finish({required bool saveBalances}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (saveBalances) {
        final assets = await _assetsFuture;
        final balances = <int, int>{};
        _addBalance(balances, assets, 'Tunai', _cashController.text);
        _addBalance(balances, assets, 'Bank', _bankController.text);
        _addBalance(balances, assets, 'Kartu', _cardController.text);
        await context.read<Repo>().updateInitialBalances(balances);
      }
      await AppSettings.instance.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addBalance(
    Map<int, int> balances,
    List<Asset> assets,
    String groupName,
    String value,
  ) {
    final asset =
        assets.where((item) => item.name == _defaultAssetName(groupName));
    if (asset.isNotEmpty && value.trim().isNotEmpty) {
      balances[asset.first.id] = parseRibuan(value);
    }
  }

  String _defaultAssetName(String groupName) {
    switch (groupName) {
      case 'Tunai':
        return 'Dompet';
      case 'Bank':
        return 'Rekening Bank';
      default:
        return 'Kartu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Finku',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => _finish(saveBalances: false),
                    child: const Text('Lewati'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  const _InfoStep(
                    icon: Icons.receipt_long_rounded,
                    title: 'Catat keuangan, tanpa ribet',
                    message:
                        'Aplikasi ini untuk mencatat pendapatan dan pengeluaran. Data tersimpan di ponsel, tanpa akun dan tanpa internet.',
                  ),
                  const _InfoStep(
                    icon: Icons.grid_view_rounded,
                    title: 'Tiga modul utama',
                    message:
                        'Transaksi untuk mencatat dan melihat riwayat, Statistik untuk melihat uang habis ke mana, Aset untuk melihat saldo Tunai, Bank, dan Kartu.',
                  ),
                  const _InfoStep(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Mencatat itu cepat',
                    message:
                        'Ketuk +, pilih Pendapatan, Pengeluaran, atau Transfer, lalu isi. Kategori, aset, dan tag bisa ditambah sendiri langsung dari form.',
                  ),
                  _InitialBalanceStep(
                    cashController: _cashController,
                    bankController: _bankController,
                    cardController: _cardController,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? colors.primary
                              : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _next,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_page == 3
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded),
                    label: Text(_page == 3 ? 'Mulai pakai' : 'Lanjut'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoStep({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(icon, size: 64, color: colors.onPrimaryContainer),
          ),
          const SizedBox(height: 42),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _InitialBalanceStep extends StatelessWidget {
  final TextEditingController cashController;
  final TextEditingController bankController;
  final TextEditingController cardController;

  const _InitialBalanceStep({
    required this.cashController,
    required this.bankController,
    required this.cardController,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: 44,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Atur saldo awal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Saldo aset dihitung dari saldo awal ditambah transaksi. Isi yang Anda punya sekarang agar angkanya akurat sejak hari pertama.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        _BalanceField(
          controller: cashController,
          icon: Icons.wallet_rounded,
          label: 'Tunai',
          hint: 'Saldo di dompet',
        ),
        const SizedBox(height: 12),
        _BalanceField(
          controller: bankController,
          icon: Icons.account_balance_rounded,
          label: 'Bank',
          hint: 'Saldo rekening',
        ),
        const SizedBox(height: 12),
        _BalanceField(
          controller: cardController,
          icon: Icons.credit_card_rounded,
          label: 'Kartu',
          hint: 'Saldo kartu',
        ),
        const SizedBox(height: 12),
        Text(
          'Boleh dilewati dan diisi nanti dari modul Aset.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _BalanceField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;

  const _BalanceField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        prefixText: '${AppSettings.instance.currency.symbol} ',
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
