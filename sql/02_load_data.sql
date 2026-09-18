-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 02_load_data.sql
-- Purpose: Import the raw CSV files and populate the normalized tables.
--
-- HOW TO RUN THIS FILE (MySQL Workbench):
--   LOAD DATA LOCAL INFILE was tried first (reads the CSV straight off
--   your own machine) but was blocked in this environment with
--   "Error 2068: LOAD DATA LOCAL INFILE file request rejected due to
--   restrictions on access", even after enabling local_infile on the
--   server AND OPT_LOCAL_INFILE on the client connection.
--
--   The working alternative used here is plain LOAD DATA INFILE
--   (no LOCAL) reading from the server's own secure-file-priv folder:
--     1. Run:  SHOW VARIABLES LIKE 'secure_file_priv';
--     2. Copy both CSVs into the folder it reports
--        (on this project's machine: 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/').
--     3. Update the two file paths below to match your own
--        secure_file_priv folder, then run this whole script after 01_schema.sql.
--   This loaded all 7,043 customer rows in well under a second, versus
--   the Workbench "Table Data Import Wizard" GUI option, which inserts
--   row-by-row and took 30+ minutes to load only 289 of 7,043 rows on
--   this same file -- not usable at this size.
-- =====================================================================

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- Step 1: load the zip -> population reference file directly
-- ---------------------------------------------------------------------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/telecom_zipcode_population.csv'
INTO TABLE zip_population
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(zip_code, population);

-- ---------------------------------------------------------------------
-- Step 2: load the flat churn CSV into a STAGING table that mirrors the
-- CSV column-for-column. This keeps the raw import simple and puts all
-- cleaning/typing decisions in SQL (step 3), not in the import step.
--
-- avg_monthly_long_distance_charges and avg_monthly_gb_download are
-- staged as VARCHAR rather than DECIMAL/INT: some rows have a
-- legitimately blank value for these (no internet/phone service), and
-- a numeric column rejects an empty string outright ("Error 1366:
-- Incorrect integer value: ' ' for column 'avg_monthly_gb_download'").
-- They are CAST back to their proper numeric type in Step 3 below.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg_telecom_raw;
CREATE TABLE stg_telecom_raw (
    customer_id                         VARCHAR(10),
    gender                               VARCHAR(10),
    age                                  INT,
    married                              VARCHAR(3),
    number_of_dependents                 INT,
    city                                 VARCHAR(100),
    zip_code                             INT,
    latitude                             DECIMAL(9,6),
    longitude                            DECIMAL(9,6),
    number_of_referrals                  INT,
    tenure_months                        INT,
    offer                                VARCHAR(20),
    phone_service                        VARCHAR(3),
    avg_monthly_long_distance_charges    VARCHAR(20),
    multiple_lines                       VARCHAR(3),
    internet_service                     VARCHAR(3),
    internet_type                        VARCHAR(20),
    avg_monthly_gb_download              VARCHAR(20),
    online_security                      VARCHAR(3),
    online_backup                        VARCHAR(3),
    device_protection_plan               VARCHAR(3),
    premium_tech_support                 VARCHAR(3),
    streaming_tv                         VARCHAR(3),
    streaming_movies                     VARCHAR(3),
    streaming_music                      VARCHAR(3),
    unlimited_data                       VARCHAR(3),
    contract                             VARCHAR(20),
    paperless_billing                    VARCHAR(3),
    payment_method                       VARCHAR(30),
    monthly_charge                       DECIMAL(8,2),
    total_charges                        DECIMAL(10,2),
    total_refunds                        DECIMAL(10,2),
    total_extra_data_charges             DECIMAL(10,2),
    total_long_distance_charges          DECIMAL(10,2),
    total_revenue                        DECIMAL(10,2),
    customer_status                      VARCHAR(10),
    churn_category                       VARCHAR(30),
    churn_reason                         VARCHAR(120)
) ENGINE=InnoDB;

-- NOTE: several columns are legitimately blank in the source CSV whenever a
-- service doesn't apply (e.g. Internet Type is blank if Internet Service =
-- 'No'). Those columns are routed through a @variable and NULLIF() below so
-- they load as true SQL NULL rather than an empty string -- without this,
-- the "business-logic NULL" checks in 03_data_cleaning_and_validation.sql
-- would not match.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/telecom_customer_churn.csv'
INTO TABLE stg_telecom_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, gender, age, married, number_of_dependents, city, zip_code,
 latitude, longitude, number_of_referrals, tenure_months, @offer, phone_service,
 @avg_monthly_long_distance_charges, @multiple_lines, internet_service, @internet_type,
 @avg_monthly_gb_download, @online_security, @online_backup, @device_protection_plan,
 @premium_tech_support, @streaming_tv, @streaming_movies, @streaming_music, @unlimited_data,
 contract, paperless_billing, payment_method, monthly_charge, total_charges,
 total_refunds, total_extra_data_charges, total_long_distance_charges, total_revenue,
 customer_status, @churn_category, @churn_reason)
SET offer                              = NULLIF(@offer, ''),
    avg_monthly_long_distance_charges  = NULLIF(@avg_monthly_long_distance_charges, ''),
    multiple_lines                     = NULLIF(@multiple_lines, ''),
    internet_type                      = NULLIF(@internet_type, ''),
    avg_monthly_gb_download            = NULLIF(@avg_monthly_gb_download, ''),
    online_security                    = NULLIF(@online_security, ''),
    online_backup                      = NULLIF(@online_backup, ''),
    device_protection_plan             = NULLIF(@device_protection_plan, ''),
    premium_tech_support               = NULLIF(@premium_tech_support, ''),
    streaming_tv                       = NULLIF(@streaming_tv, ''),
    streaming_movies                   = NULLIF(@streaming_movies, ''),
    streaming_music                    = NULLIF(@streaming_music, ''),
    unlimited_data                     = NULLIF(@unlimited_data, ''),
    churn_category                     = NULLIF(@churn_category, ''),
    churn_reason                       = NULLIF(@churn_reason, '');

-- ---------------------------------------------------------------------
-- Step 3: fan the staging table out into the normalized tables
-- ---------------------------------------------------------------------
INSERT INTO customers (customer_id, gender, age, married, number_of_dependents,
                        city, zip_code, latitude, longitude)
SELECT customer_id, gender, age, married, number_of_dependents,
       city, zip_code, latitude, longitude
FROM stg_telecom_raw;

INSERT INTO customer_services (customer_id, offer, phone_service,
        avg_monthly_long_distance_charges, multiple_lines, internet_service,
        internet_type, avg_monthly_gb_download, online_security, online_backup,
        device_protection_plan, premium_tech_support, streaming_tv,
        streaming_movies, streaming_music, unlimited_data)
SELECT customer_id, offer, phone_service,
       CAST(avg_monthly_long_distance_charges AS DECIMAL(8,2)),
       multiple_lines, internet_service, internet_type,
       CAST(avg_monthly_gb_download AS UNSIGNED),
       online_security, online_backup, device_protection_plan, premium_tech_support,
       streaming_tv, streaming_movies, streaming_music, unlimited_data
FROM stg_telecom_raw;

INSERT INTO customer_billing (customer_id, tenure_months, number_of_referrals,
        contract, paperless_billing, payment_method, monthly_charge,
        total_charges, total_refunds, total_extra_data_charges,
        total_long_distance_charges, total_revenue)
SELECT customer_id, tenure_months, number_of_referrals, contract, paperless_billing,
       payment_method, monthly_charge, total_charges, total_refunds,
       total_extra_data_charges, total_long_distance_charges, total_revenue
FROM stg_telecom_raw;

INSERT INTO customer_churn_status (customer_id, customer_status, churn_category, churn_reason)
SELECT customer_id, customer_status, churn_category, churn_reason
FROM stg_telecom_raw;

-- Staging table is no longer needed once the normalized tables are populated
-- DROP TABLE stg_telecom_raw;

-- Quick sanity check: row counts should all be 7,043 customers / 1,671 zip codes
-- Actual result when run: customers 7043 | customer_services 7043 |
-- customer_billing 7043 | customer_churn_status 7043 | zip_population 1671
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'customer_services', COUNT(*) FROM customer_services
UNION ALL SELECT 'customer_billing', COUNT(*) FROM customer_billing
UNION ALL SELECT 'customer_churn_status', COUNT(*) FROM customer_churn_status
UNION ALL SELECT 'zip_population', COUNT(*) FROM zip_population;
