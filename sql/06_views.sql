-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 06_views.sql
-- Purpose: Package the most useful analysis into reusable views, the
-- way you would for a BI tool (Power BI / Tableau) or a recurring
-- retention-team report, instead of re-running one-off scripts.
-- =====================================================================

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- vw_customer_360: one row per customer joining every table together --
-- the base view everything else (and any dashboard) can build on.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    c.customer_id,
    c.gender,
    c.age,
    c.married,
    c.number_of_dependents,
    c.city,
    c.zip_code,
    zp.population           AS zip_population,
    b.tenure_months,
    b.contract,
    b.payment_method,
    b.paperless_billing,
    b.monthly_charge,
    b.total_revenue,
    sv.internet_service,
    sv.internet_type,
    sv.phone_service,
    (CASE WHEN sv.online_security = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.online_backup = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.device_protection_plan = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN sv.premium_tech_support = 'Yes' THEN 1 ELSE 0 END) AS addon_count,
    cs.customer_status,
    cs.churn_category,
    cs.churn_reason
FROM customers c
JOIN customer_billing b        ON c.customer_id = b.customer_id
JOIN customer_services sv      ON c.customer_id = sv.customer_id
JOIN customer_churn_status cs  ON c.customer_id = cs.customer_id
LEFT JOIN zip_population zp    ON c.zip_code = zp.zip_code;

-- ---------------------------------------------------------------------
-- vw_churn_rate_by_segment: churn rate broken out by the three levers
-- that matter most (contract, payment method, internet type), unioned
-- into one tidy result set for easy dashboarding.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_churn_rate_by_segment AS
SELECT 'Contract' AS segment_type, contract AS segment_value,
       COUNT(*) AS customers,
       SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
       ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM vw_customer_360
GROUP BY contract

UNION ALL

SELECT 'Payment Method', payment_method,
       COUNT(*),
       SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2)
FROM vw_customer_360
GROUP BY payment_method

UNION ALL

SELECT 'Internet Type', COALESCE(internet_type, 'No Internet'),
       COUNT(*),
       SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END),
       ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2)
FROM vw_customer_360
GROUP BY COALESCE(internet_type, 'No Internet');

-- ---------------------------------------------------------------------
-- vw_priority_retention_customers: a rule-based priority retention list --
-- active Month-to-Month customers with above-average historical revenue.
-- This is a targeting rule, not a prediction that every row will churn.
-- off the base view any time it's queried.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_priority_retention_customers AS
SELECT
    customer_id, city, contract, monthly_charge, total_revenue,
    tenure_months, internet_type, addon_count
FROM vw_customer_360
WHERE customer_status = 'Stayed'
  AND contract = 'Month-to-Month'
  AND total_revenue > (SELECT AVG(total_revenue) FROM customer_billing)
ORDER BY total_revenue DESC;

-- Example usage:
-- SELECT * FROM vw_churn_rate_by_segment ORDER BY segment_type, churn_rate_pct DESC;
-- SELECT * FROM vw_priority_retention_customers LIMIT 25;
