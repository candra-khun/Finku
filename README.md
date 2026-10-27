# Finku (Financial-ku) — Manajer Keuangan Pribadi

<p align="center">
  <img src="assets/images/logo.png" alt="Finku Logo" width="120" height="120" />
</p>

<p align="center">
  <strong>Aplikasi Pencatat & Pengelola Keuangan Pribadi Cerdas, Aman, dan 100% Offline (Local SQLite).</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.4+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/License-Proprietary-blue.svg" alt="License" />
</p>

---

## 📌 Tentang Finku

**Finku** (*Financial-ku*) adalah aplikasi manajer keuangan pribadi berbasis Flutter yang dirancang untuk membantu pencatatan arus kas harian, perencanaan anggaran bulanan, pemantauan saldo aset/rekening, serta analisis statistik pengeluaran secara akurat dan mudah. Seluruh data tersimpan secara lokal di perangkat Anda (tanpa perlu server luar) sehingga privasi keuangan Anda terjamin.

---

## ✨ Fitur Utama

### 1. 📝 Kelola Transaksi (Arus Kas)
- **Multi Tampilan**: Pantau catatan transaksi secara **Harian**, **Kalender**, **Bulanan**, maupun catatan khusus **Memo**.
- **Pencarian & Filter Cepat**: Temukan transaksi berdasarkan kata kunci catatan/kategori secara instan.
- **Pemisah Ribuan Otomatis**: Input nominal dengan format Rupiah yang nyaman dan rapi tanpa ribet mengetik titik atau koma manual.
- **Duplikasi Transaksi**: Salin transaksi berulang dengan satu ketukan.
- **Transfer Antarakun**: Catat perpindahan dana antar rekening/aset secara akurat.
- **Tutup Buku Bulanan**: Kunci catatan keuangan periode lalu agar tidak berubah tanpa sengaja.

### 2. 📊 Statistik & Grafik Finansial
- **Diagram Lingkaran Interaktif (Pie Chart)**: Visualisasi proporsi pengeluaran dan pemasukan per kategori beserta persentase kontribusinya.
- **Grafik Tren Bulanan**: Bar chart komparasi 12 bulan (Januari–Desember) untuk melihat tren pengeluaran vs pemasukan tahunan.
- **Filter Statistik Mendalam**: Analisis pengeluaran yang dapat difilter per **Akun Aset** atau per **Tag** tertentu.

### 3. 🎯 Anggaran per Kategori (Budgeting)
- Tetapkan batas anggaran pengeluaran bulanan per kategori (misal: *Makanan Rp 2.000.000/bulan*).
- Indikator progres visual interaktif: persentase pemakaian, sisa anggaran riil, serta tanda bahaya ketika mendekati atau melebihi batas (*overbudget*).

### 4. 🎯 Target Menabung (Savings Goals)
- **Kumpulkan Dana Impian**: Rencanakan tujuan menabung spesifik (contoh: *Beli Laptop Rp 5.000.000*, *Dana Darurat Rp 10.000.000*, *Target Tabungan Bulan Ini Rp 2.000.000*).
- **Progres Visual & Deadline**: Batang kemajuan (*progress bar*) otomatis, persentase ketercapaian, sisa kekurangan dana, dan sisa hari menuju batas waktu (*deadline*).
- **Pilihan Batas Waktu Cerdas**: Saat deadline berakhir sebelum 100% tercapai, pengguna dapat memperpanjang waktu, menutup/menyelesaikan target dengan nominal saat ini, atau memindahkan sisa saldo ke target lain.
- **Alokasi Dana Terintegrasi**: Setor dana langsung dari akun aset (dengan opsi memotong saldo arus kas atau alokasi virtual), tarik dana, maupun transfer saldo antar-target tanpa perlu mencatat ganda.

### 5. 🔁 Transaksi Berulang & Pengingat Tagihan
- Jadwalkan pembayaran rutin (Harian, Mingguan, Bulanan, Tahunan) untuk sewa, langganan, internet, listrik, gaji, dll.
- Opsi otomatisasi pencatatan saat jatuh tempo tiba dan pengingat tagihan aktif.

### 6. 💼 Pengelompokan & Manajemen Akun Aset
- Tab terpadu di menu Aset: **Daftar Aset** dan **Target Menabung**.
- Kelompokkan aset keuangan: Kas/Tunai, Rekening Bank, Dompet Digital (*E-Wallet*), Kartu Kredit, hingga Investasi.
- Urutkan dan kelola master data **Kategori** (pemasukan/pengeluaran) serta **Tag** transaksi sesuai kebutuhan pribadi Anda.

### 7. 🔒 Keamanan & Privasi
- **Kunci Aplikasi dengan PIN 6 Digit**: Dilengkapi enkripsi *hashing* SHA-256 + *cryptographic salt*.
- **Autentikasi Biometrik**: Buka kunci dengan cepat menggunakan Sidik Jari (*Fingerprint*) atau Pemindai Wajah (*Face ID*).
- **Auto-Lock Timeout**: Pengaturan penguncian otomatis (Langsung saat keluar, 1 menit, atau 5 menit).

### 8. 💾 Cadangkan & Pulihkan Data (Backup & Restore)
- **Ekspor & Impor Database**: Buat salinan cadangan berkas `.ksbackup` (JSON) untuk dipindahkan ke perangkat baru.
- **Ekspor Laporan Spreadsheet (CSV)**: Unduh seluruh riwayat transaksi untuk dibuka di Microsoft Excel atau Google Sheets.

---

## 📱 Tangkapan Layar Navigasi

Finku terbagi ke dalam 4 modul utama pada menu navigasi bawah (*Bottom Navigation Bar*):
1. **Transaksi**: Arus kas harian, kalender transaksi, ringkasan per bulan, dan entri transaksi.
2. **Statistik**: Diagram lingkaran pengeluaran, rincian kategori, filter aset/tag, dan tren bulanan.
3. **Aset**: Daftar akun rekening, dompet digital, aset utama, dan total kekayaan bersih.
4. **Lainnya**: Akses menu Anggaran Kategori, Transaksi Rutin, Kelola Master Kategori & Tag, Keamanan PIN/Biometrik, serta Backup & Restore.

---

## 🛠️ Struktur Proyek

```text
lib/
├── main.dart                 # Titik masuk utama, SecurityGuard, tema, & Bottom Navigation
├── core/
│   ├── format.dart           # Pemformatan Rupiah, ribuan, & tanggal lokal Indonesia
│   ├── security_service.dart # Service keamanan PIN (SHA-256+salt), biometrik, & lifecycle
│   ├── widgets.dart          # Komponen UI bersama (kartu, tombol, indikator)
│   └── dialogs.dart          # Dialog konfirmasi dan form cepat
├── data/
│   ├── database.dart         # Konfigurasi SQLite, migrasi skema tabel, & indeks
│   ├── models.dart           # Model transaksi, kategori, aset, tag, anggaran, rutin
│   ├── repository.dart       # State management & logika akses data (Provider)
│   └── backup_service.dart   # Logika ekspor/impor JSON database & CSV spreadsheet
└── features/
    ├── transaksi/            # Tab Transaksi (harian, kalender, bulanan, form tx, pencarian)
    ├── statistik/            # Tab Statistik (pie chart, bar chart tren 12 bulan, filter aset/tag)
    ├── aset/                 # Tab Aset (saldo akun, mutasi aset, grup rekening)
    ├── anggaran/             # Fitur Anggaran Bulanan per Kategori
    ├── berulang/             # Fitur Transaksi Berulang & Pengingat Tagihan
    ├── keamanan/             # Halaman Kunci (LockScreen), Setup PIN, & Pengaturan Keamanan
    ├── kategori/             # Kelola Kategori, Tag, dan Aset
    └── lainnya/              # Tab Pengaturan & Menu Tambahan
```

---

## 🚀 Memulai (Instalasi & Pengujian)

### Prasyarat
- Flutter SDK versi `3.22.0` atau yang lebih baru
- Android Studio / VS Code dengan Android SDK terpasang

### Menjalankan di Mode Pengembangan
---

## 📌 Tentang Finku

**Finku** (*Financial-ku*) adalah aplikasi manajer keuangan pribadi berbasis Flutter yang dirancang untuk membantu pencatatan arus kas harian, perencanaan anggaran bulanan, pemantauan saldo aset/rekening, serta analisis statistik pengeluaran secara akurat dan mudah. Seluruh data tersimpan secara lokal di perangkat Anda (tanpa perlu server luar) sehingga privasi keuangan Anda terjamin 100%.

---

## ✨ Fitur Utama

### 1. 📝 Kelola Transaksi (Arus Kas)
- **Multi Tampilan**: Pantau catatan transaksi secara **Harian**, **Kalender**, **Bulanan**, maupun catatan khusus **Memo**.
- **Pencarian & Filter Cepat**: Temukan transaksi berdasarkan kata kunci catatan/kategori secara instan.
- **Pemisah Ribuan Otomatis**: Input nominal dengan format Rupiah yang nyaman dan rapi tanpa ribet mengetik titik atau koma manual.
- **Duplikasi Transaksi**: Salin transaksi berulang dengan satu ketukan.
- **Transfer Antarakun**: Catat perpindahan dana antar rekening/aset secara akurat.
- **Tutup Buku Bulanan**: Kunci catatan keuangan periode lalu agar tidak berubah tanpa sengaja.

### 2. 📊 Statistik & Grafik Finansial
- **Diagram Lingkaran Interaktif (Pie Chart)**: Visualisasi proporsi pengeluaran dan pemasukan per kategori beserta persentase kontribusinya.
- **Grafik Tren Bulanan**: Bar chart komparasi 12 bulan (Januari–Desember) untuk melihat tren pengeluaran vs pemasukan tahunan.
- **Filter Statistik Mendalam**: Analisis pengeluaran yang dapat difilter per **Akun Aset** atau per **Tag** tertentu.

### 3. 🎯 Anggaran per Kategori (Budgeting)
- Tetapkan batas anggaran pengeluaran bulanan per kategori (misal: *Makanan Rp 2.000.000/bulan*).
- Indikator progres visual interaktif: persentase pemakaian, sisa anggaran riil, serta tanda bahaya ketika mendekati atau melebihi batas (*overbudget*).

### 4. 🎯 Target Menabung (Savings Goals)
- **Kumpulkan Dana Impian**: Rencanakan tujuan menabung spesifik (contoh: *Beli Laptop Rp 5.000.000*, *Dana Darurat Rp 10.000.000*, *Target Tabungan Bulan Ini Rp 2.000.000*).
- **Progres Visual & Deadline**: Batang kemajuan (*progress bar*) otomatis, persentase ketercapaian, sisa kekurangan dana, dan sisa hari menuju batas waktu (*deadline*).
- **Pilihan Batas Waktu Cerdas**: Saat deadline berakhir sebelum 100% tercapai, pengguna dapat memperpanjang waktu, menutup/menyelesaikan target dengan nominal saat ini, atau memindahkan sisa saldo ke target lain.
- **Alokasi Dana Terintegrasi**: Setor dana langsung dari akun aset (dengan opsi memotong saldo arus kas atau alokasi virtual), tarik dana, maupun transfer saldo antar-target tanpa perlu mencatat ganda.

### 5. 🔁 Transaksi Berulang & Pengingat Tagihan
- Jadwalkan pembayaran rutin (Harian, Mingguan, Bulanan, Tahunan) untuk sewa, langganan, internet, listrik, gaji, dll.
- Opsi otomatisasi pencatatan saat jatuh tempo tiba dan pengingat tagihan aktif.

### 6. 💼 Pengelompokan & Manajemen Akun Aset
- Tab terpadu di menu Aset: **Daftar Aset** dan **Target Menabung**.
- Kelompokkan aset keuangan: Kas/Tunai, Rekening Bank, Dompet Digital (*E-Wallet*), Kartu Kredit, hingga Investasi.
- Urutkan dan kelola master data **Kategori** (pemasukan/pengeluaran) serta **Tag** transaksi sesuai kebutuhan pribadi Anda.

### 7. 🔒 Keamanan & Privasi
- **Kunci Aplikasi dengan PIN 6 Digit**: Dilengkapi enkripsi *hashing* SHA-256 + *cryptographic salt*.
- **Autentikasi Biometrik**: Buka kunci dengan cepat menggunakan Sidik Jari (*Fingerprint*) atau Pemindai Wajah (*Face ID*).
- **Auto-Lock Timeout**: Pengaturan penguncian otomatis (Langsung saat keluar, 1 menit, atau 5 menit).

### 8. 💾 Cadangkan & Pulihkan Data (Backup & Restore)
- **Ekspor & Impor Database**: Buat salinan cadangan berkas `.ksbackup` (JSON) untuk dipindahkan ke perangkat baru.
- **Ekspor Laporan Spreadsheet (CSV)**: Unduh seluruh riwayat transaksi untuk dibuka di Microsoft Excel atau Google Sheets.

---

## 📱 Tangkapan Layar Navigasi

Finku terbagi ke dalam 4 modul utama pada menu navigasi bawah (*Bottom Navigation Bar*):
1. **Transaksi**: Arus kas harian, kalender transaksi, ringkasan per bulan, dan entri transaksi.
2. **Statistik**: Diagram lingkaran pengeluaran, rincian kategori, filter aset/tag, dan tren bulanan.
3. **Aset**: Daftar akun rekening, dompet digital, aset utama, dan total kekayaan bersih.
4. **Lainnya**: Akses menu Anggaran Kategori, Transaksi Rutin, Kelola Master Kategori & Tag, Keamanan PIN/Biometrik, serta Backup & Restore.

---

## 🛠️ Struktur Proyek

```text
lib/
├── main.dart                 # Titik masuk utama, SecurityGuard, tema, & Bottom Navigation
├── core/
│   ├── format.dart           # Pemformatan Rupiah, ribuan, & tanggal lokal Indonesia
│   ├── security_service.dart # Service keamanan PIN (SHA-256+salt), biometrik, & lifecycle
│   ├── widgets.dart          # Komponen UI bersama (kartu, tombol, indikator)
│   └── dialogs.dart          # Dialog konfirmasi dan form cepat
├── data/
│   ├── database.dart         # Konfigurasi SQLite, migrasi skema tabel, & indeks
│   ├── models.dart           # Model transaksi, kategori, aset, tag, anggaran, rutin
│   ├── repository.dart       # State management & logika akses data (Provider)
│   └── backup_service.dart   # Logika ekspor/impor JSON database & CSV spreadsheet
└── features/
    ├── transaksi/            # Tab Transaksi (harian, kalender, bulanan, form tx, pencarian)
    ├── statistik/            # Tab Statistik (pie chart, bar chart tren 12 bulan, filter aset/tag)
    ├── aset/                 # Tab Aset (saldo akun, mutasi aset, grup rekening)
    ├── anggaran/             # Fitur Anggaran Bulanan per Kategori
    ├── berulang/             # Fitur Transaksi Berulang & Pengingat Tagihan
    ├── keamanan/             # Halaman Kunci (LockScreen), Setup PIN, & Pengaturan Keamanan
    ├── kategori/             # Kelola Kategori, Tag, dan Aset
    └── lainnya/              # Tab Pengaturan & Menu Tambahan
```

---

## 🚀 Memulai (Instalasi & Pengujian)

### Prasyarat
- Flutter SDK versi `3.22.0` atau yang lebih baru
- Android Studio / VS Code dengan Android SDK terpasang

### Menjalankan di Mode Pengembangan
```bash
# Masuk ke direktori projek
cd keuangan_saku

# Unduh dependensi
flutter pub get

# Jalankan linter dan analisis kode
flutter analyze

# Jalankan unit & widget test
flutter test

# Jalankan pada emulator atau ponsel Android yang terhubung
flutter run
```

### Membuat Berkas Rilis (APK Teroptimasi & Terkompresi)

```bash
# Rekomendasi: Build APK dengan kompresi per arsitektur (Ukuran ~17 - 19 MB)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

# Hasil APK per target:
# - build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (HP Android modern 64-bit ~19.5 MB)
# - build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (HP Android 32-bit ~17 MB)

# Atau build universal fat APK (Semua arsitektur digabung ~57 MB):
flutter build apk --release
```

---

## 📦 Dependensi Utama

- [`provider`](https://pub.dev/packages/provider): Manajemen status (*state management*) reaktif
- [`sqflite`](https://pub.dev/packages/sqflite): Mesin database relasional lokal SQLite
- [`fl_chart`](https://pub.dev/packages/fl_chart): Visualisasi diagram lingkaran dan grafik batang
- [`table_calendar`](https://pub.dev/packages/table_calendar): Tampilan kalender interaktif
- [`local_auth`](https://pub.dev/packages/local_auth): Autentikasi biometrik sidik jari & wajah
- [`crypto`](https://pub.dev/packages/crypto): Hashing SHA-256 berkekuatan tinggi untuk keamanan PIN
- [`share_plus`](https://pub.dev/packages/share_plus) & [`file_picker`](https://pub.dev/packages/file_picker): Berbagi file dan pemilihan berkas cadangan

---

<p align="center">
  Dibuat dengan ❤️ untuk kemudahan pengelolaan finansial yang lebih tertata dan terencana.
</p>

---

<p align="center">
  Dibuat dengan ❤️ untuk kemudahan pengelolaan finansial yang lebih tertata dan terencana.
</p>

