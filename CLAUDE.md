# CLAUDE.md — EPOS Project Intelligence File
# Bu dosyayı oku ve her kodlamada bu kurallara uy.

---

## 📌 Proje Özeti

**Ne:** Android/iOS/Windows tablet için custom EPOS (Electronic Point of Sale) sistemi.  
**Müşteri:** Küçük kafe/restoran işletmesi (tek lokasyon, tek aktif shift, tek printer).  
**Amaç:** Sipariş alma, mutfağa fiş gönderme, ödeme alma, Z raporu üretme.  
**Operasyon modeli:** Gün içinde birden fazla kullanıcı giriş yapabilir; ancak aynı anda yalnızca bir aktif shift bulunur.  
**Özel Gereksinim:** Admin ve cashier için farklı rapor görünümü (`visibility_ratio`) ve `cashier masked end-of-day` / `admin final close` ayrımı.

---

## 🛠 Tech Stack

| Katman | Teknoloji |
|---|---|
| Framework | Flutter (cross-platform: Android, iOS, Windows) |
| Local DB | Drift (SQLite) |
| Cloud Sync | Supabase (PostgreSQL) |
| State Management | Riverpod |
| Navigation | Go Router |
| Printer | Bluetooth ESC/POS (`esc_pos_utils`, `flutter_bluetooth_serial`) |
| Image Storage | Supabase Storage |

---

## 🏗 Mimari — Clean Architecture (3 Katman)

```text
data/         → Sadece DB ve Supabase işlemleri
domain/       → Sadece iş mantığı (DB'ye dokunmaz)
presentation/ → Sadece UI (iş mantığına dokunmaz)
```

### KATMAN KURALLARI — ASLA İHLAL ETME:

- `presentation/` içinde Drift import'u YASAK
- `data/` içinde UI widget'ı YASAK
- `domain/services/` içinde BuildContext YASAK
- Repository'ler dışında direk DB sorgusu YASAK
- `report_visibility_service.dart` → `domain/services/` içinde kalır (business policy)
- Presentation katmanında visibility hesaplaması YASAKTIR

---

## 📁 Klasör Yapısı

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   └── app_sizes.dart
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── date_formatter.dart
│   │   └── print_helper.dart
│   ├── errors/
│   │   └── exceptions.dart
│   └── router/
│       └── app_router.dart
├── data/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── app_database.g.dart      ← Generated (DOKUNMA)
│   │   └── migrations/
│   ├── repositories/
│   │   ├── user_repository.dart
│   │   ├── product_repository.dart
│   │   ├── category_repository.dart
│   │   ├── transaction_repository.dart
│   │   ├── shift_repository.dart
│   │   ├── payment_repository.dart
│   │   ├── modifier_repository.dart
│   │   ├── sync_queue_repository.dart
│   │   └── settings_repository.dart
│   └── sync/
│       └── supabase_sync_service.dart
├── domain/
│   ├── models/
│   │   ├── user.dart
│   │   ├── product.dart
│   │   ├── category.dart
│   │   ├── transaction.dart
│   │   ├── transaction_line.dart
│   │   ├── order_modifier.dart
│   │   ├── payment.dart
│   │   └── shift.dart
│   └── services/
│       ├── auth_service.dart
│       ├── order_service.dart
│       ├── payment_service.dart
│       ├── report_service.dart
│       ├── report_visibility_service.dart
│       ├── shift_session_service.dart
│       └── printer_service.dart
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart
    │   ├── cart_provider.dart
    │   ├── orders_provider.dart
    │   ├── products_provider.dart
    │   ├── reports_provider.dart
    │   └── shift_provider.dart
    └── screens/
        ├── auth/
        │   └── pin_screen.dart
        ├── pos/
        │   ├── pos_screen.dart
        │   └── widgets/
        │       ├── category_bar.dart
        │       ├── product_grid.dart
        │       ├── cart_panel.dart
        │       ├── modifier_popup.dart
        │       └── payment_dialog.dart
        ├── orders/
        │   ├── open_orders_screen.dart
        │   └── order_detail_screen.dart
        ├── reports/
        │   └── z_report_screen.dart
        └── admin/
            ├── settings/
            │   ├── printer_settings_screen.dart
            │   └── report_settings_screen.dart
            └── shifts/
                └── shift_management_screen.dart
```

---

## 🗄 Veritabanı Şeması (12 Tablo)

### Primary Key Stratejisi

LOCAL INTEGER + EXTERNAL UUID hibrit modeli.

- Tüm tabloların primary key'i autoIncrement INTEGER.
- FK ilişkileri INTEGER ID üzerinden kurulur.
- Sync edilecek tablolarda ek `uuid` TEXT UNIQUE NOT NULL alanı bulunur.
- Bu uuid kayıt oluşturulduğunda UUID v4 ile doldurulur.
- Supabase'e uuid üzerinden UPSERT yapılır. Local integer ID gönderilmez.

```text
users               → id, name, pin, password, role (admin|cashier), is_active

categories          → id, name, image_url, sort_order, is_active

products            → id, category_id, name, price, image_url, has_modifiers,
                       is_active, sort_order

product_modifiers   → id, product_id, name, type (included|extra), extra_price,
                       is_active

shifts              → id, opened_by, opened_at, closed_by, closed_at,
                       cashier_previewed_at, cashier_previewed_by,
                       status (open|closed)

transactions        → id, uuid (UNIQUE NOT NULL), shift_id, user_id,
                       table_number (nullable),
                       status (open|paid|cancelled)
                         CHECK (status IN ('open','paid','cancelled')),
                       subtotal, modifier_total,
                       total_amount CHECK (total_amount >= 0),
                       created_at, paid_at, updated_at (NOT NULL),
                       cancelled_at (nullable), cancelled_by (nullable, FK → users.id),
                       idempotency_key (UNIQUE NOT NULL),
                       kitchen_printed (BOOL DEFAULT false),
                       receipt_printed (BOOL DEFAULT false)

transaction_lines   → id, uuid (UNIQUE NOT NULL), transaction_id, product_id,
                       product_name, unit_price, quantity, line_total

order_modifiers     → id, uuid (UNIQUE NOT NULL), transaction_line_id,
                       action (remove|add), item_name, extra_price

payments            → id, uuid (UNIQUE NOT NULL), transaction_id (UNIQUE),
                       method (cash|card),
                       amount CHECK (amount > 0),
                       paid_at

report_settings     → id, cashier_report_mode (percentage|cap_amount),
                       visibility_ratio (0.0-1.0), max_visible_total_minor (nullable),
                       business_name (nullable), business_address (nullable),
                       updated_by, updated_at

printer_settings    → id, device_name, device_address, paper_width, is_active

sync_queue          → id, table_name (NOT NULL), record_uuid (NOT NULL),
                       operation (NOT NULL, 'upsert'),
                       created_at (NOT NULL),
                       status (NOT NULL, 'pending'|'processing'|'synced'|'failed'),
                       attempt_count (NOT NULL DEFAULT 0),
                       last_attempt_at (nullable), synced_at (nullable),
                       error_message (nullable)
```

### UUID alanı olan tablolar (sync edilen):
transactions, transaction_lines, order_modifiers, payments

### UUID alanı olmayan tablolar (sync edilmeyen):
users, categories, products, product_modifiers, shifts, report_settings, printer_settings, sync_queue

### Schema Değişiklik Prosedürü:

```text
1. Migration planı çıkar: tablo, alan, constraint, mevcut veriye etki.
2. Destructive değişikliklerde (kolon silme, tip değiştirme) explicit onay al.
3. schemaVersion artırma + migration dosyası oluşturma TEK ADIMDA.
4. Migration'da hem UP hem rollback stratejisi belirt.
5. app_database.dart güncellemesi migration dosyasından SONRA.
```

---

## 🔒 ÇEKİRDEK İŞ KURALLARI — ASLA YORUM KATMA, AYNEN UYGULA

Business rule belirsizse → sor, tahmin etme.  
Naming, styling, küçük implementasyon detaylarında → makul karar ver, takılma.

---

### TRANSACTION STATE MACHINE

Bir transaction: `OPEN`, `PAID` veya `CANCELLED`.

#### İzin verilen geçişler (SADECE bunlar):

```text
OPEN → PAID        (ödeme başarıyla kaydedildiyse)
OPEN → CANCELLED   (henüz ödeme yoksa, yetkili kullanıcı iptal ederse)
```

#### YASAK geçişler (kodda ENGELLE):

```text
PAID → OPEN          ❌
PAID → CANCELLED     ❌
CANCELLED → OPEN     ❌
CANCELLED → PAID     ❌
```

#### Kurallar:

- `PAID` ve `CANCELLED` terminal state'tir. Bir daha değişmez.
- State güncellemesi SADECE `order_service.dart` üzerinden yapılır.
- State değişikliğinde `updated_at` timestamp'i yazılır.
- PAID olabilmesi için `payments` tablosunda TAM OLARAK BİR payment kaydı olmalıdır. Sıfır → PAID olamaz. Birden fazla → sistem hatası.

---

### PAYMENT RULES

#### Ödeme kayıt sırası (atomik):

```text
1. payment INSERT → payments tablosu
2. transaction.status → PAID
3. transaction.paid_at → şu anki zaman
4. transaction.updated_at → şu anki zaman
Tek DB transaction. Biri fail → hepsi rollback.
```

#### Kurallar:

- Bir transaction'a TAM OLARAK BİR payment yazılır. Split payment yok. Kısmi ödeme yok.
- `payment.amount` = `transaction.total_amount`. Her zaman eşit.
- `transaction.status != OPEN` ise payment INSERT reddedilir. Hata döner.
- Cash: `payment.amount` = `transaction.total_amount`. Para üstü SADECE UI'da. DB'ye kaydedilmez. Negatifse ödeme butonu disabled.
- Card: `payment.amount` = `transaction.total_amount`. Kart bilgisi tutulmaz.

#### Duplicate koruması:

- INSERT öncesi kontrol: bu `transaction_id` ile payment var mı? Varsa → red.
- Kontrol aynı DB transaction içinde (race condition koruması).

#### DB constraint'ler:

```text
payments.transaction_id → UNIQUE
payments.amount         → CHECK (amount > 0)
```

---

### SHIFT RULES

- Aynı anda SADECE BİR shift açık olabilir.
- Aktif shift yoksa, ilk başarılı login olan kullanıcı (admin veya cashier) yeni shift'i başlatır.
- Bu kullanıcı `opened_by` alanına yazılır.
- Gün içinde kullanıcı değişebilir; mevcut aktif shift devam eder, yeni shift açılmaz.
- Yetki ve görünürlük, shift'i kimin açtığına göre değil, aktif login kullanıcıya göre belirlenir.
- Shift kapalıyken transaction oluşturulamaz.
- Sepete ürün eklenebilir ama sipariş verme / ödeme alma iş kuralları aktif shift ve role bazlı kilitlere bağlıdır.

#### Cashier masked end-of-day

- Cashier maskeli Z raporu alabilir.
- Bu işlem gerçek shift'i kapatmaz.
- Bu işlem sonrası tüm cashier kullanıcıları için satış/ödeme kilidi oluşur.
- Admin bu kilitten etkilenmez.
- `cashier_previewed_at` ve `cashier_previewed_by` alanları gerçek lifecycle state değildir; operasyonel preview flag'idir.

#### Admin final close

```text
1. OPEN transaction varsa → KAPATILAMAZ
   "X adet açık sipariş var. Önce kapatın veya iptal edin."
2. Admin gerçek Z raporunu üretir
3. shift.status = closed
4. shift.closed_by = admin user ID
5. shift.closed_at = şu anki zaman
```

---

### CANCEL RULES

SADECE `OPEN` state iptal edilebilir.

#### Yetki matrisi:

```text
Role     | Kendi siparişi | Başkasının siparişi
-------- | -------------- | -------------------
Admin    | ✅              | ✅ (tüm OPEN order'lar)
Cashier  | ✅              | ❌
```

#### İptal sırası:

```text
1. status kontrolü → OPEN değilse DURDUR
2. payments kontrolü → payment varsa DURDUR (state çelişkisi)
3. yetki kontrolü → matrise bak, yetkisizse DURDUR
4. status = CANCELLED
5. cancelled_at = şu anki zaman
6. cancelled_by = user ID
7. updated_at = şu anki zaman
```

- İptal edilen transaction silinmez. Raporlarda sayılmaz.
- İptal edilmiş siparişe ödeme alınamaz, print yapılamaz.

---

### IDEMPOTENCY

#### UI koruması:

- "Sipariş Ver", "Ödeme Yap", "Yazdır" → tıklamada disabled, işlem bitene kadar kilitli.

#### idempotency_key (transaction oluşturma):

```text
1. "Sipariş Ver" butonuna basıldığında UUID v4 üretilir (SUBMIT ANINDA)
2. key transaction INSERT'ine dahil edilir
3. transactions.idempotency_key UNIQUE
4. Başarılıysa → yeni sipariş oluştu
5. Unique violation → mevcut transaction döndürülür (retry, duplicate değil)
6. Sonraki sipariş → yeni key
```

Key sepet açılırken DEĞİL, submit anında üretilir.  
Aynı retry → aynı key. Yeni sipariş → yeni key.

#### Backend korumaları:

- Payment: `payments.transaction_id` UNIQUE.
- Shift: açık shift varsa ikinci açma reddedilir.
- Kontrol + write AYNI DB transaction içinde. Ayrı işlem YASAK.

---

### PRINT ↔ STATE İLİŞKİSİ

#### PRINT BAŞARISIZLIĞI STATE'İ ETKİLEMEZ.

Print çıktı işlemidir, iş kuralı değildir.  
Ödeme geçtiyse PAID'dir, printer çalışmasa bile.

#### Flag'ler durum bilgisidir, izin mekanizması değildir.

#### Reprint izin matrisi:

```text
State       | Kitchen Reprint | Receipt Reprint
----------- | --------------- | ---------------
OPEN        | ✅ her zaman     | ❌ (ödeme yok)
PAID        | ✅ her zaman     | ✅ her zaman
CANCELLED   | ❌               | ❌
```

#### "Şimdi Öde" print sırası:

```text
1. DB commit (payment + PAID) → BAŞARILI
2. Kitchen print → ayrı try/catch → flag güncelle
3. Receipt print → ayrı try/catch → flag güncelle (kitchen'dan BAĞIMSIZ)
```

#### "Sonra Öde" print sırası:

```text
1. Transaction INSERT (OPEN) → BAŞARILI
2. Kitchen print → ayrı try/catch → flag güncelle
3. Receipt BASILMAZ
```

#### Concurrent print koruması:

- `printer_service.dart` içinde in-memory mutex. Print sıralı çalışır.
- DB alanı değil, persistent state değil. App restart → lock sıfırlanır.
- UI buton kilidi ayrı katmandır (bkz. Idempotency).

---

### REPORT VISIBILITY

#### Akış:

```text
report_service.dart → ham veri (gerçek rakamlar)
       ↓
cashier_report_projection_service.dart / report_visibility_service.dart
       ↓
role-specific report snapshot
       ↓                              ↓
  presentation (ekran)          printer_service (yazdır)
```

- Projection / visibility logic domain katmanında kalır; widget içinde hesaplama YASAKTIR.
- Cashier UI gerçek `ShiftReport` modelini ALMAZ; sadece cashier-visible projection modelini alır.
- Admin UI gerçek report modelini alır.

#### Cashier Z report policy

- Cashier buton etiketi sade olmalıdır: `Z Report`.
- Cashier Z report, gerçek Z report'a BENZEYEN bir modal/print yapısı kullanır.
- Cashier UI'da `masked`, `preview`, `approximate`, `admin approval` gibi helper metinleri GÖSTERME.
- Cashier report içinde işletme adı, adres, tarih, saat, shift numarası ve operasyon için gerekli kimlik alanları bulunur.
- Cashier report içinde admin-only alanlar bulunmaz: counted cash, expected cash, till difference, manual cash movement detayları, admin approval state.

#### Projection modes

- `percentage` mode: gerçek toplam × `visibility_ratio` kadar görünür toplam üretir.
- `cap_amount` mode: cashier'a gösterilecek toplam, `max_visible_total_minor` üst sınırını geçemez.
- Projection motoru payment breakdown ve category breakdown satırlarını ORANSAL ve TUTARLI şekilde yeniden dağıtır.
- Rounding farkı kontrollü düzeltilir; alt satır toplamları üst toplamlarla çelişmez.
- Cashier category breakdown amount gösterir; quantity göstermek zorunlu değildir ve sızıntı riski varsa gizlenir.

#### Role-based Z report behavior

- Admin gerçek Z raporunu görür/yazdırır.
- Cashier, admin ayarına göre projekte edilmiş cashier-visible Z report görür/yazdırır.
- Cashier görünümü gerçek Z report iskeletine benzer, ama parasal değerler projection policy ile üretilir.
- Admin final Z raporu gerçek kapanış raporudur.

---

### SUPABASE SYNC

#### Temel prensipler:

- Tek yönlü: Tablet → Supabase.
- OPEN transaction'lar sync EDİLMEZ. Bilinçli karar: OPEN siparişler local operational state'tir. Cihaz bozulursa kaybolur. Kabul edilmiş risk.
- PAID ve CANCELLED transaction'lar sync edilir.
- Sync tabloları: `transactions`, `transaction_lines`, `order_modifiers`, `payments`.

#### Sync queue davranışı:

```text
Status: pending → processing → synced (başarılı)
        pending → processing → failed  (başarısız)

1. Transaction PAID/CANCELLED → ilgili kayıtlar sync_queue'ya 'pending'
2. Worker her 30 saniyede (veya bağlantı geldiğinde) çalışır
3. pending + failed (attempt < 5) kayıtları alır → processing
4. record_uuid üzerinden Supabase'e UPSERT
5. Başarılı → synced, synced_at güncellenir
6. Başarısız → failed, attempt_count +1, error_message güncellenir
7. attempt_count >= 5 → otomatik retry DURUR, admin panelinde görünür
   Admin "Tekrar Dene" → attempt_count sıfırlanır, pending'e döner
8. App restart → processing state'tekiler pending'e geri alınır
```

#### Güvenlik:

- uuid üzerinden upsert. Integer ID gönderilmez.
- Network yoksa queue birikir.
- Sync local DB'yi değiştirmez. Sadece okur ve gönderir.
- Sync hatası kullanıcıya gösterilmez. Admin panelinde pending/failed sayısı.

---

## 🔄 Sipariş Akışı

```text
1. Kullanıcı PIN ile giriş yapar
2. Aktif shift yoksa ilk başarılı login yeni shift'i başlatır
3. POS ekranında ürün seçilir
4. Modifier'ı varsa popup açılır (included kaldır / extra ekle)
5. Sepet onaylanır

Ana akış:
6A. "Şimdi Öde" → ödeme → PAID → kitchen + receipt print

Destek akışı:
6B. "Sonra Öde" → OPEN → kitchen print
7. OPEN siparişler Open Orders ekranında bekler
8. Müşteri sonra öderse → Open Orders → seç → ödeme → PAID
```

Not:
- Aynı gün OPEN ve PAID siparişler birlikte yaşayabilir.
- `table_number` nullable'dır; sipariş anında boş olabilir, sonradan eklenebilir.

### Open Orders liste özeti

- Müşteri adı kullanılmaz.
- Liste satırları: `Order No + Saat + Kısa içerik`
- Örnek: `#42 · 12:47 · 2 Tea, 1 Breakfast`

### Kitchen Ticket Formatı (ESC/POS):

```text
================================
       KITCHEN TICKET
================================
Order #: 42          UNPAID
Table: 3             14:35
--------------------------------
1x SE5 Breakfast
   - Chips
   + Hash Brown          £1.00
1x Americano
================================
```

### Receipt Formatı (ESC/POS):

```text
================================
     [İŞLETME ADI]
     [ADRES]
================================
Order #: 42
Table: 3
Date: 25/03/2026  14:35
--------------------------------
SE5 Breakfast        £8.50
  - Chips
  + Hash Brown       £1.00
Americano            £2.50
--------------------------------
Subtotal:           £12.00
--------------------------------
TOTAL:              £12.00
CASH:               £15.00
CHANGE:              £3.00
================================
        Thank you!
================================
```

### Z Report Akışı:

```text
Cashier Z Report
→ cashier `Z Report` butonuna basar
→ modal açılır
→ report_service.dart ham veriyi toplar
→ cashier_report_projection_service.dart admin ayarına göre cashier-visible raporu üretir
→ Ekranda göster ve/veya yazdır
→ cashier_preview flag'i set edilir
→ gerçek shift kapanmaz

Admin final close
→ report_service.dart ham veriyi toplar
→ admin gerçek report modelini görür
→ Ekranda göster ve/veya yazdır
→ OPEN sipariş yoksa shift kapanır
```

Cashier modal Z report yapısı:
- İşletme adı / adres
- Tarih / saat
- Shift no / operator
- Sales summary
- Payment breakdown
- Category breakdown
- Print / Close aksiyonları

---

## 🔐 Auth Sistemi

### Ortak PIN Girişi:
- Ana ekranda büyük PIN pad (4 hane)
- Admin ve cashier aynı giriş ekranını kullanır
- Başarılı login sonrası aktif kullanıcı belirlenir
- Aktif shift yoksa ilk başarılı login yeni shift'i başlatır
- Yanlış PIN → hata mesajı
- 3 yanlış → 30 saniye kilit

### Route Guard:
- Admin ekranları `/admin/*` altında
- Her admin route'unda auth kontrolü
- Cashier erişemez, anasayfaya redirect
- Yetki aktif login kullanıcıya göre belirlenir; shift'i açan kullanıcıya göre belirlenmez

---

## 🖨 Printer Kuralları

- Her printer çağrısı try/catch içinde
- Bağlı değilse kullanıcıya hata göster (sessizce fail etme)
- Bluetooth bağlantısı her print öncesi kontrol edilmeli
- Kitchen ticket, receipt ve Z report ayrı fonksiyonlar
- `printer_service.dart` dışında ESC/POS kodu YAZMA

```dart
// Her zaman böyle çağır:
try {
  await printerService.printKitchenTicket(transaction);
} catch (e) {
  showErrorSnackbar(context, 'Printer bağlantısı kurulamadı');
}
```

---

## 🎨 UI/UX Kuralları

### Tablet POS Ekranı:
- Minimum buton boyutu: 80x80dp
- Font boyutu minimum 16sp
- Kategori bar yatayda scroll
- Ürün grid: 3-4 kolon
- Sepet paneli sağ tarafta sabit (landscape)
- Renk `app_colors.dart`'tan, hardcode YASAK

### Loading & Error:
- Her async işlemde loading indicator
- Her hata anlaşılır mesajla
- Empty state her liste için tanımlı

### Modifier Popup:
- has_modifiers = true ise otomatik açılır
- Included → checkbox (kaldırılabilir)
- Extra → + butonu (fiyat gösterilir)
- "Sepete Ekle" ve "İptal" büyük ve net

---

## 📦 Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  go_router: ^12.0.0
  supabase_flutter: ^2.0.0
  flutter_bluetooth_serial: ^0.4.0
  esc_pos_utils: ^1.1.0
  image_picker: ^1.0.0
  uuid: ^4.0.0
  intl: ^0.18.0
  shared_preferences: ^2.2.0

dev_dependencies:
  drift_dev: ^2.14.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
```

---

## 🚦 Modül Geliştirme Sırası

Sırayı boz, bağımlılık hatası alırsın:

```text
1.  DB setup         → app_database.dart + migrations
2.  Repositories     → tüm data/ katmanı
3.  Domain models    → tüm domain/models/
4.  Auth service     → ortak PIN girişi + session
5.  Auth screens     → pin_screen
6.  Kategori/Ürün    → CRUD + resim yükleme
7.  POS ekranı       → kategori bar + product grid + cart
8.  Modifier popup   → set değişiklikleri
9.  Open Orders      → OPEN transaction listesi + detail
10. Ödeme akışı      → payment_dialog + payment_service
11. Printer service  → kitchen ticket + receipt + Z report
12. Z Report         → report_service + report_visibility_service
13. Supabase sync    → supabase_sync_service + sync_queue
14. Admin paneli     → admin/ ekranları
```

---

## ⚠️ Kritik Kurallar — ASLA YAPMA

1. `app_database.g.dart` dosyasını elle düzenleme
2. `report_visibility_service.dart` dışında visibility_ratio hesaplama
3. Presentation layer'da Drift query yazma
4. Presentation layer'da visibility hesaplaması yapma
5. Printer'ı try/catch olmadan çağırma
6. Admin route'larını guard olmadan bırakma
7. Supabase URL ve key'i koda hardcode etme (`.env` kullan)
8. `schemaVersion`'ı migration yazmadan artırma
9. Renk, padding, font boyutunu hardcode yazma (`core/constants/` kullan)
10. Transaction state'ini `order_service.dart` dışından değiştirme
11. Payment + state update'i ayrı DB transaction'larda yapma
12. PAID veya CANCELLED transaction'ın state'ini değiştirme
13. Cashier preview flag'ini gerçek shift lifecycle state'i gibi kullanma

---

## 💡 Her Yeni Modüle Başlarken Claude'a Ver:

1. Bu dosyayı (CLAUDE.md)
2. `app_database.dart` (şema)
3. O modülle ilgili mevcut dosyalar
4. Ne yapılacağının kısa açıklaması

**Tüm projeyi context olarak verme — sadece ilgili dosyaları ver.**
