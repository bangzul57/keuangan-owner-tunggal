# Keuangan Owner Tunggal (Offline)

Aplikasi pencatatan keuangan **sederhana, fleksibel, dan offline-first**  
untuk **Owner Tunggal (UMKM perorangan)**.

Proyek ini **open-source**, namun **dengan arah yang jelas dan scope yang dikunci**.

> Ini **bukan software akuntansi**, bukan ERP, dan bukan sistem enterprise.

---

## 🎯 Tujuan Proyek

Menyediakan aplikasi yang membantu **pemilik usaha tunggal** mencatat:
- uang masuk
- uang keluar
- perpindahan saldo
- penjualan barang / jasa

dengan cara:
- cepat
- tidak ribet
- tidak memaksa disiplin akuntansi formal

---

## 👤 Target Pengguna

### Cocok untuk:
- Konter pulsa & saldo digital
- Fotokopi & percetakan kecil
- Laundry, salon, barbershop
- Warung & toko kecil
- Jasa service (HP, AC, listrik)
- Katering rumahan
- Freelancer & usaha perorangan

### Tidak cocok untuk:
- Perusahaan besar / enterprise
- Manufaktur & produksi massal
- Koperasi, fintech, lembaga keuangan
- Proyek konstruksi besar
- Marketplace & multi-user platform
- Trading saham / crypto
- Usaha dengan regulasi ketat

Jika use-case Anda masuk kategori **tidak cocok**,  
mohon **tidak memaksakan fitur baru** ke proyek ini.

---

## 🧠 Filosofi Inti

1. **Uang nyata lebih penting dari laporan rapi**
2. **Owner boleh mencampur uang pribadi & usaha**
3. **Edit saldo manual diperbolehkan**
4. **Tidak ada istilah akuntansi (debit/kredit)**
5. **Jika fitur bikin user mikir lama → fitur ditolak**

Filosofi ini **tidak untuk diperdebatkan**, karena merupakan inti produk.

---

## 🧩 Konsep Sistem

### Transaksi Generik
Semua aktivitas dicatat sebagai **Transaksi**.

Field minimal:
- Tanggal
- Nominal
- Akun (Kas / Bank / E-Wallet)
- Catatan

Field opsional:
- Barang (stok)
- Jasa
- Piutang
- Admin / fee
- Akun sumber & tujuan

User **tidak diwajibkan** mengisi detail opsional.

---

## 🗓️ Sistem Tanggal

- Default tanggal transaksi: `DateTime.now()`
- User **bebas mengubah tanggal**
- Tidak ada lock periode
- Tidak ada pembatasan input mundur

Tanggal adalah **atribut transaksi**, bukan aturan sistem.

---

## ⚙️ Fitur yang Disediakan

### Manajemen Akun
- Akun Kas
- Akun Bank
- Akun E-Wallet
- Edit saldo manual

### Transaksi
- Jual / beli saldo digital
- Jual barang (stok sederhana)
- Transaksi jasa
- Pindah saldo antar akun
- Pemasukan & pengeluaran umum

### Piutang Sederhana
- Tanpa bunga
- Tanpa jadwal kompleks

### Laporan Ringkas
- Saldo per akun
- Total pemasukan
- Total pengeluaran
- Laba kasar

---

## ❌ Non-Goals (Fitur yang Tidak Akan Dibuat)

Proyek ini **secara sadar TIDAK** akan menambahkan:

- Akuntansi formal (COA, jurnal, neraca)
- Multi-user / role / approval
- Payroll & HR
- Pajak & e-Faktur
- Billing otomatis kompleks
- Produksi & manufaktur
- Manajemen proyek besar
- Sistem langganan kompleks

Pull request yang mengarah ke fitur di atas  
**akan ditolak meskipun implementasinya bagus**.

---

## 🧭 Prinsip UX

- Input seminimal mungkin
- Tombol tidak aktif jika form belum valid
- Tidak ada error merah mendadak
- Pesan error pakai bahasa manusia
- Tidak ada pop-up berlebihan
- Bisa dipakai tanpa training

---

## 🔒 Aturan Scope (Wajib untuk Kontributor)

Sebelum mengusulkan fitur, tanyakan:

1. Apakah fitur ini masih relevan untuk **owner tunggal**?
2. Apakah fitur ini bisa dipakai tanpa pengetahuan akuntansi?
3. Apakah fitur ini menambah kompleksitas mental user?
4. Apakah fitur ini memaksa “cara benar” versi sistem?
5. Apakah fitur ini bisa dijelaskan ke UMKM dalam 1 kalimat?

Jika **salah satu jawabannya “tidak”**,  
maka fitur tersebut **di luar scope proyek**.

---

## 🛠️ Teknologi

- Flutter
- SQLite (offline-first)
- Provider (state management)
- Fokus: stabil, sederhana, mudah dirawat

---

## 🛣️ Roadmap Singkat

### v1 – Fondasi
- Akun & saldo
- Transaksi dasar
- Validasi & stabilitas

### v2 – Pemakaian Harian
- Barang & jasa
- Piutang
- Riwayat transaksi
- Laporan ringkas

### v3 – Kenyamanan
- Filter & pencarian
- Export data
- Backup & restore
- Grafik sederhana

---

## 🤝 Contributing

Kontribusi **dipersilakan**, terutama untuk:
- Perbaikan bug
- Penyederhanaan UX
- Optimasi performa
- Dokumentasi

Silakan buka issue terlebih dahulu untuk:
- fitur baru
- perubahan perilaku sistem

Tujuannya agar arah proyek **tetap konsisten**.

---

## 🧾 Pernyataan Penutup

> “Proyek ini tidak mencoba menyenangkan semua orang.  
> Proyek ini mencoba membantu owner tunggal mencatat uang dengan jujur dan cepat.”

Jika filosofi ini cocok dengan Anda,  
selamat datang sebagai pengguna atau kontributor 🙌
