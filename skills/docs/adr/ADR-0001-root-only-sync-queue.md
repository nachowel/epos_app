# ADR-0001 Root-Only Sync Queue

## Status

Accepted

## Context

EPOS sync local-first çalışır:

- Drift/SQLite operational truth kaynağıdır
- Supabase sadece remote mirror sink’tir
- sync edilen graph: `transactions`, `transaction_lines`, `order_modifiers`, `payments`

Terminal bir transaction sync edilirken queue yalnız root `transactions` event’ini taşır.
Child tablolar queue’ya ayrı event olarak yazılmaz.
Worker sync anında child graph’i local DB’den rebuild eder.

## Decision

Queue tasarımı root-only kalır:

- queue item = `transactions` + `transaction.uuid`
- worker graph’i local DB snapshot’ından rebuild eder
- remote write sırası dependency order ile yürür:
  `transactions -> transaction_lines -> order_modifiers -> payments`

## Why

- Tek root event ile retry daha deterministik kalır.
- Child row’lar immutable snapshot gibi ele alınabildiği için local graph yeniden üretilebilir.
- Queue cardinality düşer; aynı transaction için çoklu child event patlaması engellenir.
- Partial failure sonrası retry, child event setini reconcile etmek yerine aynı root graph’i yeniden oynatır.

## Benefits

- Duplicate replay idempotency daha sade doğrulanır.
- Queue monitor’da bir transaction için tek root kayıt görmek daha anlaşılırdır.
- Child row order/fan-out problemi worker içinde merkezi olarak çözülür.
- Remote partial write sonrası eksik parçalar aynı transaction root’u ile tamamlanabilir.

## Risks

- Root queue item varken child local data bozulursa retry aynı root üzerinden tekrar başarısız olur.
- Queue tek başına child-level intent’i göstermez; debug için graph rebuild bilgisi gerekir.
- Büyük transaction graph’lerinde tek retry tüm graph’i yeniden oynatır.

## Retry and Debug Impact

- Retry unit’i tek child row değil, tüm finalized transaction graph’tir.
- Başarısızlık gözlemi için loglarda `table_name`, `record_uuid`, `failure_type`, `retryable`, `issues` taşınmalıdır.
- Queue `error_message` child payload yerine graph-level failure özetini taşır.

## Why Not Child Queue Events

- Child queue events ordering problemi üretir.
- Aynı transaction için line/modifier/payment event’leri ayrı retry state’lere dağılır.
- Partial success sonrası hangi child event’in authoritative olduğu daha karmaşık hale gelir.
- Root-only model, local DB authoritative olduğu için child event duplication ihtiyacını azaltır.

## Consequence

Bu tasarımın en büyük kırılganlığı, retry sırasında her seferinde local graph rebuild’e bağımlı olmasıdır.
Bu nedenle local terminal graph’in immutable kalması ve failure observability’nin güçlü olması kritik kabul edilir.
