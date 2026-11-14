# Nova AI v2.1 — Vercel + OpenAI + Supabase

Starter chatbot AI berbahasa Indonesia dengan UI responsif, streaming jawaban, autentikasi Supabase, riwayat chat, lampiran gambar/teks, dan dashboard admin.

## Yang diperbaiki di v2.1
- Menghapus seluruh kredensial dari template; semua secret server memakai Environment Variables Vercel.
- Mengganti model default menjadi `gpt-4.1-mini` (ubah hanya ke model yang benar-benar tersedia di akun API).
- Reservasi kuota harian atomik melalui PostgreSQL agar request bersamaan tidak melewati batas.
- Membatasi request API dan ukuran lampiran gambar untuk mengurangi risiko melewati batas payload serverless.
- Frontend mendeteksi stream yang terputus dan tidak menyimpan jawaban parsial sebagai jawaban sukses.
- SQL dapat dijalankan ulang tanpa error policy duplikat.
- Pemeriksaan sesi admin diperketat.

> Tidak ada software yang dapat dijamin bebas dari semua error. Lakukan pengujian dengan kredensial dan project milikmu sebelum digunakan publik.

## A. Siapkan Supabase
1. Buat project di https://supabase.com.
2. Buka **SQL Editor**, tempel seluruh isi `supabase/schema.sql`, lalu klik **Run**.
3. Buka **Project Settings → API**. Siapkan Project URL, publishable/anon key, dan secret/service-role key.
4. Di **Authentication → URL Configuration**, atur Site URL ke domain Vercel setelah deploy. Tambahkan domain Vercel ke Redirect URLs, misalnya `https://nama-project.vercel.app/**`.

## B. Isi konfigurasi frontend
Buka `public/app.js`, ubah dua konstanta di bagian paling atas:

```js
const SUPABASE_URL = "https://PROJECT_ID.supabase.co";
const SUPABASE_ANON_KEY = "SUPABASE_PUBLISHABLE_OR_ANON_KEY";
```

Gunakan URL dan publishable/anon key dari project Supabase milikmu. Key publishable/anon memang digunakan browser; **jangan** pernah menaruh secret/service-role key di file `public/`.

## C. Upload dan deploy ke Vercel
1. Ekstrak ZIP ini di komputer.
2. Buat repository baru di GitHub, lalu upload isi folder `nova-ai-vercel-v2` (pastikan `package.json`, `api/`, `public/`, `supabase/`, dan `vercel.json` berada di root repository).
3. Buka https://vercel.com → **Add New → Project** → Import repository GitHub tersebut.
4. Pada konfigurasi project:
   - Framework Preset: **Other**
   - Root Directory: `./`
   - Build Command: kosongkan (tidak diperlukan)
   - Output Directory: kosongkan / gunakan default Vercel
   - Install Command: `npm install` (default juga boleh)
5. Sebelum deploy, buka **Environment Variables** dan tambahkan:

   | Name | Value |
   |---|---|
   | `OPENAI_API_KEY` | API key BARU dari OpenAI Platform |
   | `OPENAI_MODEL` | `gpt-4.1-mini` |
   | `SUPABASE_URL` | Project URL Supabase |
   | `SUPABASE_ANON_KEY` | Publishable/anon key Supabase |
   | `SUPABASE_SERVICE_ROLE_KEY` | Secret/service-role key Supabase |
   | `ADMIN_EMAILS` | Email admin, contoh `admin@email.com` |
   | `DAILY_MESSAGE_LIMIT` | `100` atau batas yang kamu inginkan |

   Pilih environment **Production, Preview, dan Development** sesuai kebutuhan. Jangan menambahkan prefix `NEXT_PUBLIC_` atau `VITE_` pada secret server.
6. Klik **Deploy**. Tunggu sampai status deployment Ready.
7. Setelah deploy, buka URL Vercel dan coba daftar/login, kirim chat, unggah gambar kecil, simpan riwayat, dan buka dashboard admin.

## D. Konfigurasi setelah deploy
- Supabase → Authentication → URL Configuration: set **Site URL** ke URL Vercel final dan masukkan URL tersebut ke **Redirect URLs**.
- Pastikan email admin yang dimasukkan ke `ADMIN_EMAILS` sama persis dengan email akun login.
- Jika mengubah Environment Variables, lakukan **Redeploy** agar fungsi memakai nilai terbaru.

## E. Jalankan lokal (opsional)
```bash
npm install
cp .env.example .env
# Ganti semua YOUR_* di .env dengan kredensial milikmu
npm run dev
```
Pastikan konstanta Supabase di `public/app.js` juga sudah diisi.

## Batas dan catatan
- Gambar maksimal 2,5 MB per file untuk menjaga ukuran request JSON tetap di bawah batas serverless.
- File teks dibaca hingga 20.000 karakter.
- PDF/DOCX belum didukung.
- Kuota menggunakan hari UTC dan satu request yang sudah mendapat reservasi akan dihitung, termasuk jika panggilan model kemudian gagal.
- Untuk mencegah penyalahgunaan lebih lanjut pada aplikasi publik, tambahkan CAPTCHA/rate limiting per IP dan pemantauan biaya.
- OpenAI API billing terpisah dari langganan ChatGPT.
- Jangan commit `.env` atau membagikan API key. Karena ZIP versi sebelumnya berisi secret, cabut/revoke API key OpenAI dan rotasi Supabase secret/service-role key yang pernah terekspos. Jangan gunakan ulang key lama.
