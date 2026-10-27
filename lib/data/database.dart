import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Warna bawaan untuk kategori (dipakai berurutan pada diagram lingkaran).
const List<int> categoryPalette = [
  0xFFEF5350,
  0xFF42A5F5,
  0xFF66BB6A,
  0xFFFFA726,
  0xFFAB47BC,
  0xFF26C6DA,
  0xFFEC407A,
  0xFF8D6E63,
  0xFF9CCC65,
  0xFF5C6BC0,
  0xFFFFCA28,
  0xFF78909C,
];

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'keuangan_saku.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
    );
    // Pastikan kolom sort tersedia pada categories dan assets
    await db.execute('ALTER TABLE categories ADD COLUMN sort INTEGER NOT NULL DEFAULT 0').catchError((_) {});
    await db.execute('ALTER TABLE assets ADD COLUMN sort INTEGER NOT NULL DEFAULT 0').catchError((_) {});
    // Pastikan tabel budgets tersedia
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL,
        period TEXT NOT NULL,
        UNIQUE(category_id, period)
      )
    ''').catchError((_) {});
    return db;
  }

  Future<void> _create(Database d, int version) async {
    await d.execute('''
      CREATE TABLE asset_groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE assets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        group_id INTEGER NOT NULL REFERENCES asset_groups(id),
        initial_balance INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER REFERENCES categories(id),
        asset_id INTEGER NOT NULL REFERENCES assets(id),
        to_asset_id INTEGER REFERENCES assets(id),
        note TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await d.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await d.execute('''
      CREATE TABLE transaction_tags(
        transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (transaction_id, tag_id)
      )''');
    await d.execute('''
      CREATE TABLE memos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE closings(
        period TEXT PRIMARY KEY,
        closed_at TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL,
        period TEXT NOT NULL,
        UNIQUE(category_id, period)
      )''');

    // Data awal: tiga grup aset utama beserta satu aset di tiap grup.
    final tunai = await d.insert(
        'asset_groups', {'name': 'Tunai', 'is_default': 1, 'sort': 1});
    final bank = await d.insert(
        'asset_groups', {'name': 'Bank', 'is_default': 1, 'sort': 2});
    final kartu = await d.insert(
        'asset_groups', {'name': 'Kartu', 'is_default': 1, 'sort': 3});
    await d.insert('assets', {'name': 'Dompet', 'group_id': tunai});
    await d.insert('assets', {'name': 'Rekening Bank', 'group_id': bank});
    await d.insert('assets', {'name': 'Kartu', 'group_id': kartu});

    const expense = [
      'Makanan',
      'Transportasi',
      'Belanja',
      'Tagihan',
      'Hiburan',
      'Kesehatan',
      'Pendidikan',
      'Lainnya',
    ];
    for (var i = 0; i < expense.length; i++) {
      await d.insert('categories', {
        'name': expense[i],
        'type': 'expense',
        'color': categoryPalette[i % categoryPalette.length],
      });
    }
    const income = ['Gaji', 'Bonus', 'Hadiah', 'Lainnya'];
    for (var i = 0; i < income.length; i++) {
      await d.insert('categories', {
        'name': income[i],
        'type': 'income',
        'color': categoryPalette[i % categoryPalette.length],
      });
    }
  }
}
