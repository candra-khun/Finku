import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';

import '../core/format.dart';
import 'database.dart';
import 'models.dart';

class ClosedPeriodException implements Exception {
  final String period;
  ClosedPeriodException(this.period);

  @override
  String toString() =>
      'Periode ${periodLabel(period)} sudah ditutup. Buka kembali tutup buku untuk mengubah transaksinya.';
}

/// Satu-satunya pintu akses data. Setiap perubahan memanggil notifyListeners
/// sehingga halaman yang memakai RepoFuture memuat ulang datanya.
class Repo extends ChangeNotifier {
  final AppDb _d = AppDb.instance;

  void _changed() => notifyListeners();
  void notifyChanged() => notifyListeners();

  // ---------------------------------------------------------------- master

  Future<List<AssetGroup>> groups() async {
    final db = await _d.db;
    final rows = await db.query('asset_groups', orderBy: 'sort, id');
    return rows.map(AssetGroup.fromMap).toList();
  }

  Future<List<Asset>> assets({bool includeArchived = false}) async {
    final db = await _d.db;
    final rows = await db.query(
      'assets',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort, id',
    );
    return rows.map(Asset.fromMap).toList();
  }

  Future<List<Category>> categories(String type) async {
    final db = await _d.db;
    final rows = await db.query('categories',
        where: 'type = ?', whereArgs: [type], orderBy: 'sort, id');
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Tag>> tags() async {
    final db = await _d.db;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE');
    return rows.map(Tag.fromMap).toList();
  }

  Future<int> addGroup(String name) async {
    final db = await _d.db;
    final rows = await db
        .rawQuery('SELECT COALESCE(MAX(sort), 0) + 1 AS n FROM asset_groups');
    final id = await db.insert('asset_groups', {
      'name': name.trim(),
      'is_default': 0,
      'sort': rows.first['n'] as int,
    });
    _changed();
    return id;
  }

  Future<int> addAsset(String name, int groupId, int initialBalance) async {
    final db = await _d.db;
    final id = await db.insert('assets', {
      'name': name.trim(),
      'group_id': groupId,
      'initial_balance': initialBalance,
    });
    _changed();
    return id;
  }

  Future<int> addCategory(String name, String type) async {
    final db = await _d.db;
    final clean = name.trim();
    final existing = await db.query(
      'categories',
      where: 'type = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [type, clean],
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;
    final count = (await db.rawQuery(
            'SELECT COUNT(*) AS c FROM categories WHERE type = ?', [type]))
        .first['c'] as int;
    final id = await db.insert('categories', {
      'name': clean,
      'type': type,
      'color': categoryPalette[count % categoryPalette.length],
    });
    _changed();
    return id;
  }

  Future<int> addTag(String name) async {
    final db = await _d.db;
    final clean = name.trim();
    final existing = await db
        .query('tags', where: 'LOWER(name) = LOWER(?)', whereArgs: [clean]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    final id = await db.insert('tags', {'name': clean});
    _changed();
    return id;
  }

  /// Menghapus aset bila belum punya transaksi, selain itu diarsipkan agar
  /// riwayat tetap utuh. Mengembalikan true bila diarsipkan.
  Future<bool> removeAsset(int id) async {
    final db = await _d.db;
    final used = (await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE asset_id = ? OR to_asset_id = ?',
      [id, id],
    ))
        .first['c'] as int;
    if (used == 0) {
      await db.delete('assets', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update('assets', {'archived': 1},
          where: 'id = ?', whereArgs: [id]);
    }
    _changed();
    return used > 0;
  }

  Future<void> updateAsset(
    int id, {
    required String name,
    required int groupId,
    int? initialBalance,
  }) async {
    final db = await _d.db;
    final map = <String, Object?>{
      'name': name.trim(),
      'group_id': groupId,
    };
    if (initialBalance != null) {
      map['initial_balance'] = initialBalance;
    }
    await db.update('assets', map, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> reorderAssets(List<int> orderedIds) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'assets',
          {'sort': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
    _changed();
  }

  // ------------------------------------------------------------- kelola kategori

  Future<void> updateCategory(int id, {required String name, int? color}) async {
    final db = await _d.db;
    final map = <String, Object?>{'name': name.trim()};
    if (color != null) map['color'] = color;
    await db.update('categories', map, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<int> categoryUsageCount(int id) async {
    final db = await _d.db;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      [id],
    );
    return res.first['c'] as int;
  }

  Future<void> deleteCategory(int id, {int? targetCategoryId}) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'category_id': targetCategoryId},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  Future<void> reorderCategories(List<int> orderedIds) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'categories',
          {'sort': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
    _changed();
  }

  // ------------------------------------------------------------------ kelola tag

  Future<void> updateTag(int id, String name) async {
    final db = await _d.db;
    await db.update('tags', {'name': name.trim()},
        where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<int> tagUsageCount(int id) async {
    final db = await _d.db;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transaction_tags WHERE tag_id = ?',
      [id],
    );
    return res.first['c'] as int;
  }

  Future<void> deleteTag(int id) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      await txn.delete('transaction_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  // ------------------------------------------------------------ kelola grup aset

  Future<void> updateGroup(int id, String name) async {
    final db = await _d.db;
    await db.update('asset_groups', {'name': name.trim()},
        where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<int> groupAssetCount(int id) async {
    final db = await _d.db;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM assets WHERE group_id = ? AND archived = 0',
      [id],
    );
    return res.first['c'] as int;
  }

  Future<void> deleteGroup(int id, {int? targetGroupId}) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      if (targetGroupId != null) {
        await txn.update(
          'assets',
          {'group_id': targetGroupId},
          where: 'group_id = ?',
          whereArgs: [id],
        );
      }
      await txn.delete('asset_groups', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  Future<void> reorderGroups(List<int> orderedIds) async {
    final db = await _d.db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'asset_groups',
          {'sort': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
    _changed();
  }

  // ------------------------------------------------------------- transaksi

  Future<bool> isClosed(String period) async {
    final db = await _d.db;
    final rows =
        await db.query('closings', where: 'period = ?', whereArgs: [period]);
    return rows.isNotEmpty;
  }

  Future<void> _ensureOpen(DateTime date) async {
    final p = periodOf(date);
    if (await isClosed(p)) throw ClosedPeriodException(p);
  }

  Future<int> addTransaction(TxInput t) async {
    await _ensureOpen(t.date);
    final db = await _d.db;
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('transactions', t.toMap());
      for (final tagId in t.tagIds) {
        await txn.insert(
            'transaction_tags', {'transaction_id': id, 'tag_id': tagId});
      }
    });
    _changed();
    return id;
  }

  Future<void> updateTransaction(int id, TxInput t) async {
    final db = await _d.db;
    final old = await db.query('transactions',
        columns: ['date'], where: 'id = ?', whereArgs: [id]);
    if (old.isNotEmpty) {
      await _ensureOpen(parseYmd(old.first['date'] as String));
    }
    await _ensureOpen(t.date);
    await db.transaction((txn) async {
      await txn
          .update('transactions', t.toMap(), where: 'id = ?', whereArgs: [id]);
      await txn.delete('transaction_tags',
          where: 'transaction_id = ?', whereArgs: [id]);
      for (final tagId in t.tagIds) {
        await txn.insert(
            'transaction_tags', {'transaction_id': id, 'tag_id': tagId});
      }
    });
    _changed();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _d.db;
    final old = await db.query('transactions',
        columns: ['date'], where: 'id = ?', whereArgs: [id]);
    if (old.isEmpty) return;
    await _ensureOpen(parseYmd(old.first['date'] as String));
    await db.transaction((txn) async {
      await txn.delete('transaction_tags',
          where: 'transaction_id = ?', whereArgs: [id]);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  /// Daftar transaksi pada rentang tanggal (inklusif), terbaru di atas.
  /// [assetId] mencakup transaksi di mana aset menjadi asal atau tujuan.
  Future<List<TxItem>> transactions(
    DateTime from,
    DateTime to, {
    int? categoryId,
    String? type,
    int? assetId,
  }) async {
    final db = await _d.db;
    final where = <String>['t.date >= ?', 't.date <= ?'];
    final args = <Object?>[ymd(from), ymd(to)];
    if (categoryId != null) {
      where.add('t.category_id = ?');
      args.add(categoryId);
    }
    if (type != null) {
      where.add('t.type = ?');
      args.add(type);
    }
    if (assetId != null) {
      where.add('(t.asset_id = ? OR t.to_asset_id = ?)');
      args.addAll([assetId, assetId]);
    }
    final whereSql = where.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT t.*, c.name AS cat_name, a.name AS asset_name, a2.name AS to_asset_name
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      JOIN assets a ON a.id = t.asset_id
      LEFT JOIN assets a2 ON a2.id = t.to_asset_id
      WHERE $whereSql
      ORDER BY t.date DESC, t.id DESC
    ''', args);

    final ids = rows.map((r) => r['id'] as int).toList();
    final tagsByTx = <int, List<Tag>>{};
    if (ids.isNotEmpty) {
      final tagRows = await db.rawQuery('''
        SELECT tt.transaction_id AS tid, g.id AS id, g.name AS name
        FROM transaction_tags tt JOIN tags g ON g.id = tt.tag_id
        WHERE tt.transaction_id IN (${ids.join(',')})
      ''');
      for (final r in tagRows) {
        tagsByTx
            .putIfAbsent(r['tid'] as int, () => [])
            .add(Tag(id: r['id'] as int, name: r['name'] as String));
      }
    }
    return rows
        .map((r) => TxItem.fromMap(r, tagsByTx[r['id'] as int] ?? const []))
        .toList();
  }

  /// Mencari transaksi berdasarkan kata kunci pada catatan, deskripsi, kategori,
  /// tag, atau nama aset.
  Future<List<TxItem>> searchTransactions(
    String query, {
    DateTime? from,
    DateTime? to,
    String? type,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final db = await _d.db;
    final where = <String>[];
    final args = <Object?>[];

    if (from != null) {
      where.add('t.date >= ?');
      args.add(ymd(from));
    }
    if (to != null) {
      where.add('t.date <= ?');
      args.add(ymd(to));
    }
    if (type != null) {
      where.add('t.type = ?');
      args.add(type);
    }

    final pattern = '%$clean%';
    where.add('''(
      t.note LIKE ? OR
      t.description LIKE ? OR
      c.name LIKE ? OR
      a.name LIKE ? OR
      a2.name LIKE ? OR
      t.id IN (
        SELECT tt.transaction_id FROM transaction_tags tt
        JOIN tags tg ON tg.id = tt.tag_id
        WHERE tg.name LIKE ?
      )
    )''');
    args.addAll([pattern, pattern, pattern, pattern, pattern, pattern]);

    final whereSql = where.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT t.*, c.name AS cat_name, a.name AS asset_name, a2.name AS to_asset_name
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      JOIN assets a ON a.id = t.asset_id
      LEFT JOIN assets a2 ON a2.id = t.to_asset_id
      WHERE $whereSql
      ORDER BY t.date DESC, t.id DESC
    ''', args);

    final ids = rows.map((r) => r['id'] as int).toList();
    final tagsByTx = <int, List<Tag>>{};
    if (ids.isNotEmpty) {
      final tagRows = await db.rawQuery('''
        SELECT tt.transaction_id AS tid, g.id AS id, g.name AS name
        FROM transaction_tags tt JOIN tags g ON g.id = tt.tag_id
        WHERE tt.transaction_id IN (${ids.join(',')})
      ''');
      for (final r in tagRows) {
        tagsByTx
            .putIfAbsent(r['tid'] as int, () => [])
            .add(Tag(id: r['id'] as int, name: r['name'] as String));
      }
    }
    return rows
        .map((r) => TxItem.fromMap(r, tagsByTx[r['id'] as int] ?? const []))
        .toList();
  }

  Future<Totals> totals(
    DateTime from,
    DateTime to, {
    int? assetId,
    int? tagId,
  }) async {
    final db = await _d.db;
    final whereArgs = <Object?>[];
    final conditions = <String>['t.date >= ?', 't.date <= ?'];
    whereArgs.add(ymd(from));
    whereArgs.add(ymd(to));

    String joinClause = '';
    if (tagId != null) {
      joinClause += ' JOIN transaction_tags tt ON tt.transaction_id = t.id AND tt.tag_id = ?';
      whereArgs.add(tagId);
    }

    if (assetId != null) {
      conditions.add('t.asset_id = ?');
      whereArgs.add(assetId);
    }

    final where = conditions.join(' AND ');
    final r = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) AS inc,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS exp
      FROM transactions t $joinClause
      WHERE $where
    ''', whereArgs);
    return Totals(r.first['inc'] as int, r.first['exp'] as int);
  }

  /// Total per tanggal ("yyyy-MM-dd") pada rentang tertentu.
  Future<Map<String, Totals>> dailyTotals(DateTime from, DateTime to) async {
    final db = await _d.db;
    final rows = await db.rawQuery('''
      SELECT date,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS inc,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS exp
      FROM transactions WHERE date >= ? AND date <= ?
      GROUP BY date
    ''', [ymd(from), ymd(to)]);
    return {
      for (final r in rows)
        r['date'] as String: Totals(r['inc'] as int, r['exp'] as int),
    };
  }

  /// Total per bulan (1..12) untuk satu tahun.
  Future<Map<int, Totals>> monthlyTotals(
    int year, {
    int? assetId,
    int? tagId,
  }) async {
    final db = await _d.db;
    final whereArgs = <Object?>[];
    final conditions = <String>['t.date >= ?', 't.date <= ?'];
    whereArgs.add('$year-01-01');
    whereArgs.add('$year-12-31');

    String joinClause = '';
    if (tagId != null) {
      joinClause += ' JOIN transaction_tags tt ON tt.transaction_id = t.id AND tt.tag_id = ?';
      whereArgs.add(tagId);
    }

    if (assetId != null) {
      conditions.add('t.asset_id = ?');
      whereArgs.add(assetId);
    }

    final where = conditions.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT CAST(substr(t.date, 6, 2) AS INTEGER) AS m,
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) AS inc,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS exp
      FROM transactions t $joinClause
      WHERE $where
      GROUP BY m
    ''', whereArgs);
    return {
      for (final r in rows)
        r['m'] as int: Totals(r['inc'] as int, r['exp'] as int),
    };
  }

  // -------------------------------------------------------------- statistik

  Future<List<CategoryStat>> categoryStats(
    String type,
    DateTime from,
    DateTime to, {
    int? assetId,
    int? tagId,
  }) async {
    final db = await _d.db;
    final whereArgs = <Object?>[];
    final conditions = <String>['t.type = ?', 't.date >= ?', 't.date <= ?'];
    whereArgs.add(type);
    whereArgs.add(ymd(from));
    whereArgs.add(ymd(to));

    String joinClause = '';
    if (tagId != null) {
      joinClause += ' JOIN transaction_tags tt ON tt.transaction_id = t.id AND tt.tag_id = ?';
      whereArgs.add(tagId);
    }

    if (assetId != null) {
      conditions.add('t.asset_id = ?');
      whereArgs.add(assetId);
    }

    final where = conditions.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT c.id AS id, c.name AS name, c.type AS type, c.color AS color,
             SUM(t.amount) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      $joinClause
      WHERE $where
      GROUP BY c.id
      ORDER BY total DESC
    ''', whereArgs);
    return rows
        .map((r) => CategoryStat(Category.fromMap(r), r['total'] as int))
        .toList();
  }

  // ------------------------------------------------------------------- aset

  /// Saldo tiap aset = saldo awal + pendapatan - pengeluaran - transfer keluar
  /// + transfer masuk. Bila [upTo] diisi, hanya transaksi sampai tanggal itu.
  Future<List<AssetBalance>> assetBalances({DateTime? upTo}) async {
    final db = await _d.db;
    final dateSql = upTo == null ? '' : ' AND date <= ?';
    final dateArgs = upTo == null ? <Object?>[] : <Object?>[ymd(upTo)];
    final rows = await db.rawQuery('''
      SELECT a.*,
        a.initial_balance
        + COALESCE((SELECT SUM(amount) FROM transactions
                    WHERE asset_id = a.id AND type = 'income'$dateSql), 0)
        - COALESCE((SELECT SUM(amount) FROM transactions
                    WHERE asset_id = a.id AND type IN ('expense', 'transfer')$dateSql), 0)
        + COALESCE((SELECT SUM(amount) FROM transactions
                    WHERE to_asset_id = a.id AND type = 'transfer'$dateSql), 0) AS balance
      FROM assets a
      WHERE a.archived = 0
      ORDER BY a.id
    ''', [...dateArgs, ...dateArgs, ...dateArgs]);
    return rows
        .map((r) => AssetBalance(Asset.fromMap(r), r['balance'] as int))
        .toList();
  }

  // ------------------------------------------------------------- tutup buku

  Future<Set<String>> closedPeriods() async {
    final db = await _d.db;
    final rows = await db.query('closings', orderBy: 'period DESC');
    return rows.map((r) => r['period'] as String).toSet();
  }

  Future<void> closePeriod(String period) async {
    final db = await _d.db;
    await db.insert('closings', {
      'period': period,
      'closed_at': DateTime.now().toIso8601String(),
    });
    _changed();
  }

  Future<void> reopenPeriod(String period) async {
    final db = await _d.db;
    await db.delete('closings', where: 'period = ?', whereArgs: [period]);
    _changed();
  }

  // ------------------------------------------------------------------- memo

  Future<List<Memo>> memos() async {
    final db = await _d.db;
    final rows = await db.query('memos', orderBy: 'created_at DESC, id DESC');
    return rows.map(Memo.fromMap).toList();
  }

  Future<void> addMemo(String content) async {
    final db = await _d.db;
    await db.insert('memos', {
      'content': content.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    _changed();
  }

  Future<void> updateMemo(int id, String content) async {
    final db = await _d.db;
    await db.update('memos', {'content': content.trim()},
        where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> deleteMemo(int id) async {
    final db = await _d.db;
    await db.delete('memos', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  // --------------------------------------------------------------- anggaran

  /// Menetapkan atau memperbarui batas anggaran kategori pada periode tertentu ("yyyy-MM").
  Future<void> setBudget({
    required int categoryId,
    required int amount,
    required String period,
  }) async {
    final db = await _d.db;
    await db.insert(
      'budgets',
      {
        'category_id': categoryId,
        'amount': amount,
        'period': period,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changed();
  }

  /// Menghapus anggaran suatu kategori pada periode tertentu.
  Future<void> deleteBudget(int categoryId, String period) async {
    final db = await _d.db;
    await db.delete(
      'budgets',
      where: 'category_id = ? AND period = ?',
      whereArgs: [categoryId, period],
    );
    _changed();
  }

  /// Menyalin seluruh anggaran dari satu periode ke periode lainnya.
  Future<int> copyBudgets(String fromPeriod, String toPeriod) async {
    final db = await _d.db;
    final sourceBudgets = await db.query(
      'budgets',
      where: 'period = ?',
      whereArgs: [fromPeriod],
    );
    if (sourceBudgets.isEmpty) return 0;

    await db.transaction((txn) async {
      for (final b in sourceBudgets) {
        await txn.insert(
          'budgets',
          {
            'category_id': b['category_id'],
            'amount': b['amount'],
            'period': toPeriod,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _changed();
    return sourceBudgets.length;
  }

  /// Mendapatkan ringkasan anggaran bulanan (total anggaran, realisasi pengeluaran, sisa).
  Future<MonthlyBudgetSummary> monthlyBudgetSummary(String period) async {
    final db = await _d.db;
    final firstDay = parseYmd('$period-01');
    final from = firstOfMonth(firstDay);
    final to = lastOfMonth(firstDay);

    // 1. Ambil seluruh kategori pengeluaran
    final cats = await categories('expense');

    // 2. Ambil anggaran untuk periode ini
    final budgetRows = await db.query(
      'budgets',
      where: 'period = ?',
      whereArgs: [period],
    );
    final budgetMap = <int, int>{};
    for (final r in budgetRows) {
      budgetMap[r['category_id'] as int] = r['amount'] as int;
    }

    // 3. Ambil pengeluaran aktual per kategori pada bulan ini
    final spentRows = await db.rawQuery('''
      SELECT category_id, SUM(amount) AS total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date <= ? AND category_id IS NOT NULL
      GROUP BY category_id
    ''', [ymd(from), ymd(to)]);

    final spentMap = <int, int>{};
    for (final r in spentRows) {
      spentMap[r['category_id'] as int] = r['total'] as int;
    }

    // 4. Bangun list CategoryBudget
    final items = <CategoryBudget>[];
    var totalBudget = 0;
    var totalSpent = 0;

    for (final cat in cats) {
      final bAmount = budgetMap[cat.id];
      final sAmount = spentMap[cat.id] ?? 0;

      // Hanya masukkan yang memiliki anggaran atau memiliki pengeluaran
      if (bAmount != null) {
        totalBudget += bAmount;
        totalSpent += sAmount;
        items.add(CategoryBudget(
          category: cat,
          budgetAmount: bAmount,
          spentAmount: sAmount,
          period: period,
        ));
      }
    }

    // Urutkan: yang overbudget di atas, lalu berdasarkan persentase terpakai tertinggi
    items.sort((a, b) {
      if (a.isOverBudget && !b.isOverBudget) return -1;
      if (!a.isOverBudget && b.isOverBudget) return 1;
      return b.progress.compareTo(a.progress);
    });

    return MonthlyBudgetSummary(
      period: period,
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      items: items,
    );
  }

  // ------------------------------------------------ recurring transactions
  Future<List<RecurringTx>> recurringList({bool? activeOnly}) async {
    final db = await _d.db;
    final where = activeOnly == true ? 'WHERE r.is_active = 1' : '';
    final rows = await db.rawQuery('''
      SELECT r.*,
             c.name AS category_name, c.color AS category_color,
             a.name AS asset_name,
             ta.name AS to_asset_name
      FROM recurring_transactions r
      LEFT JOIN categories c ON c.id = r.category_id
      LEFT JOIN assets a ON a.id = r.asset_id
      LEFT JOIN assets ta ON ta.id = r.to_asset_id
      $where
      ORDER BY r.next_due_date ASC, r.id DESC
    ''');
    return rows.map(RecurringTx.fromMap).toList();
  }

  Future<int> insertRecurring({
    required String title,
    required String type,
    required int amount,
    int? categoryId,
    required int assetId,
    int? toAssetId,
    String frequency = 'monthly',
    int interval = 1,
    int dueDay = 1,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool autoRecord = false,
    bool isActive = true,
    String note = '',
  }) async {
    final db = await _d.db;
    final id = await db.insert('recurring_transactions', {
      'title': title,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'asset_id': assetId,
      'to_asset_id': toAssetId,
      'frequency': frequency,
      'interval': interval,
      'due_day': dueDay,
      'start_date': ymd(startDate),
      'next_due_date': ymd(nextDueDate),
      'auto_record': autoRecord ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'note': note,
    });
    _changed();
    return id;
  }

  Future<void> updateRecurring({
    required int id,
    required String title,
    required String type,
    required int amount,
    int? categoryId,
    required int assetId,
    int? toAssetId,
    String frequency = 'monthly',
    int interval = 1,
    int dueDay = 1,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool autoRecord = false,
    bool isActive = true,
    String note = '',
  }) async {
    final db = await _d.db;
    await db.update(
      'recurring_transactions',
      {
        'title': title,
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'asset_id': assetId,
        'to_asset_id': toAssetId,
        'frequency': frequency,
        'interval': interval,
        'due_day': dueDay,
        'start_date': ymd(startDate),
        'next_due_date': ymd(nextDueDate),
        'auto_record': autoRecord ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  Future<void> deleteRecurring(int id) async {
    final db = await _d.db;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> toggleRecurringActive(int id, bool isActive) async {
    final db = await _d.db;
    await db.update(
      'recurring_transactions',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// Catat transaksi berulang / bayar tagihan sekarang
  Future<int> recordRecurringTx(RecurringTx item, {DateTime? recordDate}) async {
    final actualDate = recordDate ?? DateTime.now();
    final note = item.note.isNotEmpty
        ? item.note
        : 'Tagihan rutin: ${item.title}';

    // 1. Masukkan ke transaksi
    final txId = await addTransaction(TxInput(
      type: item.type,
      date: actualDate,
      amount: item.amount,
      categoryId: item.categoryId,
      assetId: item.assetId,
      toAssetId: item.toAssetId,
      note: note,
      description: item.title,
      tagIds: const [],
    ));

    // 2. Hitung tanggal jatuh tempo berikutnya
    final nextDue = computeNextDueDate(
      item.nextDueDate,
      item.frequency,
      item.interval,
      item.dueDay,
    );

    // 3. Perbarui recurring item
    final db = await _d.db;
    await db.update(
      'recurring_transactions',
      {
        'last_processed_date': ymd(actualDate),
        'next_due_date': ymd(nextDue),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );

    _changed();
    return txId;
  }

  /// Memproses transaksi rutin yang disetel otomatis dan sudah jatuh tempo
  Future<int> processDueAutoRecurring() async {
    final today = ymd(DateTime.now());
    final db = await _d.db;
    final rows = await db.rawQuery('''
      SELECT r.*,
             c.name AS category_name, c.color AS category_color,
             a.name AS asset_name,
             ta.name AS to_asset_name
      FROM recurring_transactions r
      LEFT JOIN categories c ON c.id = r.category_id
      LEFT JOIN assets a ON a.id = r.asset_id
      LEFT JOIN assets ta ON ta.id = r.to_asset_id
      WHERE r.is_active = 1 AND r.auto_record = 1 AND r.next_due_date <= ?
    ''', [today]);

    if (rows.isEmpty) return 0;

    int count = 0;
    for (final r in rows) {
      final item = RecurringTx.fromMap(r);
      await recordRecurringTx(item, recordDate: item.nextDueDate);
      count++;
    }
    return count;
  }

  /// Tagihan yang sudah atau segera jatuh tempo (dalam 3 hari)
  Future<List<RecurringTx>> getDueOrUpcomingReminders() async {
    final list = await recurringList(activeOnly: true);
    return list.where((item) => item.isOverdue || item.isDueToday || item.daysUntilDue <= 3).toList();
  }

  // =========================================================================
  // MODUL TARGET MENABUNG (SAVINGS GOALS)
  // =========================================================================

  /// Mengambil daftar seluruh target menabung
  Future<List<SavingsGoal>> savingsGoals({String? status}) async {
    final db = await _d.db;
    final where = status == null ? null : 'g.status = ?';
    final whereArgs = status == null ? null : [status];
    final rows = await db.rawQuery('''
      SELECT g.*, a.name AS asset_name
      FROM savings_goals g
      LEFT JOIN assets a ON a.id = g.asset_id
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY 
        CASE WHEN g.status = 'active' THEN 0 ELSE 1 END,
        CASE WHEN g.target_date IS NULL THEN 1 ELSE 0 END,
        g.target_date ASC,
        g.id DESC
    ''', whereArgs);
    return rows.map(SavingsGoal.fromMap).toList();
  }

  /// Ringkasan total target menabung
  Future<({int totalTarget, int totalSaved, int activeCount, int completedCount})> savingsGoalsSummary() async {
    final goals = await savingsGoals();
    var totalTarget = 0;
    var totalSaved = 0;
    var activeCount = 0;
    var completedCount = 0;

    for (final g in goals) {
      if (g.status == 'active') {
        activeCount++;
        totalTarget += g.targetAmount;
        totalSaved += g.currentAmount;
      } else if (g.status == 'completed') {
        completedCount++;
        totalTarget += g.targetAmount;
        totalSaved += g.currentAmount;
      }
    }
    return (
      totalTarget: totalTarget,
      totalSaved: totalSaved,
      activeCount: activeCount,
      completedCount: completedCount,
    );
  }

  /// Mengambil data target berdasarkan ID
  Future<SavingsGoal?> getSavingsGoal(int id) async {
    final db = await _d.db;
    final rows = await db.rawQuery('''
      SELECT g.*, a.name AS asset_name
      FROM savings_goals g
      LEFT JOIN assets a ON a.id = g.asset_id
      WHERE g.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
  }

  /// Membuat target baru
  Future<int> addSavingsGoal({
    required String title,
    required int targetAmount,
    int initialAmount = 0,
    DateTime? targetDate,
    int color = 0xFF00897B,
    String icon = 'flag',
    int? assetId,
    String note = '',
    bool createInitialTransaction = false,
  }) async {
    final db = await _d.db;
    final now = DateTime.now();
    final goalId = await db.insert('savings_goals', {
      'title': title.trim(),
      'target_amount': targetAmount,
      'current_amount': initialAmount,
      'target_date': targetDate != null ? ymd(targetDate) : null,
      'color': color,
      'icon': icon,
      'status': (initialAmount >= targetAmount && targetAmount > 0) ? 'completed' : 'active',
      'asset_id': assetId,
      'note': note.trim(),
      'created_at': now.toIso8601String(),
    });

    if (initialAmount > 0) {
      int? txId;
      if (createInitialTransaction && assetId != null) {
        txId = await _recordSavingsTransaction(
          assetId: assetId,
          amount: initialAmount,
          isDeposit: true,
          goalTitle: title.trim(),
          date: now,
          note: 'Setoran Awal Target',
        );
      }
      await db.insert('goal_allocations', {
        'goal_id': goalId,
        'asset_id': assetId,
        'amount': initialAmount,
        'date': ymd(now),
        'note': 'Setoran Awal Target',
        'tx_id': txId,
      });
    }

    _changed();
    return goalId;
  }

  /// Memperbarui informasi target
  Future<void> updateSavingsGoal(
    int id, {
    required String title,
    required int targetAmount,
    DateTime? targetDate,
    int? color,
    String? icon,
    int? assetId,
    String? note,
    String? status,
  }) async {
    final db = await _d.db;
    final current = await getSavingsGoal(id);
    if (current == null) return;

    final newStatus = status ??
        ((current.currentAmount >= targetAmount && targetAmount > 0)
            ? 'completed'
            : current.status);

    await db.update(
      'savings_goals',
      {
        'title': title.trim(),
        'target_amount': targetAmount,
        'target_date': targetDate != null ? ymd(targetDate) : null,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        'asset_id': assetId,
        if (note != null) 'note': note.trim(),
        'status': newStatus,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// Menghapus target
  Future<void> deleteSavingsGoal(int id) async {
    final db = await _d.db;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// Mengubah status target (active, completed, cancelled)
  Future<void> updateGoalStatus(int id, String status) async {
    final db = await _d.db;
    await db.update('savings_goals', {'status': status}, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// Memperpanjang batas waktu target (deadline)
  Future<void> extendGoalDeadline(int id, DateTime newDeadline) async {
    final db = await _d.db;
    await db.update(
      'savings_goals',
      {
        'target_date': ymd(newDeadline),
        'status': 'active',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// Mencatat transaksi mutasi tabungan di buku kas
  Future<int?> _recordSavingsTransaction({
    required int assetId,
    required int amount,
    required bool isDeposit,
    required String goalTitle,
    DateTime? date,
    String note = '',
  }) async {
    final txDate = date ?? DateTime.now();
    const catName = 'Tabungan / Investasi';
    final catType = isDeposit ? 'expense' : 'income';
    final catId = await addCategory(catName, catType);
    final txNote = isDeposit
        ? 'Menabung ke "$goalTitle"${note.isNotEmpty ? ": $note" : ""}'
        : 'Tarik dari "$goalTitle"${note.isNotEmpty ? ": $note" : ""}';
    return await addTransaction(TxInput(
      type: catType,
      date: txDate,
      amount: amount,
      categoryId: catId,
      assetId: assetId,
      toAssetId: null,
      note: txNote,
      description: 'Mutasi Tabungan Target Finku',
      tagIds: const [],
    ));
  }

  /// Menabung / Alokasi dana ke target
  Future<void> allocateToGoal({
    required int goalId,
    required int amount,
    int? assetId,
    String note = '',
    bool createTransaction = false,
    DateTime? date,
  }) async {
    if (amount <= 0) return;
    final db = await _d.db;
    final goal = await getSavingsGoal(goalId);
    if (goal == null) return;

    final txDate = date ?? DateTime.now();
    int? txId;
    if (createTransaction && assetId != null) {
      txId = await _recordSavingsTransaction(
        assetId: assetId,
        amount: amount,
        isDeposit: true,
        goalTitle: goal.title,
        date: txDate,
        note: note,
      );
    }

    await db.insert('goal_allocations', {
      'goal_id': goalId,
      'asset_id': assetId,
      'amount': amount,
      'date': ymd(txDate),
      'note': note.trim().isEmpty ? 'Menabung' : note.trim(),
      'tx_id': txId,
    });

    final newAmount = goal.currentAmount + amount;
    final isDone = newAmount >= goal.targetAmount && goal.targetAmount > 0;
    await db.update(
      'savings_goals',
      {
        'current_amount': newAmount,
        if (isDone) 'status': 'completed',
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );

    _changed();
  }

  /// Menarik dana dari target
  Future<void> withdrawFromGoal({
    required int goalId,
    required int amount,
    int? assetId,
    String note = '',
    bool createTransaction = false,
    DateTime? date,
  }) async {
    if (amount <= 0) return;
    final db = await _d.db;
    final goal = await getSavingsGoal(goalId);
    if (goal == null) return;

    final actualAmount = amount.clamp(0, goal.currentAmount);
    if (actualAmount <= 0) return;

    final txDate = date ?? DateTime.now();
    int? txId;
    if (createTransaction && assetId != null) {
      txId = await _recordSavingsTransaction(
        assetId: assetId,
        amount: actualAmount,
        isDeposit: false,
        goalTitle: goal.title,
        date: txDate,
        note: note,
      );
    }

    await db.insert('goal_allocations', {
      'goal_id': goalId,
      'asset_id': assetId,
      'amount': -actualAmount,
      'date': ymd(txDate),
      'note': note.trim().isEmpty ? 'Penarikan Dana' : note.trim(),
      'tx_id': txId,
    });

    final newAmount = goal.currentAmount - actualAmount;
    await db.update(
      'savings_goals',
      {
        'current_amount': newAmount,
        if (goal.status == 'completed' && newAmount < goal.targetAmount) 'status': 'active',
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );

    _changed();
  }

  /// Memindahkan saldo antar target menabung
  Future<void> transferBetweenGoals({
    required int fromGoalId,
    required int toGoalId,
    required int amount,
    String note = '',
  }) async {
    if (amount <= 0 || fromGoalId == toGoalId) return;
    final db = await _d.db;
    final fromGoal = await getSavingsGoal(fromGoalId);
    final toGoal = await getSavingsGoal(toGoalId);
    if (fromGoal == null || toGoal == null) return;

    final actualAmount = amount.clamp(0, fromGoal.currentAmount);
    if (actualAmount <= 0) return;

    final now = DateTime.now();
    final today = ymd(now);

    // Pengurangan dari fromGoal
    await db.insert('goal_allocations', {
      'goal_id': fromGoalId,
      'amount': -actualAmount,
      'date': today,
      'note': 'Dipindah ke target "${toGoal.title}"${note.isNotEmpty ? ": $note" : ""}',
    });
    final newFromAmount = fromGoal.currentAmount - actualAmount;
    await db.update(
      'savings_goals',
      {
        'current_amount': newFromAmount,
        if (fromGoal.status == 'completed' && newFromAmount < fromGoal.targetAmount)
          'status': 'active',
      },
      where: 'id = ?',
      whereArgs: [fromGoalId],
    );

    // Penambahan ke toGoal
    await db.insert('goal_allocations', {
      'goal_id': toGoalId,
      'amount': actualAmount,
      'date': today,
      'note': 'Diterima dari target "${fromGoal.title}"${note.isNotEmpty ? ": $note" : ""}',
    });
    final newToAmount = toGoal.currentAmount + actualAmount;
    final isToDone = newToAmount >= toGoal.targetAmount && toGoal.targetAmount > 0;
    await db.update(
      'savings_goals',
      {
        'current_amount': newToAmount,
        if (isToDone) 'status': 'completed',
      },
      where: 'id = ?',
      whereArgs: [toGoalId],
    );

    _changed();
  }

  /// Mengambil seluruh riwayat alokasi dana untuk suatu target
  Future<List<GoalAllocation>> goalAllocations(int goalId) async {
    final db = await _d.db;
    final rows = await db.rawQuery('''
      SELECT ga.*, a.name AS asset_name
      FROM goal_allocations ga
      LEFT JOIN assets a ON a.id = ga.asset_id
      WHERE ga.goal_id = ?
      ORDER BY ga.date DESC, ga.id DESC
    ''', [goalId]);
    return rows.map(GoalAllocation.fromMap).toList();
  }
}
