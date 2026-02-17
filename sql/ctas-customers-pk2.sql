CREATE TABLE `customers_pk2` (
  PRIMARY KEY(`account_number`) NOT ENFORCED,
  WATERMARK FOR `created_at` AS `created_at` - INTERVAL '5' SECONDS
)
  WITH ('changelog.mode' = 'upsert')
AS SELECT * FROM `customers_faker2`