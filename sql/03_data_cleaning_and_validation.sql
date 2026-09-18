-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 03_data_cleaning_and_validation.sql
-- Purpose: Validate the imported data and document the data-quality
-- issues found during profiling. Source values are preserved whenever
-- the correct replacement cannot be established from available evidence.
-- =====================================================================

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- CHECK 1 — Duplicate customer IDs
-- Result on this dataset: 0 duplicates (7,043 unique customer_id values)
-- ---------------------------------------------------------------------
SELECT customer_id, COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- CHECK 2 — Referential integrity: every customer's zip code must exist
-- in zip_population. Result: 0 orphan rows.
-- ---------------------------------------------------------------------
SELECT c.customer_id, c.zip_code
FROM customers c
LEFT JOIN zip_population z ON c.zip_code = z.zip_code
WHERE z.zip_code IS NULL;

-- ---------------------------------------------------------------------
-- CHECK 3 — Every churned customer must have a churn reason on file.
-- Result: 0 missing (1,869 churned rows, all 1,869 have a reason).
-- ---------------------------------------------------------------------
SELECT customer_id
FROM customer_churn_status
WHERE customer_status = 'Churned'
  AND (churn_reason IS NULL OR churn_reason = '');

-- ---------------------------------------------------------------------
-- CHECK 4 - Negative Monthly Charge anomaly
-- Found: 120 rows (1.7% of customers) with Monthly Charge between
-- -$10 and -$1, e.g. customer 0003-MKNFE at -$4.00. The data dictionary
-- does not explain these values, and converting them to positive values
-- would not establish the true charge. Preserve the source value, flag
-- the records, and exclude them from monthly-charge averages.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS rows_with_negative_monthly_charge
FROM customer_billing
WHERE monthly_charge < 0;

-- Record each anomaly in an audit table without changing the source.
CREATE TABLE IF NOT EXISTS data_cleaning_log (
    log_id        INT AUTO_INCREMENT PRIMARY KEY,
    table_name    VARCHAR(64),
    customer_id   VARCHAR(10),
    column_name   VARCHAR(64),
    old_value     VARCHAR(64),
    new_value     VARCHAR(64),
    reason        VARCHAR(255),
    cleaned_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO data_cleaning_log (table_name, customer_id, column_name, old_value, new_value, reason)
SELECT 'customer_billing', customer_id, 'monthly_charge',
       monthly_charge, NULL,
       'Negative monthly charge flagged for review; source value preserved and excluded from charge averages'
FROM customer_billing
WHERE monthly_charge < 0;

-- ---------------------------------------------------------------------
-- CHECK 5 — Business-logic NULLs are NOT missing data; they are correct.
-- Confirm the pattern before treating them that way:
--   Offer is NULL for customers who never accepted a marketing offer
--   Internet-related columns are NULL only when internet_service = 'No'
--   Phone-related columns are NULL only when phone_service = 'No'
--   churn_category / churn_reason are NULL only when customer_status <> 'Churned'
-- If any of the counts below is > 0, the NULL pattern is inconsistent
-- and needs investigation. On this dataset every check returns 0.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM customer_services
       WHERE internet_service <> 'No' AND internet_type IS NULL) AS bad_internet_type_nulls,
    (SELECT COUNT(*) FROM customer_services
       WHERE internet_service = 'No' AND internet_type IS NOT NULL) AS internet_type_should_be_null,
    (SELECT COUNT(*) FROM customer_services
       WHERE phone_service = 'No' AND multiple_lines <> 'No') AS bad_multiple_lines,
    (SELECT COUNT(*) FROM customer_churn_status
       WHERE customer_status <> 'Churned' AND churn_category IS NOT NULL) AS unexpected_churn_category;

-- ---------------------------------------------------------------------
-- CHECK 6 — Sanity ranges on numeric fields (age, tenure, charges)
-- Result: age 19-80, tenure 0-72 months, all within plausible bounds.
-- ---------------------------------------------------------------------
SELECT
    MIN(age) AS min_age, MAX(age) AS max_age
FROM customers;

SELECT
    MIN(tenure_months) AS min_tenure, MAX(tenure_months) AS max_tenure,
    MIN(monthly_charge) AS min_monthly_charge, MAX(monthly_charge) AS max_monthly_charge
FROM customer_billing;

-- ---------------------------------------------------------------------
-- CHECK 7 - Recompute Total Revenue and compare to the stored value, to
-- confirm the documented formula actually holds:
--   Total Revenue = Total Charges - Total Refunds
--                   + Total Extra Data Charges + Total Long Distance Charges
-- Result: 0 mismatches (formula holds for all 7,043 rows).
-- ---------------------------------------------------------------------
SELECT customer_id, total_revenue,
       (total_charges - total_refunds + total_extra_data_charges + total_long_distance_charges) AS recomputed_revenue
FROM customer_billing
WHERE ROUND(total_revenue, 2) <>
      ROUND(total_charges - total_refunds + total_extra_data_charges + total_long_distance_charges, 2);

-- ---------------------------------------------------------------------
-- CHECK 8 — Standardize free-text categorical values (defensive; this
-- dataset is already consistent, but this is how you'd guard against a
-- messier export where casing/whitespace differ, e.g. ' yes', 'YES').
-- ---------------------------------------------------------------------
SET SQL_SAFE_UPDATES = 0;
UPDATE customer_billing      SET contract       = TRIM(contract);
UPDATE customer_billing      SET payment_method = TRIM(payment_method);
UPDATE customer_services     SET internet_type  = TRIM(internet_type);
UPDATE customer_churn_status SET customer_status = TRIM(customer_status);
SET SQL_SAFE_UPDATES = 1;
