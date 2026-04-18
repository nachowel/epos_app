-- Manual remote mirror drift check.
-- Compare this output against lib/data/sync/mirror_schema_contract.dart.
-- Release rule: if mirror payload changes, deploy the matching Supabase
-- migration before releasing the app build that emits the new payload.

select
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'transactions',
    'transaction_lines',
    'order_modifiers',
    'payments'
  )
order by table_name, ordinal_position;
