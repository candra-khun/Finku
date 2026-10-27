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
