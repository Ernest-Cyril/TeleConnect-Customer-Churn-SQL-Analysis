-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 04_basic_queries.sql
-- Purpose: Answer the foundational business questions with straightforward
-- SELECT / WHERE / GROUP BY / aggregate SQL. Every query below was run
-- against the cleaned data; the result noted in the comment is real.
-- =====================================================================

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- Q1. How many customers do we have, and how many have left?
-- Result: 7,043 total | 1,869 Churned | 4,720 Stayed | 454 Joined this qtr
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                   AS total_customers,
    SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    SUM(CASE WHEN customer_status = 'Stayed'  THEN 1 ELSE 0 END) AS stayed,
    SUM(CASE WHEN customer_status = 'Joined'  THEN 1 ELSE 0 END) AS joined_this_quarter
FROM customer_churn_status;

-- ---------------------------------------------------------------------
-- Q2. What is the overall churn rate?
-- Result: 26.54% of all customers; 28.37% if you exclude brand-new
-- "Joined" customers who haven't had a chance to churn yet.
-- ---------------------------------------------------------------------
SELECT
    ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct_all_customers,
    ROUND(100.0 * SUM(CASE WHEN customer_status = 'Churned' THEN 1 ELSE 0 END)
        / SUM(CASE WHEN customer_status IN ('Churned','Stayed') THEN 1 ELSE 0 END), 2) AS churn_rate_pct_excl_new_joins
FROM customer_churn_status;

-- ---------------------------------------------------------------------
-- Q3. Which contract type has the highest churn?
-- Result: Month-to-Month 45.84% | One Year 10.71% | Two Year 2.55%
-- ---------------------------------------------------------------------
SELECT
    b.contract,
    COUNT(*) AS customers,
    SUM(CASE WHEN s.customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN s.customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customer_billing b
JOIN customer_churn_status s ON b.customer_id = s.customer_id
GROUP BY b.contract
ORDER BY churn_rate_pct DESC;

-- ---------------------------------------------------------------------
-- Q4. Which payment method has the highest churn?
-- Result: Mailed Check 36.88% | Bank Withdrawal 34.00% | Credit Card 14.48%
-- ---------------------------------------------------------------------
SELECT
    b.payment_method,
    COUNT(*) AS customers,
    SUM(CASE WHEN s.customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN s.customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customer_billing b
JOIN customer_churn_status s ON b.customer_id = s.customer_id
GROUP BY b.payment_method
ORDER BY churn_rate_pct DESC;

-- ---------------------------------------------------------------------
-- Q5. Which internet service type has the highest churn?
-- Result: Fiber Optic 40.72% | Cable 25.66% | DSL 18.58% | No Internet 7.40%
-- ---------------------------------------------------------------------
SELECT
    COALESCE(sv.internet_type, 'No Internet') AS internet_type,
    COUNT(*) AS customers,
    SUM(CASE WHEN cs.customer_status = 'Churned' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN cs.customer_status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customer_services sv
JOIN customer_churn_status cs ON sv.customer_id = cs.customer_id
GROUP BY COALESCE(sv.internet_type, 'No Internet')
ORDER BY churn_rate_pct DESC;

-- ---------------------------------------------------------------------
-- Q6. What are the leading reasons customers give for leaving?
-- Result (by category): Competitor 45.0% | Dissatisfaction 17.2% |
--   Attitude 16.8% | Price 11.3% | Other 9.7%
-- ---------------------------------------------------------------------
SELECT
    churn_category,
    COUNT(*) AS customers_lost,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer_churn_status WHERE customer_status = 'Churned'), 2) AS pct_of_all_churn
FROM customer_churn_status
WHERE customer_status = 'Churned'
GROUP BY churn_category
ORDER BY customers_lost DESC;

-- Top 5 specific reasons within those categories
-- Result: "Competitor had better devices" (313), "Competitor made better
-- offer" (311), "Attitude of support person" (220), "Don't know" (130),
-- "Competitor offered more data" (117)
SELECT churn_reason, COUNT(*) AS customers_lost
FROM customer_churn_status
WHERE customer_status = 'Churned'
GROUP BY churn_reason
ORDER BY customers_lost DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- Q7. Does tenure differ between customers who stayed and who churned?
-- Result: Churned customers average 18.0 months of tenure vs. 41.0
-- months for customers who stayed. After excluding 120 unexplained
-- negative-charge anomalies, average monthly charge is $74.62 for
-- churned customers and $62.96 for customers who stayed.
-- ---------------------------------------------------------------------
SELECT
    cs.customer_status,
    ROUND(AVG(b.tenure_months), 1) AS avg_tenure_months,
    ROUND(AVG(CASE WHEN b.monthly_charge >= 0 THEN b.monthly_charge END), 2)
        AS avg_monthly_charge_excluding_anomalies
FROM customer_billing b
JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
WHERE cs.customer_status IN ('Churned', 'Stayed')
GROUP BY cs.customer_status;

-- ---------------------------------------------------------------------
-- Q8. How much revenue is tied to churned customers?
-- Result: $3,684,459.82 in historical total revenue attached to the 1,869 churned
-- customers (avg $1,971.35/customer) vs. $17,632,392.12 held by
-- customers who stayed (avg $3,735.68/customer).
-- ---------------------------------------------------------------------
SELECT
    cs.customer_status,
    COUNT(*) AS customers,
    ROUND(SUM(b.total_revenue), 2) AS historical_total_revenue,
    ROUND(AVG(b.total_revenue), 2) AS avg_revenue_per_customer
FROM customer_billing b
JOIN customer_churn_status cs ON b.customer_id = cs.customer_id
GROUP BY cs.customer_status;
