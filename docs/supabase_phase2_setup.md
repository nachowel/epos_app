# Supabase Mirror Phase 2 Setup

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

## Repo state after the two-phase split

Repo artık iki ayrı artifact taşır:

- baseline schema truth:
  [`supabase/phase1_sales_sync_foundation.sql`](/c:/Users/nacho/Desktop/EPOS/epos_app/supabase/phase1_sales_sync_foundation.sql)
- trusted-only enforcement migration:
  [`supabase/migrations/20260330130000_trusted_only_mirror_writes.sql`](/c:/Users/nacho/Desktop/EPOS/epos_app/supabase/migrations/20260330130000_trusted_only_mirror_writes.sql)

Bu ayrım bilinçlidir:

- baseline dosyası current live physical schema shape’ini anlatır
- hardening migration davranış değişimini getirir
- kör apply yerine kontrollü rollout hedeflenir

Repo-level hazırlık tamamlanmış olsa da canlı ortamda enforcement ancak migration apply edilince gerçek olur.

## Current trusted write path

Önerilen ve korunmuş write yolu şudur:

- `SyncWorker`
- `SyncRemoteGateway`
- `SupabaseSyncService`
- `TrustedSupabaseMirrorWriter`
- `supabase/functions/mirror-transaction-graph`

Client finalized local transaction graph’i üretir.
Remote write kararı local tarafta verilir.
Edge Function service-role ile mirror tablolarına upsert yapar.

Bu mimaride:

- local transaction/payment lifecycle authority değişmez
- remote business authority üretmez
- trusted function yalnız mirror write boundary olarak kalır

## What the hardening migration changes

[`supabase/migrations/20260330130000_trusted_only_mirror_writes.sql`](/c:/Users/nacho/Desktop/EPOS/epos_app/supabase/migrations/20260330130000_trusted_only_mirror_writes.sql)
şunları yapar:

- mirror tablolarda RLS’in açık kaldığını garanti eder
- live audit’te görülen permissive write policy’leri güvenli şekilde düşürür
- `anon` ve `authenticated` rollerinden direct table privileges’i kaldırır
- trusted function path’i bozmaz çünkü function service-role ile yazar

Hedef sonuç:

- anon direct `insert` fail
- anon direct `update` fail
- authenticated direct `insert` fail
- authenticated direct `update` fail
- `mirror-transaction-graph` invoke sonrası write devam eder

Kısa hali:

> Trusted function artık hedeflenen tek remote write yoludur, ama bu ancak hardening migration canlıya apply edilince fiilen enforce edilir.

## Policies removed by the hardening migration

Migration özellikle şu permissive write policy’leri `drop policy if exists` ile temizler:

- `transactions_insert_sync`
- `transactions_update_sync`
- `transaction_lines_insert_sync`
- `transaction_lines_update_sync`
- `order_modifiers_insert_sync`
- `order_modifiers_update_sync`
- `payments_insert_sync`
- `payments_update_sync`

Burada yeni client write policy üretilmez.
Amaç yalnız mevcut permissive direct write surface’i kapatmaktır.

## Grants tightened by the hardening migration

Migration şu tablolarda `anon` ve `authenticated` için direct privileges’i kapatır:

- `transactions`
- `transaction_lines`
- `order_modifiers`
- `payments`

Yaklaşım:

- `revoke all privileges ... from anon, authenticated`

Bu mirror tablolar için client direct `select/insert/update/delete` yüzeyini daraltır.
Health/readiness kontrolü doğrudan client table read ile değil `mirror-health` function’ı ile devam eder.

## Why the trusted function is not affected

`mirror-transaction-graph` ve `mirror-health` function’ları şu secret ile server-side client kurar:

- `SUPABASE_SERVICE_ROLE_KEY`

Bu nedenle:

- anon/authenticated policy/grant daralması function path’i bozmaz
- function service-role ile mirror tabloya erişmeye devam eder
- client-side direct writer ise hardening apply sonrası canlıda başarısız olur

Bu istenen davranıştır.

## Baseline schema file

[`supabase/phase1_sales_sync_foundation.sql`](/c:/Users/nacho/Desktop/EPOS/epos_app/supabase/phase1_sales_sync_foundation.sql)
hala current live mirror schema baseline’ını temsil eder.

Bu dosya:

- UUID/FK tiplerini
- finalized-only transaction status domain’ini
- `transactions.synced_at`
- live-style transaction guardrail trigger’ını
- mevcut fiziksel tablo/index şeklini

anlatır.

Bu dosya özellikle şunu yapmaz:

- trusted-only enforcement’i gömmez
- client direct write closure’ı baseline içine karıştırmaz
- behavior change migration rolünü üstlenmez

## Draft baseline migration artifact

[`supabase/migrations/20260330120000_live_mirror_schema_baseline_draft.sql`](/c:/Users/nacho/Desktop/EPOS/epos_app/supabase/migrations/20260330120000_live_mirror_schema_baseline_draft.sql)
yalnız schema alignment taslağı olarak kalır.

Bu dosya security migration değildir.
Direct write closure getirmez.

## Environment recommendation

Uygulama config’i artık root `.env` dosyasından yüklenir. `flutter run`
tek başına yeterlidir.

Gerekli env anahtarları:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `EPOS_INTERNAL_API_KEY`
- `FEATURE_SYNC_ENABLED`

Önerilen ek değer:

- `SYNC_MIRROR_WRITE_MODE=trusted_sync_boundary`

Production’da direct mode zaten uygulama seviyesinde geçerli write path olarak
kabul edilmez. Hardening migration apply edildiğinde DB tarafı da bu kararı
enforce eder.

## Manual verification after live apply

### 1. RLS durumu

SQL Editor:

```sql
select
  schemaname,
  tablename,
  rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments'
  )
order by tablename;
```

Beklenen:

- tüm mirror tablolarında `rowsecurity = true`

### 2. Policy temizliği

SQL Editor:

```sql
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename in (
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments'
  )
order by tablename, policyname;
```

Beklenen:

- yukarıdaki `*_insert_sync` ve `*_update_sync` policy’leri görünmez
- anon/authenticated için permissive write policy kalmaz

### 3. Grant daralması

SQL Editor:

```sql
select
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments'
  )
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;
```

Beklenen:

- `INSERT`
- `UPDATE`
- `DELETE`

satırları görünmez.
İdeal olarak mirror tablo direct privilege satırı kalmaz.

### 4. Anon direct insert fail

HTTP örneği:

```powershell
$headers = @{
  apikey = "<SUPABASE_ANON_KEY>"
  Authorization = "Bearer <SUPABASE_ANON_KEY>"
  "Content-Type" = "application/json"
  Prefer = "return=representation"
}

$body = @'
[
  {
    "uuid": "aaaaaaaa-1111-1111-1111-111111111111",
    "shift_local_id": 1,
    "user_local_id": 1,
    "table_number": null,
    "status": "paid",
    "subtotal_minor": 1000,
    "modifier_total_minor": 0,
    "total_amount_minor": 1000,
    "created_at": "2026-03-30T12:00:00Z",
    "paid_at": "2026-03-30T12:05:00Z",
    "updated_at": "2026-03-30T12:05:00Z",
    "cancelled_at": null,
    "cancelled_by_local_id": null,
    "kitchen_printed": false,
    "receipt_printed": false
  }
]
'@

Invoke-RestMethod `
  -Method Post `
  -Uri "https://<PROJECT_REF>.supabase.co/rest/v1/transactions" `
  -Headers $headers `
  -Body $body
```

Beklenen:

- `401` / `403` / privilege-RLS failure
- direct table write başarıyla dönmemeli

### 5. Anon direct update fail

HTTP örneği:

```powershell
$headers = @{
  apikey = "<SUPABASE_ANON_KEY>"
  Authorization = "Bearer <SUPABASE_ANON_KEY>"
  "Content-Type" = "application/json"
}

$body = @'
{
  "receipt_printed": true
}
'@

Invoke-RestMethod `
  -Method Patch `
  -Uri "https://<PROJECT_REF>.supabase.co/rest/v1/transactions?uuid=eq.<EXISTING_UUID>" `
  -Headers $headers `
  -Body $body
```

Beklenen:

- `401` / `403` / privilege-RLS failure
- existing row update edilememeli

### 6. Trusted function write still works

HTTP örneği:

```powershell
$headers = @{
  apikey = "<SUPABASE_ANON_KEY>"
  Authorization = "Bearer <SUPABASE_ANON_KEY>"
  "Content-Type" = "application/json"
}

$body = @'
{
  "payload_version": 1,
  "transaction_uuid": "11111111-1111-1111-1111-111111111111",
  "transaction_idempotency_key": "idem-11111111",
  "generated_at": "2026-03-30T12:10:00Z",
  "transaction": {
    "uuid": "11111111-1111-1111-1111-111111111111",
    "shift_local_id": 1,
    "user_local_id": 1,
    "table_number": null,
    "status": "paid",
    "subtotal_minor": 1000,
    "modifier_total_minor": 0,
    "total_amount_minor": 1000,
    "created_at": "2026-03-30T12:00:00Z",
    "paid_at": "2026-03-30T12:05:00Z",
    "updated_at": "2026-03-30T12:05:00Z",
    "cancelled_at": null,
    "cancelled_by_local_id": null,
    "kitchen_printed": false,
    "receipt_printed": false
  },
  "transaction_lines": [],
  "order_modifiers": [],
  "payment": {
    "uuid": "22222222-2222-2222-2222-222222222222",
    "transaction_uuid": "11111111-1111-1111-1111-111111111111",
    "method": "card",
    "amount_minor": 1000,
    "paid_at": "2026-03-30T12:05:00Z"
  }
}
'@

Invoke-RestMethod `
  -Method Post `
  -Uri "https://<PROJECT_REF>.supabase.co/functions/v1/mirror-transaction-graph" `
  -Headers $headers `
  -Body $body
```

Beklenen:

- response `ok: true`
- transaction/payment row’ları mirror’da yazılmaya devam eder

## Operational note

Bu repo değişikliği hardening’i hazırlar.
Canlı ortamda trusted-only enforcement ancak şu sıra ile güvenle tamamlanır:

1. baseline doğru mu doğrula
2. edge functions deploy ve secret’ları doğrula
3. hardening migration’ı kontrollü apply et
4. yukarıdaki verification bloklarını çalıştır

Trusted path works, but enforcement is only real after the live migration is applied.
