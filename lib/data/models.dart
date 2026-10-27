import '../core/format.dart';

class AssetGroup {
  final int id;
  final String name;
  final bool isDefault;
  final int sort;

  const AssetGroup({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.sort,
  });

  factory AssetGroup.fromMap(Map<String, Object?> m) => AssetGroup(
        id: m['id'] as int,
        name: m['name'] as String,
        isDefault: (m['is_default'] as int) == 1,
        sort: m['sort'] as int,
      );
}

class Asset {
  final int id;
  final String name;
  final int groupId;
  final int initialBalance;
  final bool archived;

  const Asset({
    required this.id,
    required this.name,
    required this.groupId,
    required this.initialBalance,
    required this.archived,
  });

  factory Asset.fromMap(Map<String, Object?> m) => Asset(
        id: m['id'] as int,
        name: m['name'] as String,
        groupId: m['group_id'] as int,
        initialBalance: m['initial_balance'] as int,
        archived: (m['archived'] as int) == 1,
      );
}

class AssetBalance {
  final Asset asset;
  final int balance;

  const AssetBalance(this.asset, this.balance);
}

class Category {
  final int id;
  final String name;
  final String type; // income | expense
  final int color;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
  });

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        type: m['type'] as String,
        color: m['color'] as int,
      );
}

class Tag {
  final int id;
  final String name;

  const Tag({required this.id, required this.name});

  factory Tag.fromMap(Map<String, Object?> m) =>
      Tag(id: m['id'] as int, name: m['name'] as String);
}

class Memo {
  final int id;
  final String content;
  final DateTime createdAt;

  const Memo({required this.id, required this.content, required this.createdAt});

  factory Memo.fromMap(Map<String, Object?> m) => Memo(
        id: m['id'] as int,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class Totals {
  final int income;
  final int expense;

  const Totals(this.income, this.expense);

  static const Totals zero = Totals(0, 0);

  int get total => income - expense;
}

class CategoryStat {
  final Category category;
  final int total;

  const CategoryStat(this.category, this.total);
}

/// Data transaksi untuk ditampilkan (sudah digabung dengan nama kategori,
/// aset, dan tag).
class TxItem {
  final int id;
  final String type; // income | expense | transfer
  final DateTime date;
  final int amount;
  final int? categoryId;
  final String? categoryName;
  final int assetId;
  final String assetName;
  final int? toAssetId;
  final String? toAssetName;
  final String note;
  final String description;
  final List<Tag> tags;

  const TxItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.assetId,
    required this.assetName,
    required this.toAssetId,
    required this.toAssetName,
    required this.note,
    required this.description,
    required this.tags,
  });

  bool get isTransfer => type == 'transfer';

  factory TxItem.fromMap(Map<String, Object?> m, List<Tag> tags) => TxItem(
        id: m['id'] as int,
        type: m['type'] as String,
        date: parseYmd(m['date'] as String),
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int?,
        categoryName: m['cat_name'] as String?,
        assetId: m['asset_id'] as int,
        assetName: m['asset_name'] as String,
        toAssetId: m['to_asset_id'] as int?,
        toAssetName: m['to_asset_name'] as String?,
        note: (m['note'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        tags: tags,
      );
}

/// Data masukan untuk menambah/mengubah transaksi.
class TxInput {
  final String type;
  final DateTime date;
  final int amount;
  final int? categoryId;
  final int assetId;
  final int? toAssetId;
  final String note;
  final String description;
  final List<int> tagIds;

  const TxInput({
    required this.type,
    required this.date,
    required this.amount,
    required this.categoryId,
    required this.assetId,
    required this.toAssetId,
    required this.note,
    required this.description,
    required this.tagIds,
  });

  Map<String, Object?> toMap() => {
        'type': type,
        'date': ymd(date),
        'amount': amount,
        'category_id': categoryId,
        'asset_id': assetId,
        'to_asset_id': toAssetId,
        'note': note,
        'description': description,
      };
}

class Budget {
  final int id;
  final int categoryId;
  final int amount;
  final String period; // "yyyy-MM"

  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
  });

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int,
        categoryId: m['category_id'] as int,
        amount: m['amount'] as int,
        period: m['period'] as String,
      );
}

/// Anggaran per kategori yang digabung dengan realisasi pengeluaran pada periode tersebut.
class CategoryBudget {
  final Category category;
  final int budgetAmount;
  final int spentAmount;
  final String period;

  const CategoryBudget({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.period,
  });

  int get remaining => budgetAmount - spentAmount;

  double get progress =>
      budgetAmount > 0 ? (spentAmount / budgetAmount).clamp(0.0, 2.0) : 0.0;

  bool get isOverBudget => spentAmount > budgetAmount;
}

/// Ringkasan keseluruhan anggaran untuk satu bulan.
class MonthlyBudgetSummary {
  final String period;
  final int totalBudget;
  final int totalSpent;
  final List<CategoryBudget> items;

  const MonthlyBudgetSummary({
    required this.period,
    required this.totalBudget,
    required this.totalSpent,
    required this.items,
  });

  int get totalRemaining => totalBudget - totalSpent;

  double get overallProgress =>
      totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 2.0) : 0.0;

  bool get isOverBudget => totalSpent > totalBudget;
}

DateTime computeNextDueDate(DateTime fromDate, String frequency, int interval, int dueDay) {
  switch (frequency) {
    case 'daily':
      return fromDate.add(Duration(days: interval));
    case 'weekly':
      return fromDate.add(Duration(days: interval * 7));
    case 'yearly':
      final nextYear = fromDate.year + interval;
      final maxDays = DateTime(nextYear, fromDate.month + 1, 0).day;
      final day = dueDay.clamp(1, maxDays);
      return DateTime(nextYear, fromDate.month, day);
    case 'monthly':
    default:
      var newMonth = fromDate.month + interval;
      var newYear = fromDate.year;
      while (newMonth > 12) {
        newMonth -= 12;
        newYear += 1;
      }
      final maxDays = DateTime(newYear, newMonth + 1, 0).day;
      final day = dueDay.clamp(1, maxDays);
      return DateTime(newYear, newMonth, day);
  }
}

class RecurringTx {
  final int id;
  final String title;
  final String type; // 'expense', 'income', 'transfer'
  final int amount;
  final int? categoryId;
  final String? categoryName;
  final int? categoryColor;
  final int assetId;
  final String? assetName;
  final int? toAssetId;
  final String? toAssetName;
  final String frequency; // 'monthly', 'weekly', 'daily', 'yearly'
  final int interval;
  final int dueDay;
  final DateTime startDate;
  final DateTime nextDueDate;
  final DateTime? lastProcessedDate;
  final bool autoRecord;
  final bool isActive;
  final String note;

  const RecurringTx({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    required this.assetId,
    this.assetName,
    this.toAssetId,
    this.toAssetName,
    this.frequency = 'monthly',
    this.interval = 1,
    this.dueDay = 1,
    required this.startDate,
    required this.nextDueDate,
    this.lastProcessedDate,
    this.autoRecord = false,
    this.isActive = true,
    this.note = '',
  });

  bool get isDueToday {
    final now = DateTime.now();
    return nextDueDate.year == now.year &&
        nextDueDate.month == now.month &&
        nextDueDate.day == now.day;
  }

  bool get isOverdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.isBefore(today);
  }

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return interval == 1 ? 'Harian' : 'Tiap $interval hari';
      case 'weekly':
        return interval == 1 ? 'Mingguan' : 'Tiap $interval minggu';
      case 'yearly':
        return interval == 1 ? 'Tahunan' : 'Tiap $interval tahun';
      case 'monthly':
      default:
        return interval == 1 ? 'Tiap tanggal $dueDay' : 'Tiap $interval bln (tgl $dueDay)';
    }
  }

  factory RecurringTx.fromMap(Map<String, Object?> m) {
    return RecurringTx(
      id: m['id'] as int,
      title: m['title'] as String,
      type: m['type'] as String,
      amount: m['amount'] as int,
      categoryId: m['category_id'] as int?,
      categoryName: m['category_name'] as String?,
      categoryColor: m['category_color'] as int?,
      assetId: m['asset_id'] as int,
      assetName: m['asset_name'] as String?,
      toAssetId: m['to_asset_id'] as int?,
      toAssetName: m['to_asset_name'] as String?,
      frequency: (m['frequency'] as String?) ?? 'monthly',
      interval: (m['interval'] as int?) ?? 1,
      dueDay: (m['due_day'] as int?) ?? 1,
      startDate: parseYmd(m['start_date'] as String),
      nextDueDate: parseYmd(m['next_due_date'] as String),
      lastProcessedDate: m['last_processed_date'] != null
          ? parseYmd(m['last_processed_date'] as String)
          : null,
      autoRecord: (m['auto_record'] as int? ?? 0) == 1,
      isActive: (m['is_active'] as int? ?? 1) == 1,
      note: (m['note'] as String?) ?? '',
    );
  }
}
