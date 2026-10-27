# Keuangan Saku

Aplikasi pengelola keuangan pribadi (Flutter, Android) dengan tiga modul:
Transaksi, Statistik, dan Aset. Data tersimpan lokal di perangkat (SQLite).

## Menjalankan

Prasyarat: Flutter 3.22 atau lebih baru dan Android SDK (`flutter doctor`).

```bash
cd keuangan_saku
flutter create --project-name keuangan_saku --org com.contoh --platforms android .
flutter pub get
flutter test
flutter run
```

Perintah `flutter create .` hanya menambahkan folder `android/` yang belum ada;
berkas `lib/` dan `pubspec.yaml` tidak ditimpa. Ganti `com.contoh` dengan
domain Anda sendiri.

## Membuat APK

```bash
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

Untuk mengubah nama aplikasi di ponsel, ubah `android:label` di
`android/app/src/main/AndroidManifest.xml` menjadi `Keuangan Saku`.

## Struktur

```text
lib/
  main.dart                 navigasi 3 tab
  core/                     format Rupiah/tanggal, widget dan dialog bersama
  data/                     skema SQLite, model, repository
  features/
    transaksi/              harian, kalender, bulanan, tutup buku, memo, form
    statistik/              diagram lingkaran, daftar kategori, filter periode
    aset/                   aset utama (atas), aset tambahan (bawah), detail
```
