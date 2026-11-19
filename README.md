# Kernel OTG sambil mengisi untuk Mi Mix 2S (LineageOS 22.2)

Paket ini membangun ulang kernel LineageOS untuk Mi Mix 2S (polaris) di GitHub Actions,
dengan satu tambahan: parameter `otg_chg_icl_ua` di driver charger. Saat parameter itu
diisi (misalnya 2000000 = 2 A), ponsel tidak lagi dikunci ke batas "port USB biasa"
500 mA ketika menerima daya dari luar sambil menjadi host USB.

Saat parameter bernilai 0 (bawaan), kernel berperilaku sama seperti aslinya.

## Isi paket

| File | Fungsi |
|---|---|
| `.github/workflows/build.yml` | Skrip build otomatis di GitHub Actions |
| `scripts/patch_smb.py` | Memasang patch ke `smb-lib.c` |
| `config.gz` | **Anda tambahkan sendiri**: konfigurasi kernel dari ponsel |

## Langkah 1: ambil konfigurasi kernel dari ponsel

```
su -c 'cp /proc/config.gz /sdcard/Download/config.gz'
```

## Langkah 2: buat repositori GitHub (dari browser ponsel)

1. Masuk ke github.com, buat repositori baru (Public atau Private).
2. **Add file → Create new file**, beri nama persis `.github/workflows/build.yml`,
   tempelkan isi file `build.yml`, lalu **Commit**.
3. **Add file → Create new file**, beri nama `scripts/patch_smb.py`,
   tempelkan isi file `patch_smb.py`, lalu **Commit**.
4. **Add file → Upload files**, unggah `config.gz` dari folder Download, lalu **Commit**.

## Langkah 3: jalankan build

1. Buka tab **Actions** di repositori.
2. Pilih **Build kernel OTG-charge**, tekan **Run workflow**, biarkan isian bawaan.
3. Tunggu sekitar 30–90 menit.
4. Setelah selesai, buka hasil run dan unduh **kernel-otg-charge** (file zip).
   Isinya `Image`, `Image.gz-dtb`, dan `build.log`.

Kalau build gagal (tanda silang merah), unduh zip yang sama dan kirim `build.log`,
atau salin bagian akhir log dari langkah yang gagal.

## Langkah 4: jangan flash dulu

Kirim kabar bahwa build berhasil. Langkah membuat `boot.img` baru dengan `magiskboot`
dan cara mem-flash-nya akan diberikan setelah itu, bersama rencana pemulihan
kalau kernel gagal boot.
