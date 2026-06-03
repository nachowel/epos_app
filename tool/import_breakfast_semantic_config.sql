-- Import breakfast semantic menu configuration from a known-good EPOS SQLite
-- database into the currently opened target database.
--
-- Usage:
--   1. Back up the target EPOS database first.
--   2. Open the target database with sqlite3:
--        sqlite3 "C:/Users/<user>/Documents/epos.sqlite"
--   3. Edit the ATTACH path below to point at the Work PC backup/export.
--   4. Run:
--        .read tool/import_breakfast_semantic_config.sql
--
-- Scope:
--   - categories named Set Breakfast or Healthy Breakfast
--   - set_items rows for matching root products
--   - modifier_groups rows for matching root products
--   - product_modifiers choice rows for matching root products
--   - product_modifiers explicit semantic extra-pool rows for matching roots
--   - menu_settings free_swap_limit and max_swaps
--
-- Product matching is by category name + product name so the target database
-- can have different numeric product IDs.

ATTACH 'C:/PATH/TO/WORK-PC/epos.sqlite' AS source;

BEGIN;

CREATE TEMP TABLE import_breakfast_root_map (
  source_product_id INTEGER NOT NULL,
  target_product_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  category_name TEXT NOT NULL
);

INSERT INTO import_breakfast_root_map (
  source_product_id,
  target_product_id,
  product_name,
  category_name
)
SELECT
  sp.id,
  tp.id,
  sp.name,
  sc.name
FROM source.products sp
INNER JOIN source.categories sc ON sc.id = sp.category_id
INNER JOIN categories tc ON tc.name = sc.name
INNER JOIN products tp ON tp.category_id = tc.id AND tp.name = sp.name
WHERE sc.name IN ('Set Breakfast', 'Healthy Breakfast')
  AND (
    EXISTS (SELECT 1 FROM source.set_items si WHERE si.product_id = sp.id)
    OR EXISTS (
      SELECT 1 FROM source.modifier_groups sg WHERE sg.product_id = sp.id
    )
    OR EXISTS (
      SELECT 1
      FROM source.product_modifiers sm
      WHERE sm.product_id = sp.id AND sm.type = 'choice'
    )
  );

CREATE TEMP TABLE import_breakfast_product_map (
  source_product_id INTEGER NOT NULL,
  target_product_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  category_name TEXT NOT NULL
);

INSERT INTO import_breakfast_product_map (
  source_product_id,
  target_product_id,
  product_name,
  category_name
)
SELECT sp.id, tp.id, sp.name, sc.name
FROM source.products sp
INNER JOIN source.categories sc ON sc.id = sp.category_id
INNER JOIN categories tc ON tc.name = sc.name
INNER JOIN products tp ON tp.category_id = tc.id AND tp.name = sp.name;

DELETE FROM product_modifiers
WHERE product_id IN (
    SELECT target_product_id FROM import_breakfast_root_map
  )
  AND (
    type = 'choice'
    OR (type = 'extra' AND item_product_id IS NOT NULL)
  );

DELETE FROM modifier_groups
WHERE product_id IN (
  SELECT target_product_id FROM import_breakfast_root_map
);

DELETE FROM set_items
WHERE product_id IN (
  SELECT target_product_id FROM import_breakfast_root_map
);

INSERT INTO set_items (
  product_id,
  item_product_id,
  is_removable,
  default_quantity,
  sort_order
)
SELECT
  roots.target_product_id,
  items.target_product_id,
  si.is_removable,
  si.default_quantity,
  si.sort_order
FROM source.set_items si
INNER JOIN import_breakfast_root_map roots
  ON roots.source_product_id = si.product_id
INNER JOIN import_breakfast_product_map items
  ON items.source_product_id = si.item_product_id;

INSERT INTO modifier_groups (
  product_id,
  name,
  min_select,
  max_select,
  included_quantity,
  sort_order
)
SELECT
  roots.target_product_id,
  sg.name,
  sg.min_select,
  sg.max_select,
  sg.included_quantity,
  sg.sort_order
FROM source.modifier_groups sg
INNER JOIN import_breakfast_root_map roots
  ON roots.source_product_id = sg.product_id;

CREATE TEMP TABLE import_breakfast_group_map (
  source_group_id INTEGER NOT NULL,
  target_group_id INTEGER NOT NULL
);

INSERT INTO import_breakfast_group_map (source_group_id, target_group_id)
SELECT sg.id, tg.id
FROM source.modifier_groups sg
INNER JOIN import_breakfast_root_map roots
  ON roots.source_product_id = sg.product_id
INNER JOIN modifier_groups tg
  ON tg.product_id = roots.target_product_id AND tg.name = sg.name;

INSERT INTO product_modifiers (
  product_id,
  group_id,
  item_product_id,
  name,
  type,
  extra_price_minor,
  price_behavior,
  ui_section,
  is_active
)
SELECT
  roots.target_product_id,
  groups.target_group_id,
  items.target_product_id,
  sm.name,
  sm.type,
  sm.extra_price_minor,
  sm.price_behavior,
  sm.ui_section,
  sm.is_active
FROM source.product_modifiers sm
INNER JOIN import_breakfast_root_map roots
  ON roots.source_product_id = sm.product_id
INNER JOIN import_breakfast_group_map groups
  ON groups.source_group_id = sm.group_id
LEFT JOIN import_breakfast_product_map items
  ON items.source_product_id = sm.item_product_id
WHERE sm.type = 'choice'
  AND (sm.item_product_id IS NULL OR items.target_product_id IS NOT NULL);

INSERT INTO product_modifiers (
  product_id,
  group_id,
  item_product_id,
  name,
  type,
  extra_price_minor,
  price_behavior,
  ui_section,
  is_active
)
SELECT
  roots.target_product_id,
  NULL,
  items.target_product_id,
  sm.name,
  sm.type,
  sm.extra_price_minor,
  sm.price_behavior,
  sm.ui_section,
  sm.is_active
FROM source.product_modifiers sm
INNER JOIN import_breakfast_root_map roots
  ON roots.source_product_id = sm.product_id
INNER JOIN import_breakfast_product_map items
  ON items.source_product_id = sm.item_product_id
WHERE sm.type = 'extra'
  AND sm.item_product_id IS NOT NULL;

UPDATE menu_settings
SET
  free_swap_limit = (
    SELECT free_swap_limit
    FROM source.menu_settings
    ORDER BY id ASC
    LIMIT 1
  ),
  max_swaps = (
    SELECT max_swaps
    FROM source.menu_settings
    ORDER BY id ASC
    LIMIT 1
  ),
  updated_at = unixepoch()
WHERE id = (SELECT id FROM menu_settings ORDER BY id ASC LIMIT 1);

COMMIT;

SELECT
  roots.category_name,
  roots.product_name,
  (SELECT COUNT(*) FROM set_items si WHERE si.product_id = roots.target_product_id)
    AS set_item_count,
  (SELECT COUNT(*) FROM modifier_groups mg WHERE mg.product_id = roots.target_product_id)
    AS choice_group_count,
  (
    SELECT COUNT(*)
    FROM product_modifiers pm
    WHERE pm.product_id = roots.target_product_id
      AND pm.type = 'choice'
      AND pm.item_product_id IS NOT NULL
  ) AS choice_member_count,
  (
    SELECT COUNT(*)
    FROM product_modifiers pm
    WHERE pm.product_id = roots.target_product_id
      AND pm.type = 'extra'
      AND pm.item_product_id IS NOT NULL
  ) AS extra_pool_count
FROM import_breakfast_root_map roots
ORDER BY roots.category_name, roots.product_name;

DETACH source;
