/// Menentukan apakah pengingat pencatatan harian perlu dikirim.
///
/// Pengingat hanya dikirim saat belum ada transaksi pada tanggal tersebut.
bool shouldShowDailyTransactionReminder(int transactionCount) {
  return transactionCount == 0;
}
