-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 05_advanced_queries.sql
-- Purpose: Advanced SQL -- multi-table JOINs, correlated & scalar
-- subqueries, CTEs, and window functions -- to answer the deeper
-- "who should we prioritise" questions. Results in the comments are
-- from running these queries against the cleaned data.
-- =====================================================================

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- A1. CTE + window function (NTILE): does customer value predict churn?
-- Split customers into four equal-sized revenue quartiles and compare
-- churn rate across them.
-- Result: Q1 (highest revenue) churn 14.44% -> Q4 (lowest revenue)
-- churn 55.13%. Low-value customers churn ~3.8x more often, mostly
-- because low revenue usually means short tenure.
-- ---------------------------------------------------------------------
WITH revenue_tiers AS (
    SELECT
        b.customer_id,
        b.total_revenue,
        cs.customer_status,
        NTILE(4) OVER (ORDER BY b.total_revenue DESC) AS revenue_quartile
    FROM customer_billing b
    JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
    WHERE cs.customer_status IN ('Churned', 'Stayed')
)
SELECT
    revenue_quartile,
    COUNT(*) AS customers,
    SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(total_revenue), 2) AS avg_revenue
FROM revenue_tiers
GROUP BY revenue_quartile
ORDER BY revenue_quartile;

-- ---------------------------------------------------------------------
-- A2. Correlated subquery: customers paying ABOVE the average monthly
-- charge for their own contract type, who then churned anyway -- i.e.
-- "we charged them a premium and lost them regardless".
-- Result: Month-to-Month 1,174 | One Year 130 | Two Year 38
-- ---------------------------------------------------------------------
-- NOTE: the original correlated-subquery form below is left as a comment
-- for teaching purposes. When actually run against the live 7,043-row
-- database in MySQL Workbench it hit "Error Code: 2013. Lost connection
-- to MySQL server during query" (a client read-timeout at 30.000 sec),
-- because the subquery recomputes AVG(monthly_charge) once per outer row.
-- It was rewritten as a CTE that computes each contract's average ONCE
-- and joins it back -- same result, returns instantly:
--
-- SELECT
--     b.contract,
--     COUNT(*) AS above_avg_payers_who_churned
-- FROM customer_billing b
-- JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
-- WHERE cs.customer_status = 'Churned'
--   AND b.monthly_charge > (
--         SELECT AVG(b2.monthly_charge)
--         FROM customer_billing b2
--         WHERE b2.contract = b.contract   -- correlated: recomputed per contract type
--       )
-- GROUP BY b.contract;

WITH contract_avg AS (
    SELECT contract, AVG(monthly_charge) AS avg_charge
    FROM customer_billing
    WHERE monthly_charge >= 0
    GROUP BY contract
)
SELECT
    b.contract,
    COUNT(*) AS above_avg_payers_who_churned
FROM customer_billing b
JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
JOIN contract_avg ca ON ca.contract = b.contract
WHERE cs.customer_status = 'Churned'
  AND b.monthly_charge >= 0
  AND b.monthly_charge > ca.avg_charge
GROUP BY b.contract;

-- ---------------------------------------------------------------------
-- A3. Window functions RANK() + running SUM(): the 10 highest-revenue
-- customers who churned, with a running cumulative total of historical revenue
-- as you work down the list.
-- Result: top 10 churned customers alone account for $107,437.62 of
-- historical revenue; #1 is customer 2889-FPWRM at $11,195.44 (Competitor).
-- ---------------------------------------------------------------------
SELECT
    b.customer_id,
    b.total_revenue,
    b.contract,
    cs.churn_category,
    RANK() OVER (ORDER BY b.total_revenue DESC) AS revenue_rank,
    ROUND(SUM(b.total_revenue) OVER (ORDER BY b.total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS running_cumulative_historical_revenue
FROM customer_billing b
JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
WHERE cs.customer_status = 'Churned'
ORDER BY b.total_revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- A4. CTE + JOIN to the population reference table + RANK(): which
-- zip codes/cities are churn hotspots, in the context of how many
-- people actually live there (not just raw customer count)?
-- Result: several San Diego zip codes show churn rates of 85-94%
-- among a customer base of 20-36 people each -- small but very
-- concentrated pockets worth a local, targeted investigation.
-- ---------------------------------------------------------------------
WITH city_churn AS (
    SELECT
        c.city,
        c.zip_code,
        COUNT(*) AS customers,
        SUM(CASE WHEN cs.customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned
    FROM customers c
    JOIN customer_churn_status cs ON c.customer_id = cs.customer_id
    GROUP BY c.city, c.zip_code
)
SELECT
    cc.city,
    cc.zip_code,
    zp.population,
    cc.customers,
    cc.churned,
    ROUND(100.0 * cc.churned / cc.customers, 2) AS churn_rate_pct,
    RANK() OVER (ORDER BY cc.churned DESC) AS churn_rank_by_volume
FROM city_churn cc
JOIN zip_population zp ON cc.zip_code = zp.zip_code
WHERE cc.customers >= 5           -- ignore zip codes with too few customers to be meaningful
ORDER BY cc.churned DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- A5. CTE with CASE-based bucketing: churn rate by tenure stage of the
-- customer lifecycle.
-- Result: 0-12 months 59.87% churn | 13-24 months 28.71% | 25-48
-- months 20.39% | 49+ months 9.51%. Retention risk is heavily
-- front-loaded in the first year.
-- ---------------------------------------------------------------------
WITH tenure_buckets AS (
    SELECT
        b.customer_id,
        cs.customer_status,
        CASE
            WHEN b.tenure_months <= 12 THEN '0-12 mo'
            WHEN b.tenure_months <= 24 THEN '13-24 mo'
            WHEN b.tenure_months <= 48 THEN '25-48 mo'
            ELSE '49+ mo'
        END AS tenure_bucket,
        CASE
            WHEN b.tenure_months <= 12 THEN 1
            WHEN b.tenure_months <= 24 THEN 2
            WHEN b.tenure_months <= 48 THEN 3
            ELSE 4
        END AS bucket_order
    FROM customer_billing b
    JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
    WHERE cs.customer_status IN ('Churned', 'Stayed')
)
SELECT
    tenure_bucket,
    COUNT(*) AS customers,
    SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM tenure_buckets
GROUP BY tenure_bucket, bucket_order
ORDER BY bucket_order;

-- ---------------------------------------------------------------------
-- A6. JOIN + derived CASE columns: does bundling add-on services reduce
-- churn? Count each customer's add-ons (security, backup, device
-- protection, tech support) and compare churn rate by add-on count.
-- Result: 0 add-ons 63.54% churn -> 4 add-ons 5.32% churn. This is the
-- single strongest lever in the whole dataset.
-- ---------------------------------------------------------------------
SELECT
    (CASE WHEN sv.online_security = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.online_backup = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.device_protection_plan = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.premium_tech_support = 'Yes' THEN 1 ELSE 0 END) AS addon_count,
    COUNT(*) AS customers,
    SUM(CASE WHEN cs.customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN cs.customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customer_services sv
JOIN customer_churn_status cs ON sv.customer_id = cs.customer_id
WHERE sv.internet_service = 'Yes'
  AND cs.customer_status IN ('Churned', 'Stayed')
GROUP BY addon_count
ORDER BY addon_count;

-- ---------------------------------------------------------------------
-- A7. Multi-table JOIN + scalar subquery: a rule-based priority retention list --
-- customers who are STILL ACTIVE, on a flexible Month-to-Month
-- contract (easiest to leave), and already spending more than the
-- company average -- i.e. valuable customers with no contractual
-- reason to stay.
-- Result: 442 customers meet all three conditions. These are the
-- candidates for a retention offer, sorted by historical revenue. This
-- segment is not a predictive churn model.
-- ---------------------------------------------------------------------
SELECT
    c.customer_id,
    c.city,
    b.contract,
    b.monthly_charge,
    b.total_revenue,
    b.tenure_months,
    sv.internet_type
FROM customers c
JOIN customer_billing b        ON c.customer_id = b.customer_id
JOIN customer_churn_status cs  ON c.customer_id = cs.customer_id
JOIN customer_services sv      ON c.customer_id = sv.customer_id
WHERE cs.customer_status = 'Stayed'
  AND b.contract = 'Month-to-Month'
  AND b.total_revenue > (SELECT AVG(total_revenue) FROM customer_billing)
ORDER BY b.total_revenue DESC;
