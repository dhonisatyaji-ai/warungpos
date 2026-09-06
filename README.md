# WarungPOS

Kasir UMKM. Buka: **https://dhonisatyaji-ai.github.io/warungpos/**

Login: `admin` / `admin123` · `kasir` / `kasir123`

## Unggah ke GitHub (pembaruan)

1. Buka repo → folder paling atas (root)
2. **Add file → Upload files**
3. Unggah **semua file di folder ini**, terutama:
   - `index.html`
   - `version.json`
   - `.nojekyll` (file kosong, nama harus persis)
4. Commit
5. Buka github.io/warungpos → menu **Update → Pasang sekarang**

Jangan unggah `Index (2).html` atau file dari editor Apps Script.

## Data

- Default: tersimpan di HP/laptop (cepat, tanpa loading Google)
- Cloud: Pengaturan → isi URL + kunci **Supabase**, jalankan `supabase-schema.sql` di SQL Editor
- Spreadsheet Google: opsional di Pengaturan (lebih lambat)

## File cadangan

- `gas-Code.gs` — backend lama Google (tidak wajib)
- `supabase-schema.sql` — tabel cloud
