CREATE TABLE `customers_pk2` (
    account_number STRING NOT NULL,
    customer_name STRING,
    email STRING,
    phone_number STRING,
    date_of_birth TIMESTAMP(3),
    city STRING,
    created_at TIMESTAMP(3) WITH LOCAL TIME ZONE,
    PRIMARY KEY(`account_number`) NOT ENFORCED,
    WATERMARK FOR `created_at` AS `created_at` - INTERVAL '5' SECONDS
 )
