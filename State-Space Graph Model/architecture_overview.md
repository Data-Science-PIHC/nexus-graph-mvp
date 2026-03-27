# Arsitektur Data & Model Logistik Nexus Graph (State-Space)

Dokumen ini menjelaskan struktur data mendalam dan logika pemodelan grafik yang digunakan untuk mengelola kompleksitas biaya distribusi multi-modal menggunakan pendekatan **State-Space**.

---

## 1. Konsep Utama: State-Space Architecture
Nexus Graph tidak menggunakan model "City-to-City" sederhana. Sistem ini menggunakan **State-Space Graph**, di mana setiap lokasi dipecah berdasarkan wujud barangnya (**Packaging State**).

### Komponen Utama Grafik:
*   **CargoState (Node)**: Titik unik yang menggabungkan `Location_Code` + `Packaging State`. 
    *   *Contoh*: `D101_CURAH` dan `D101_INBAG` adalah dua node yang berbeda meskipun berada di lokasi fisik yang sama.
*   **Operation (Edge/Relationship)**: Jalur fisik atau proses internal yang menghubungkan dua `CargoState`.
    *   *MOVE*: Berpindah lokasi antar gudang/pelabuhan.
    *   *BAGGING*: Transisi perubahan wujud (Curah -> Inbag) di lokasi yang sama.

---

## 2. Struktur Data Input (The 5-CSV Engine)
Seluruh kecerdasan grafik dibangun dari 5 file CSV yang saling berelasi secara sistematis:

1.  **1_CargoStates.csv**: Definisi seluruh titik koordinat logistik dan batasan wujud barangnya.
2.  **2_Operations.csv**: Peta konektivitas fisik. Mendefinisikan jalur mana yang secara teknis bisa dilewati.
3.  **3_TariffMasters.csv**: Layer finansial. Menentukan di mana biaya menempel berdasarkan `contract_scope` (Origin/Dest/Route).
4.  **4_Conditions.csv**: Pintu pengaman (Gating). Menyimpan aturan bisnis dinamis (Contoh: Hanya untuk jenis produk tertentu).
5.  **5_RateTiers.csv**: Tabel nilai harga. Mendukung skema harga progresif berdasarkan volume tonase.

---

## 3. Logika Mesin Perhitungan (Pricing Engine)

Sistem menghitung biaya secara dinamis melalui proses integrasi antara **Operational Layer** (fisik) dan **Financial Layer** (biaya):

### A. Dynamic Condition Gating
Sistem melakukan filter instan pada setiap langkah perjalanan dengan membandingkan parameter `ShipmentScenario` terhadap file `Conditions`. Jika syarat tidak terpenuhi, tarif tersebut dieliminasi secara otomatis.

### B. Multiplier Logic (Dynamic Twins)
Sistem mendukung perhitungan biaya non-linier seperti:
*   **Survey Penggandaan**: Formula otomatis `(n-1) * rate` berdasarkan jumlah produk di skenario.
*   **Conditional Components**: Mengaktifkan/mematikan komponen biaya seperti "Survey Segel" secara real-time.

### C. Commercial Validity Check
Sistem memiliki mekanisme untuk memutus jalur hantu. Sebuah operasi `MOVE` hanya dianggap valid jika ditemukan biaya **Freight/Angkutan** yang melekat padanya. Ini memastikan hasil optimasi selalu logis secara komersial.

---

## 4. Mekanisme Pathfinding (EFFECTIVE_MOVE)
Untuk menjamin performa tinggi, sistem menggunakan teknik dua tahap:
1.  **Effective Generation**: Men-generate relasi **`EFFECTIVE_MOVE`** yang sudah menggabungkan seluruh komponen biaya (Handling + Survey + Freight, dll) menjadi satu angka final per-ton.
2.  **Route Optimization**: Pencarian rute tercepat/termurah dilakukan di atas layer `EFFECTIVE_MOVE` yang sudah "matang".

---
*Dokumen ini merupakan panduan teknis operasional Nexus Graph State-Space Model.*
