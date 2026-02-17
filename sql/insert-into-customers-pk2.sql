INSERT INTO
    `customers_pk2`
SELECT
    `account_number`,
    `customer_name`,
    `email`,
    `phone_number`,
    `date_of_birth`,
    `city`,
    `created_at`
FROM
    `customers_faker2`
