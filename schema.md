# EPOS Veritabanı Şeması — Drift (SQLite) Referans Belgesi

> **Bu belge `CLAUDE.md` ile birebir uyumlu tek kaynak doğruluğudur.**
> Bir geliştirici sadece bunu okuyarak `app_database.dart` dosyasını doğru yazabilmelidir.

---

## Genel Kurallar

### Proje Kapsamı
- Tek lokasyon, küçük kafe/restoran.
- Aynı anda yalnızca bir aktif shift vardır.
- Gün içinde birden fazla kullanıcı login olabilir.
- Tek Bluetooth ESC/POS yazıcı vardır.
- Split payment YOK. Kısmi ödeme YOK.
- Ayrı order type alanı YOK. `table_number` nullable: null = masa atanmamış sipariş.
- Modifier group yapısı YOK. Düz modifier modeli.
- Tax/VAT/discount/service charge YOK. Gerekirse migration ile eklenir.

### Primary Key Stratejisi
- Tüm tabloların primary key'i `INTEGER autoIncrement`.
- FK ilişkileri INTEGER ID üzerinden kurulur.
- Sync edilecek tablolarda ek `uuid TEXT UNIQUE NOT NULL` alanı bulunur.
- Bu uuid kayıt oluşturulduğunda UUID v4 ile doldurulur.
- Supabase'e uuid üzerinden UPSERT yapılır. Local integer ID gönderilmez.

### Para Birimi Kuralı — KRİTİK
**Tüm para alanları INTEGER olarak minor units (kuruş/pence) cinsinden tutulur.**

```text
£12.50 → 1250
£0.00  → 0
£1.00  → 100
```

- `REAL` / `double` / `float` para alanı için YASAKTIR.
- Binary floating point sapması (`0.1 + 0.2 != 0.3`) raporları, toplam kontrollerini ve ödeme eşleştirmesini bozar.
- UI'da gösterim için `currency_formatter.dart` kullanılır: `1250 → £12.50`.

### Text Enum Kuralı
Tüm sınırlı değerli text alanları CHECK constraint ile korunur.  
Drift'te `customConstraint` kullanılır.

---

## Tablolar (12 Adet)

### 1. users

Admin ve cashier kullanıcıları.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| name | TEXT | NOT NULL | |
| pin | TEXT | nullable | Tüm operasyonel kullanıcılar PIN ile giriş yapar. Uygulama katmanında hashlenip yazılır. |
| password | TEXT | nullable | Ayrı admin şifre akışı için rezerv alan; aktif operasyon girişi PIN ile yapılır. |
| role | TEXT | NOT NULL, CHECK (role IN ('admin','cashier')) | |
| is_active | BOOLEAN | DEFAULT true | |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Not:** `pin` ve `password` DB'de yalnızca hashlenmiş tutulur.

**UUID:** Yok. Sync edilmeyen yerel sistem tablosu.

---

### 2. categories

Ürün kategorileri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| name | TEXT | NOT NULL | |
| image_url | TEXT | nullable | Supabase Storage URL |
| sort_order | INTEGER | DEFAULT 0 | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 3. products

Satılabilir ürünler.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| category_id | INTEGER | NOT NULL, FK → categories.id | |
| name | TEXT | NOT NULL | |
| price_minor | INTEGER | NOT NULL, CHECK (price_minor >= 0) | Fiyat (pence). £8.50 → 850 |
| image_url | TEXT | nullable | |
| has_modifiers | BOOLEAN | DEFAULT false | |
| is_active | BOOLEAN | DEFAULT true | |
| sort_order | INTEGER | DEFAULT 0 | |

**UUID:** Yok.

---

### 4. product_modifiers

Ürüne bağlı düz modifier seçenekleri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| product_id | INTEGER | NOT NULL, FK → products.id | |
| name | TEXT | NOT NULL | |
| type | TEXT | NOT NULL, CHECK (type IN ('included','extra')) | |
| extra_price_minor | INTEGER | DEFAULT 0, CHECK (extra_price_minor >= 0) | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 5. shifts

Günlük operasyon kaydı.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| opened_by | INTEGER | NOT NULL, FK → users.id | İlk başarılı login ile açan kullanıcı |
| opened_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |
| closed_by | INTEGER | nullable, FK → users.id | Final close yapan admin |
| closed_at | DATETIME | nullable | |
| cashier_previewed_at | DATETIME | nullable | Cashier masked EOD zamanı |
| cashier_previewed_by | INTEGER | nullable, FK → users.id | Cashier masked EOD alan kullanıcı |
| status | TEXT | DEFAULT 'open', CHECK (status IN ('open','closed')) | |

**Kritik Kurallar:**
- Aynı anda SADECE BİR shift açık olabilir.
- Aktif shift yoksa ilk başarılı login (admin veya cashier) shift açar.
- Cashier preview alanları gerçek lifecycle state değildir; operasyonel preview flag'idir.
- Gerçek shift kapanışı sadece admin final close ile olur.

**UUID:** Yok.

---

### 6. transactions

Her sipariş kaydı. State machine: OPEN → PAID | CANCELLED.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| shift_id | INTEGER | NOT NULL, FK → shifts.id | Aktif shift'in ID'si |
| user_id | INTEGER | NOT NULL, FK → users.id | Siparişi oluşturan kullanıcı |
| table_number | INTEGER | nullable | Sipariş anında boş olabilir, sonradan eklenebilir |
| status | TEXT | DEFAULT 'open', CHECK (status IN ('open','paid','cancelled')) | |
| subtotal_minor | INTEGER | DEFAULT 0, CHECK (subtotal_minor >= 0) | Ürün satır toplamları (pence) |
| modifier_total_minor | INTEGER | DEFAULT 0, CHECK (modifier_total_minor >= 0) | Modifier toplamı (pence) |
| total_amount_minor | INTEGER | DEFAULT 0, CHECK (total_amount_minor >= 0) | Son toplam (pence) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |
| paid_at | DATETIME | nullable | |
| updated_at | DATETIME | NOT NULL | |
| cancelled_at | DATETIME | nullable | |
| cancelled_by | INTEGER | nullable, FK → users.id | |
| idempotency_key | TEXT | UNIQUE NOT NULL | |
| kitchen_printed | BOOLEAN | DEFAULT false | |
| receipt_printed | BOOLEAN | DEFAULT false | |

**Kurallar:**
- `subtotal_minor`, `modifier_total_minor`, `total_amount_minor` snapshot'tır.
- Sipariş finalize edilirken `order_service.dart` tarafından tek noktadan hesaplanır.
- `table_number` nullable'dır; masa sipariş anında belli olmayabilir.

**UUID:** Var.

---

### 7. transaction_lines

Sipariş kalemleri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_id | INTEGER | NOT NULL, FK → transactions.id | |
| product_id | INTEGER | NOT NULL, FK → products.id | |
| product_name | TEXT | NOT NULL | Snapshot |
| unit_price_minor | INTEGER | NOT NULL, CHECK (unit_price_minor >= 0) | Snapshot |
| quantity | INTEGER | DEFAULT 1, CHECK (quantity > 0) | |
| line_total_minor | INTEGER | NOT NULL, CHECK (line_total_minor >= 0) | `unit_price_minor * quantity + modifier extra'lar` |

**UUID:** Var.

---

### 8. order_modifiers

Sipariş modifier snapshot'ları.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_line_id | INTEGER | NOT NULL, FK → transaction_lines.id | |
| action | TEXT | NOT NULL, CHECK (action IN ('remove','add')) | |
| item_name | TEXT | NOT NULL | Snapshot |
| extra_price_minor | INTEGER | DEFAULT 0, CHECK (extra_price_minor >= 0) | Snapshot |

**UUID:** Var.

---

### 9. payments

Ödeme kaydı. Transaction başına TAM OLARAK BİR payment.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_id | INTEGER | UNIQUE NOT NULL, FK → transactions.id | |
| method | TEXT | NOT NULL, CHECK (method IN ('cash','card')) | |
| amount_minor | INTEGER | NOT NULL, CHECK (amount_minor > 0) | |
| paid_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Kurallar:**
- `payments.amount_minor == transactions.total_amount_minor`
- `transaction.status != OPEN` ise payment INSERT reddedilir
- Payment + PAID transition aynı DB transaction içinde gerçekleşir

**UUID:** Var.

---

### 10. report_settings

Cashier-visible Z report projection ayarı.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| cashier_report_mode | TEXT | NOT NULL, DEFAULT 'percentage', CHECK (cashier_report_mode IN ('percentage','cap_amount')) | Cashier projection modu |
| visibility_ratio | REAL | DEFAULT 1.0, CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0) | `percentage` modunda görünür oran |
| max_visible_total_minor | INTEGER | nullable, CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0) | `cap_amount` modunda görünür üst toplam |
| business_name | TEXT | nullable | Rapor başlığında gösterilecek işletme adı |
| business_address | TEXT | nullable | Rapor başlığında gösterilecek işletme adresi |
| updated_by | INTEGER | nullable, FK → users.id | |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Kullanım:**
- Admin gerçek raporu görür.
- Cashier, admin policy'sine göre projekte edilmiş Z report görür.
- Aynı projection policy payment breakdown ve category breakdown için de kullanılır.
- Presentation katmanında projection hesaplaması yapılmaz.

**UUID:** Yok.

---

### Cashier Z Report Projection Rules

- Cashier Z report gerçek Z report iskeletine benzeyebilir; bu güvenlik ihlali değildir.
- İşletme adı, adres, tarih, saat, shift no ve operator adı gibi kimlik alanları gerçek değerlerle gösterilebilir.
- Parasal alanlar projection policy ile üretilir.
- Payment breakdown ve category breakdown tutarlı yeniden dağıtılmalıdır.
- Quantity veya admin-only accounting alanları cashier görünümünde zorunlu değildir; sızıntı riski varsa gösterilmez.

### 11. printer_settings

Bluetooth ESC/POS printer konfigürasyonu.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| device_name | TEXT | NOT NULL | |
| device_address | TEXT | NOT NULL | |
| paper_width | INTEGER | DEFAULT 80, CHECK (paper_width IN (58,80)) | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 12. sync_queue

Offline-first sync kuyruğu.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| table_name | TEXT | NOT NULL, CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')) | |
| record_uuid | TEXT | NOT NULL | |
| operation | TEXT | NOT NULL, DEFAULT 'upsert', CHECK (operation IN ('upsert')) | |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |
| status | TEXT | NOT NULL, DEFAULT 'pending', CHECK (status IN ('pending','processing','synced','failed')) | |
| attempt_count | INTEGER | NOT NULL, DEFAULT 0 | |
| last_attempt_at | DATETIME | nullable | |
| synced_at | DATETIME | nullable | |
| error_message | TEXT | nullable | |

**Kurallar:**
- OPEN transaction'lar sync edilmez.
- PAID ve CANCELLED transaction'lar sync edilir.

**UUID:** Yok.

---

## UUID Özeti

| Tablo | UUID | Sync |
|-------|------|------|
| users | ❌ | ❌ |
| categories | ❌ | ❌ |
| products | ❌ | ❌ |
| product_modifiers | ❌ | ❌ |
| shifts | ❌ | ❌ |
| transactions | ✅ | ✅ |
| transaction_lines | ✅ | ✅ |
| order_modifiers | ✅ | ✅ |
| payments | ✅ | ✅ |
| report_settings | ❌ | ❌ |
| printer_settings | ❌ | ❌ |
| sync_queue | ❌ | ❌ |

---

## Index'ler

```text
idx_products_category       → products(category_id, is_active, sort_order)
idx_product_modifiers_prod  → product_modifiers(product_id, is_active)
idx_transactions_shift      → transactions(shift_id, status, created_at)
idx_transactions_user       → transactions(user_id, created_at)
idx_transaction_lines_tx    → transaction_lines(transaction_id)
idx_order_modifiers_line    → order_modifiers(transaction_line_id)
idx_payments_tx             → payments(transaction_id)
idx_shifts_status           → shifts(status, opened_at)
idx_sync_queue_status       → sync_queue(status, created_at)
```

---

## CHECK Constraint Özeti

```sql
-- users
CHECK (role IN ('admin','cashier'))

-- products
CHECK (price_minor >= 0)

-- product_modifiers
CHECK (type IN ('included','extra'))
CHECK (extra_price_minor >= 0)

-- shifts
CHECK (status IN ('open','closed'))

-- transactions
CHECK (status IN ('open','paid','cancelled'))
CHECK (subtotal_minor >= 0)
CHECK (modifier_total_minor >= 0)
CHECK (total_amount_minor >= 0)

-- transaction_lines
CHECK (unit_price_minor >= 0)
CHECK (quantity > 0)
CHECK (line_total_minor >= 0)

-- order_modifiers
CHECK (action IN ('remove','add'))
CHECK (extra_price_minor >= 0)

-- payments
CHECK (method IN ('cash','card'))
CHECK (amount_minor > 0)

-- report_settings
CHECK (cashier_report_mode IN ('percentage','cap_amount'))
CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0)
CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0)

-- printer_settings
CHECK (paper_width IN (58,80))

-- sync_queue
CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments'))
CHECK (operation IN ('upsert'))
CHECK (status IN ('pending','processing','synced','failed'))
```

---

## Drift Implementasyon Notları

### Para alanları Drift'te nasıl yazılır:
```dart
IntColumn get priceMinor => integer()();
IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();
```

### CHECK constraint Drift'te nasıl yazılır:
```dart
TextColumn get role => text()
    .customConstraint("NOT NULL CHECK (role IN ('admin','cashier'))")();

TextColumn get status => text()
    .withDefault(const Constant('open'))
    .customConstraint("NOT NULL CHECK (status IN ('open','paid','cancelled'))")();

IntColumn get totalAmountMinor => integer()
    .withDefault(const Constant(0))
    .customConstraint('NOT NULL CHECK (total_amount_minor >= 0)')();
```

### UNIQUE alanlar:
```text
transactions.uuid            → UNIQUE NOT NULL
transactions.idempotency_key → UNIQUE NOT NULL
transaction_lines.uuid       → UNIQUE NOT NULL
order_modifiers.uuid         → UNIQUE NOT NULL
payments.uuid                → UNIQUE NOT NULL
payments.transaction_id      → UNIQUE NOT NULL
```

---

## Kapsam Dışı — BİLİNÇLİ OLARAK DAHİL EDİLMEDİ

- `partially_paid` durumu
- Çoklu payment akışı
- Order type / takeaway / delivery ayrımı
- Modifier group yapısı
- Çoklu printer mimarisi
- Tax / VAT / discount / service charge
- Payment'ta `status`, `reference`, `provider`
- Müşteri adı alanı (open orders için bilinçli olarak kullanılmaz)

---

## Schema Değişiklik Prosedürü

```text
1. Migration planı çıkar: tablo, alan, constraint, mevcut veriye etki.
2. Destructive değişikliklerde explicit onay al.
3. schemaVersion artırma + migration dosyası oluşturma TEK ADIMDA.
4. Migration'da hem UP hem rollback stratejisi belirt.
5. app_database.dart güncellemesi migration dosyasından SONRA.
```
