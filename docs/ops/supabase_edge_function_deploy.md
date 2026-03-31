# Supabase Edge Function Deploy

Bu rehber EPOS’un güncellenmiş Edge Function sürümlerini live Supabase projesine
deploy etmek içindir.

Current linked project ref:

- `loxlggkhcqvdxazojbso`

Deploy edilecek function’lar:

- `mirror-transaction-graph`
- `owner-revenue-analytics`

Shared code:

- `supabase/functions/_shared/internal_auth.js`

## Readiness

Repo şu açıdan deploy-ready durumda:

- `mirror-transaction-graph` shared auth guard import ediyor
- `owner-revenue-analytics` auth logic'ini function içinde taşıyor
- shared import path relative olarak doğru:
  - `../_shared/internal_auth.js`
- `supabase/config.toml` mevcut
- extra import map gerekmiyor

## Required secrets

Hosted Supabase Edge Functions ortamında şu secret’lar platform tarafından
default gelir:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Bu repo için manuel set edilmesi gereken custom secret:

- `EPOS_INTERNAL_API_KEY`

Owner analytics notu:

- `owner-revenue-analytics` artık `EPOS_INTERNAL_API_KEY` kullanmaz
- bu function publishable `apikey` ile çağrılır
- gerçek authorization kararı function içindeki `Authorization: Bearer <user_jwt>` doğrulaması + `public.analytics_access_map` allow-list lookup ile verilir
- `apikey` burada yalnız Supabase routing/client access içindir; owner analytics yetkisi vermez

## Remote deploy

PowerShell:

```powershell
Set-Location c:\Users\nacho\Desktop\EPOS\epos_app
supabase login
supabase link --project-ref loxlggkhcqvdxazojbso
```

Custom secret set:

```powershell
$env:EPOS_INTERNAL_API_KEY="<REAL_TRUSTED_BOUNDARY_KEY>"
supabase secrets set EPOS_INTERNAL_API_KEY=$env:EPOS_INTERNAL_API_KEY --project-ref loxlggkhcqvdxazojbso
```

Deploy commands:

```powershell
supabase functions deploy mirror-transaction-graph --project-ref loxlggkhcqvdxazojbso --use-api
supabase functions deploy owner-revenue-analytics --project-ref loxlggkhcqvdxazojbso --use-api
```

Tek seferde kısa komut seti:

```powershell
Set-Location c:\Users\nacho\Desktop\EPOS\epos_app
$env:EPOS_INTERNAL_API_KEY="<REAL_TRUSTED_BOUNDARY_KEY>"
supabase login
supabase link --project-ref loxlggkhcqvdxazojbso
supabase secrets set EPOS_INTERNAL_API_KEY=$env:EPOS_INTERNAL_API_KEY --project-ref loxlggkhcqvdxazojbso
supabase functions deploy mirror-transaction-graph --project-ref loxlggkhcqvdxazojbso --use-api
supabase functions deploy owner-revenue-analytics --project-ref loxlggkhcqvdxazojbso --use-api
```

Not:

- `--use-api` deploy için Docker zorunluluğunu kaldırır
- deploy sonrası Dashboard > Edge Functions üzerinden yeni revision görünmeli

## Local serve smoke

Local serve için pratik yol:

1. Docker açık olsun
2. local stack’i başlat
3. function runtime’ı serve et
4. PowerShell ile smoke request gönder

Bu repo içinde `supabase functions serve` tek başına çalıştırıldığında:

- `supabase start is not running`

Bu yüzden local smoke için önce local stack gerekir.

PowerShell:

```powershell
Set-Location c:\Users\nacho\Desktop\EPOS\epos_app
docker --version
supabase start
```

Custom function env dosyası oluştur:

```powershell
@'
EPOS_INTERNAL_API_KEY=<REAL_TRUSTED_BOUNDARY_KEY>
'@ | Set-Content supabase\functions\.env.local
```

Serve:

```powershell
supabase functions serve --env-file supabase/functions/.env.local --no-verify-jwt
```

Analytics smoke request:

```powershell
$headers = @{
  "Content-Type" = "application/json"
  "apikey" = "<SUPABASE_ANON_KEY>"
  "Authorization" = "Bearer <REAL_SUPABASE_USER_JWT>"
}

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:54321/functions/v1/owner-revenue-analytics" `
  -Headers $headers `
  -Body "{}"
```

Mirror write smoke request:

```powershell
$headers = @{
  "Content-Type" = "application/json"
  "x-epos-internal-key" = "<REAL_TRUSTED_BOUNDARY_KEY>"
}

$body = @'
{
  "payload_version": 1,
  "transaction_uuid": "11111111-1111-1111-1111-111111111111",
  "transaction_idempotency_key": "idem-11111111",
  "generated_at": "2026-03-31T12:10:00Z",
  "transaction": {
    "uuid": "11111111-1111-1111-1111-111111111111",
    "status": "paid",
    "shift_local_id": 1,
    "user_local_id": 1,
    "table_number": null,
    "subtotal_minor": 1000,
    "modifier_total_minor": 0,
    "total_amount_minor": 1000,
    "created_at": "2026-03-31T12:00:00Z",
    "paid_at": "2026-03-31T12:05:00Z",
    "updated_at": "2026-03-31T12:05:00Z",
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
    "paid_at": "2026-03-31T12:05:00Z"
  }
}
'@

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:54321/functions/v1/mirror-transaction-graph" `
  -Headers $headers `
  -Body $body
```

Beklenen:

- analytics request JSON döner
- mirror request `ok: true` döner
- analytics function için `Authorization` zorunludur
- analytics function, publishable key'i auth kararı olarak kullanmaz
- analytics function yalnız active `analytics_access_map` row'u olan user JWT'lerini kabul eder
- mirror function internal key ile çalışmaya devam eder

## Owner analytics auth model

`owner-revenue-analytics` için intentional model:

- `verify_jwt = false`
- gateway implicit auth yerine function-owned auth
- request mutlaka `Authorization: Bearer <real user jwt>` taşır
- function `auth.getUser()` ile token'ı doğrular
- ardından `public.analytics_access_map` içinde active allow-list row arar

Bu model, publishable key tabanlı yeni JWT signing key flow ile uyumludur.

Remote smoke request:

```powershell
$headers = @{
  "Content-Type" = "application/json"
  "apikey" = "<SUPABASE_ANON_KEY>"
  "Authorization" = "Bearer <REAL_SUPABASE_USER_JWT>"
}

Invoke-RestMethod `
  -Method Post `
  -Uri "https://loxlggkhcqvdxazojbso.supabase.co/functions/v1/owner-revenue-analytics" `
  -Headers $headers `
  -Body "{}"
```

Beklenen:

- missing token -> `401`
- invalid token -> `401`
- valid token but no `analytics_access_map` row -> `403`
- valid token with inactive row -> `403`
- valid token with active row -> analytics JSON payload

## Post-deploy verification

Deploy sonrası kısa kontrol:

1. Uygulamayı aç
2. Admin Sync ekranına git
3. Yeni failed item oluşturacak küçük bir paid order sync dene
4. `Invalid Token or Protected Header formatting` hatasının geri gelmediğini doğrula
5. Analytics ekranını aç
6. Revenue analytics response geldiğini doğrula
7. Son error alanında eski formatting hatasının kalmadığını doğrula

Beklenen iyileşme:

- sync screen artık malformed bearer token hatası göstermemeli
- secure function hataları artık ayrışmalı:
  - `auth_header_malformed`
  - `missing_internal_key`
  - `unauthorized_internal_key`

## Why old live functions are incompatible

App artık edge function çağrılarını `x-epos-internal-key` odaklı yeni contract ile
yapıyor ve structured auth failure bekliyor.

Hosted project’te eski function revision kalırsa:

- live runtime yeni auth guard davranışını taşımamış olur
- app ile function contract’ı version-skew durumuna düşer
- deploy edilmemiş eski revision yüzünden troubleshooting yanıltıcı kalır
