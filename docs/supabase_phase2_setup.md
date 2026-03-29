# Supabase Mirror Security Setup

## Architecture recap

- POS operasyonel olarak local çalışır.
- Drift/SQLite tek operational truth kaynağıdır.
- Supabase yalnızca mirror + reporting katmanıdır.
- Sync yönü yalnızca `local -> remote mirror` olur.
- Remote local state’i geri yazmaz.
- Trusted server-side writer business authority değildir; yalnız mirror writer’dır.

Bu entegrasyon yalnızca şu 4 tabloyla sınırlıdır:

- `transactions`
- `transaction_lines`
- `order_modifiers`
- `payments`

## Current trusted write path

Normal ve önerilen write yolu artık şudur:

- `SyncWorker`
- `SyncRemoteGateway`
- `SupabaseSyncService`
- `TrustedSupabaseMirrorWriter`
- `supabase/functions/mirror-transaction-graph`

Client finalized local transaction graph’i üretir.
Remote write kararı local tarafta verilir.
Server-side function yalnız mirror tabloya UUID bazlı upsert yapar.

## Direct client write status

`DirectSupabaseMirrorWriter` hâlâ kod tabanında vardır, ancak normal production yolu değildir.

Bu fazdan sonra:

- varsayılan mode `trusted_sync_boundary`
- `direct_mirror_write` yalnız açıkça seçilirse dev/non-prod amaçlı düşünülebilir
- production environment içinde direct mode engellenir
- trusted mode başarısızsa direct writer’a fallback yapılmaz

Önemli:

- Bu hardened SQL ile direct client table write artık çalışmamalıdır
- direct writer yalnız test/dev wiring veya geçici kontrollü ortamlarda anlamlıdır

## What was tightened in this phase

- varsayılan sync write mode trusted boundary oldu
- production’da direct client write config’i reddediliyor
- remote health check artık doğrudan tablo select ile değil, read-only server-side probe ile çalışıyor
- mirror tablolarında RLS etkinleştirildi
- anon/authenticated direct table privileges kaldırıldı
- trusted server-side function service-role ile yazmaya devam eder

## SQL setup

[`supabase/phase1_sales_sync_foundation.sql`](/abs/path/C:/Users/nacho/Desktop/EPOS/epos_app/supabase/phase1_sales_sync_foundation.sql)
şunları yapar:

- 4 remote mirror tabloyu oluşturur
- UUID tabanlı ilişkileri kurar
- `last_received_at` trigger mantığını ekler
- index’leri ekler
- RLS’i etkinleştirir
- anon/authenticated direct table grants’i kaldırır

Uygulama adımları:

1. Supabase dashboard’u açın.
2. `SQL Editor` bölümüne gidin.
3. SQL dosyasının tamamını kopyalayın.
4. Editor içine yapıştırın.
5. Script’i çalıştırın.
6. Şu tablo ve güvenlik durumlarını doğrulayın:
   - `transactions`
   - `transaction_lines`
   - `order_modifiers`
   - `payments`
   - RLS enabled
   - anon/authenticated direct `select/insert/update/delete` yok

Script tekrar çalıştırılabilir yapıdadır.

## Edge Functions

Trusted path için iki function beklenir:

- `mirror-transaction-graph`
- `mirror-health`

Deploy:

```powershell
supabase functions deploy mirror-transaction-graph
supabase functions deploy mirror-health
```

Bu function’ların server-side environment’ında şu secret’lar erişilebilir olmalıdır:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Function davranışı:

- `mirror-transaction-graph`
  - finalized graph validate eder
  - transaction -> lines -> modifiers -> payment sırasıyla upsert yapar
  - idempotent UUID write mantığını korur
- `mirror-health`
  - read-only kontrol yapar
  - gerekli mirror tablolarının hazır olup olmadığını döner

## Environment ayarları

Gerekli `dart-define` değerleri:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SYNC_MIRROR_WRITE_MODE`

Önerilen değer:

- `SYNC_MIRROR_WRITE_MODE=trusted_sync_boundary`

PowerShell örneği:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key `
  --dart-define=SYNC_MIRROR_WRITE_MODE=trusted_sync_boundary
```

Supabase tanımlı değilse uygulama local çalışmaya devam eder.

## Health check / probe

Health check read-only kalır.
Startup’ı bloklamaz.
Write auth garantisi vermez.

```dart
final SupabaseConnectionStatus status = await ref
    .read(supabaseConnectionServiceProvider)
    .runDebugReadOnlyProbe();
```

Bu probe artık `mirror-health` function’ı üzerinden şu soruya cevap verir:

> Remote mirror ulaşılabilir mi ve gerekli mirror tabloları hazır mı?

Probe şunları doğrular:

- config geçerli mi
- trusted read-only probe çağrılabiliyor mu
- gerekli tablolar var mı
- tablo erişim durumu function tarafından okunabiliyor mu

Probe şunları doğrulamaz:

- write path’in production’da eksiksiz hardened olduğu
- Edge Function deployment dışı tüm auth/policy detaylarının kusursuz olduğu

## RLS / grants current state

Bu fazdaki amaç “RLS varmış gibi görünmek” değil, direct surface’i gerçekten daraltmaktır.

Şu anki hedef durum:

- mirror tablolarında RLS enabled
- anon/authenticated için direct table policy yok
- anon/authenticated direct table grants yok
- service-role ile çalışan Edge Function mirror write yapabiliyor

Yani normal client artık tabloya doğrudan yazmamalıdır.

## Production recommendation

Production için önerilen tek write yolu:

- `trusted_sync_boundary`

Production’da önerilmeyen yol:

- `direct_mirror_write`

Production environment içinde direct mode seçilirse uygulama bunu geçerli sync write path olarak kabul etmez.

## Dev/debug exception path

Direct writer tamamen silinmiş değildir.

Kalan rolü:

- test harness
- kontrollü non-production deneyler
- eski geçiş senaryoları

Ama hardened SQL ile birlikte bu yolun normal Supabase mirror ortamında çalışması beklenmemelidir.

## Domain alignment

Remote mirror `transactions.status` domain’i:

- `open`
- `paid`
- `cancelled`

Local `draft` ve `sent` durumları remote authority üretmez.
Sync worker hâlâ yalnız finalized local kayıtları mirror’a yollar.

## What still remains for full hardening

Bu faz önemli bir sıkılaştırma yapar, ama full production-complete security değildir.

Hâlâ kalan işler:

- direct writer’ın uygulamadan tamamen kaldırılması
- Edge Function deployment ve secret yönetiminin operasyonel olarak doğrulanması
- gerekiyorsa function invocation tarafında daha sıkı auth modeli
- Supabase tarafında ek audit/monitoring

## Next security phase

Bir sonraki mantıklı faz:

- direct writer’ı app runtime’dan tamamen çıkarmak
- trusted boundary dışındaki write path’leri tamamen kapatılmış kabul etmek
- function-side operational monitoring ve rotation/hardening eklemek
