import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import 'database.dart';
import 'repository.dart';

class BackupSummary {
  final DateTime createdAt;
  final int transactionCount;
  final int assetCount;
  final int categoryCount;
  final int tagCount;
  final int memoCount;

  const BackupSummary({
    required this.createdAt,
    required this.transactionCount,
    required this.assetCount,
    required this.categoryCount,
    required this.tagCount,
    required this.memoCount,
  });
}

class BackupService {
  final Repo repo;
  final AppDb _d = AppDb.instance;

  BackupService(this.repo);

  /// Ekspor seluruh database ke Map JSON
  Future<Map<String, dynamic>> createBackupData() async {
    final db = await _d.db;
    return {
      'app': 'finku',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'asset_groups': await db.query('asset_groups'),
      'assets': await db.query('assets'),
      'categories': await db.query('categories'),
      'tags': await db.query('tags'),
      'transactions': await db.query('transactions'),
      'transaction_tags': await db.query('transaction_tags'),
      'memos': await db.query('memos'),
      'closings': await db.query('closings'),
      'budgets': await db.query('budgets'),
      'recurring_transactions': await db.query('recurring_transactions'),
      'savings_goals': await db.query('savings_goals'),
      'goal_allocations': await db.query('goal_allocations'),
    };
  }

  /// Ekspor ke string JSON terformat
  Future<String> exportBackupJson() async {
    final data = await createBackupData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Buat file cadangan lokal dan bagikan melalui sistem share sheet
  Future<String> exportAndShareBackup() async {
    final jsonStr = await exportBackupJson();
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateStr = ymd(now).replaceAll('-', '');
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'finku_backup_${dateStr}_$timeStr.ksbackup';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(jsonStr, encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/json', name: fileName)],
        subject: 'Cadangan Data Finku',
        text: 'Berkas cadangan data Finku ($fileName)',
      ),
    );
    return filePath;
  }

  /// Validasi konten JSON cadangan dan kembalikan ringkasannya
  BackupSummary validateBackup(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Format berkas cadangan tidak valid (bukan JSON object).');
    }
    if (decoded['app'] != 'finku' && decoded['app'] != 'keuangan_saku') {
      throw const FormatException(
          'Berkas ini bukan berkas cadangan resmi Finku.');
    }
    final createdAt =
        DateTime.tryParse(decoded['created_at']?.toString() ?? '') ??
            DateTime.now();
    final txs = (decoded['transactions'] as List?) ?? [];
    final assets = (decoded['assets'] as List?) ?? [];
    final categories = (decoded['categories'] as List?) ?? [];
    final tags = (decoded['tags'] as List?) ?? [];
    final memos = (decoded['memos'] as List?) ?? [];

    return BackupSummary(
      createdAt: createdAt,
      transactionCount: txs.length,
      assetCount: assets.length,
      categoryCount: categories.length,
      tagCount: tags.length,
      memoCount: memos.length,
    );
  }

  /// Pilih berkas cadangan melalui FilePicker
  Future<String?> pickBackupFile() async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ksbackup', 'json', 'txt'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null) return null;
    return File(path).readAsString();
  }

  /// Eksekusi pemulihan data (Restore) ke dalam SQLite database
  Future<void> restoreFromJson(String jsonStr) async {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format berkas cadangan tidak valid.');
    }
    if (decoded['app'] != 'finku' && decoded['app'] != 'keuangan_saku') {
      throw const FormatException(
          'Berkas ini bukan berkas cadangan Finku.');
    }

    final db = await _d.db;
    await db.transaction((txn) async {
      // 1. Bersihkan tabel lama dalam urutan dependensi foreign key
      await txn.delete('recurring_transactions').catchError((_) => 0);
      await txn.delete('budgets').catchError((_) => 0);
      await txn.delete('transaction_tags');
      await txn.delete('transactions');
      await txn.delete('memos');
      await txn.delete('closings');
      await txn.delete('tags');
      await txn.delete('assets');
      await txn.delete('categories');
      await txn.delete('asset_groups');

      // 2. Masukkan data cadangan
      final groups = (decoded['asset_groups'] as List?) ?? [];
      for (final r in groups) {
        await txn.insert('asset_groups', Map<String, dynamic>.from(r as Map));
      }

      final assets = (decoded['assets'] as List?) ?? [];
      for (final r in assets) {
        await txn.insert('assets', Map<String, dynamic>.from(r as Map));
      }

      final categories = (decoded['categories'] as List?) ?? [];
      for (final r in categories) {
        await txn.insert('categories', Map<String, dynamic>.from(r as Map));
      }

      final tags = (decoded['tags'] as List?) ?? [];
      for (final r in tags) {
        await txn.insert('tags', Map<String, dynamic>.from(r as Map));
      }

      final transactions = (decoded['transactions'] as List?) ?? [];
      for (final r in transactions) {
        await txn.insert('transactions', Map<String, dynamic>.from(r as Map));
      }

      final txTags = (decoded['transaction_tags'] as List?) ?? [];
      for (final r in txTags) {
        await txn.insert(
            'transaction_tags', Map<String, dynamic>.from(r as Map));
      }

      final memos = (decoded['memos'] as List?) ?? [];
      for (final r in memos) {
        await txn.insert('memos', Map<String, dynamic>.from(r as Map));
      }

      final closings = (decoded['closings'] as List?) ?? [];
      for (final r in closings) {
        await txn.insert('closings', Map<String, dynamic>.from(r as Map));
      }

      final budgets = (decoded['budgets'] as List?) ?? [];
      for (final r in budgets) {
        await txn.insert('budgets', Map<String, dynamic>.from(r as Map)).catchError((_) => 0);
      }

      final recurring = (decoded['recurring_transactions'] as List?) ?? [];
      for (final r in recurring) {
        await txn.insert('recurring_transactions', Map<String, dynamic>.from(r as Map)).catchError((_) => 0);
      }

      final goals = (decoded['savings_goals'] as List?) ?? [];
      for (final r in goals) {
        await txn.insert('savings_goals', Map<String, dynamic>.from(r as Map)).catchError((_) => 0);
      }

      final allocations = (decoded['goal_allocations'] as List?) ?? [];
      for (final r in allocations) {
        await txn.insert('goal_allocations', Map<String, dynamic>.from(r as Map)).catchError((_) => 0);
      }
    });

    // Beritahu seluruh app bahwa data telah diperbarui
    repo.notifyChanged();
  }

  /// Ekspor transaksi ke format CSV yang kompatibel penuh dengan Excel
  Future<String> generateCsv({
    DateTime? from,
    DateTime? to,
    String separator = ';',
  }) async {
    final start = from ?? DateTime(2000);
    final end = to ?? DateTime(2100);
    final items = await repo.transactions(start, end);

    final buffer = StringBuffer();
    // Tambahkan UTF-8 Byte Order Mark (BOM) agar Microsoft Excel otomatis membaca UTF-8 dengan benar
    buffer.write('\uFEFF');

    final headers = [
      'No',
      'Tanggal',
      'Jenis',
      'Kategori',
      'Aset Asal',
      'Aset Tujuan',
      'Nominal',
      'Format Rupiah',
      'Catatan',
      'Deskripsi',
      'Tag',
    ];

    buffer.writeln(
        headers.map((h) => _escapeCsv(h, separator)).join(separator));

    for (var i = 0; i < items.length; i++) {
      final t = items[i];
      final typeLabel = switch (t.type) {
        'income' => 'Pendapatan',
        'expense' => 'Pengeluaran',
        'transfer' => 'Transfer',
        _ => t.type,
      };

      final catLabel = t.isTransfer ? 'Transfer' : (t.categoryName ?? '-');
      final tagLabel = t.tags.map((tg) => tg.name).join(', ');

      final row = [
        (i + 1).toString(),
        ymd(t.date),
        typeLabel,
        catLabel,
        t.assetName,
        t.toAssetName ?? '',
        t.amount.toString(),
        rupiah(t.amount),
        t.note,
        t.description,
        tagLabel,
      ];

      buffer.writeln(row.map((c) => _escapeCsv(c, separator)).join(separator));
    }

    return buffer.toString();
  }

  /// Simpan dan bagikan berkas CSV/Excel
  Future<String> exportAndShareCsv({
    DateTime? from,
    DateTime? to,
    String separator = ';',
  }) async {
    final csvContent =
        await generateCsv(from: from, to: to, separator: separator);
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateStr = ymd(now).replaceAll('-', '');
    final fileName = 'laporan_transaksi_$dateStr.csv';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(csvContent, encoding: utf8);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'text/csv', name: fileName)],
        subject: 'Laporan Finku (CSV/Excel)',
        text: 'Laporan transaksi Finku ($fileName)',
      ),
    );

    return filePath;
  }

  String _escapeCsv(String val, String separator) {
    if (val.contains(separator) ||
        val.contains('"') ||
        val.contains('\n') ||
        val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}

