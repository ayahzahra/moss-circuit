# Moss Circuit — kebun mini

Game snake bertema kebun malam. Kumpulkan biji bercahaya, hindari tepi dan
tubuh ular, lalu coba capai rekor terbaikmu.

## Mainkan versi Windows

Unduh atau buka [`MossCircuit.exe`](MossCircuit.exe) di Windows 32-bit atau
64-bit. Tidak perlu menginstal runtime atau dependensi tambahan.

## Kontrol

- **Panah** atau **WASD** untuk mengarahkan ular
- **Space** untuk mulai, jeda, atau lanjutkan permainan
- **T** untuk mengganti tema gelap/terang
- **R** untuk memulai ulang
- Tombol di layar juga bisa diklik

Kecepatan bertambah saat ular mengumpulkan biji. Rekor dan pilihan tema
tersimpan di `%APPDATA%\MossCircuit`.

## Kompilasi dari source Pascal

1. Instal [Free Pascal Compiler](https://www.freepascal.org/download.html).
2. Buka Command Prompt di folder proyek.
3. Jalankan `fpc -WG -O2 -Xs MossCircuit.pas`.

Perintah tersebut membuat `MossCircuit.exe`. Source tersedia di
[`MossCircuit.pas`](MossCircuit.pas). Game Windows menggunakan WinAPI bawaan
dan tidak memerlukan library eksternal.

## Versi browser

Buka [`index.html`](index.html) langsung di browser—tanpa server atau dependensi.
Untuk menerbitkan versi ini dengan GitHub Pages, buka **Settings → Pages**,
pilih **Deploy from a branch**, lalu pilih branch `main` dan folder `/ (root)`.
