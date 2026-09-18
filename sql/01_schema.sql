-- =====================================================================
-- TeleConnect Customer Churn and Revenue Risk Analysis
-- 01_schema.sql
-- Purpose: Create the database and a normalized relational schema.
--
-- Design notes:
--   The source data arrives as ONE flat CSV (telecom_customer_churn.csv)
--   with 38 columns covering demographics, services, billing and churn
--   status, plus a second reference file of population by zip code.
--
--   To demonstrate real database design (not just "load a spreadsheet"),
--   the flat file is normalized into five related tables, all keyed on
--   customer_id (and customers -> zip_population via zip_code):
--
--       customers              -- demographic + location attributes
--       zip_population         -- reference table: population per zip
--       customer_services      -- phone / internet / add-on subscriptions
--       customer_billing       -- tenure, contract, payment, charges
--       customer_churn_status  -- Stayed / Churned / Joined + reason
--
--   This lets the query layer (04/05) show real JOIN logic instead of
--   pulling every answer from a single table.
-- =====================================================================

DROP DATABASE IF EXISTS teleconnect_churn;
CREATE DATABASE teleconnect_churn
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE teleconnect_churn;

-- ---------------------------------------------------------------------
-- Reference table: population per zip code
-- ---------------------------------------------------------------------
CREATE TABLE zip_population (
    zip_code    INT PRIMARY KEY,
    population  INT NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Core dimension: one row per customer (demographics + location)
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id             VARCHAR(10) PRIMARY KEY,
    gender                  VARCHAR(10),
    age                     TINYINT UNSIGNED,
    married                 VARCHAR(3),
    number_of_dependents    SMALLINT UNSIGNED,
    city                    VARCHAR(100),
    zip_code                INT,
    latitude                DECIMAL(9,6),
    longitude               DECIMAL(9,6),
    CONSTRAINT fk_customers_zip
        FOREIGN KEY (zip_code) REFERENCES zip_population (zip_code)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Services subscribed to by each customer
-- ---------------------------------------------------------------------
CREATE TABLE customer_services (
    customer_id                         VARCHAR(10) PRIMARY KEY,
    offer                               VARCHAR(20),   -- last marketing offer accepted (None/Offer A-E)
    phone_service                       VARCHAR(3),    -- Yes/No
    avg_monthly_long_distance_charges   DECIMAL(8,2),
    multiple_lines                      VARCHAR(3),
    internet_service                    VARCHAR(3),    -- Yes/No
    internet_type                       VARCHAR(20),   -- DSL / Fiber Optic / Cable / NULL
    avg_monthly_gb_download             SMALLINT UNSIGNED,
    online_security                     VARCHAR(3),
    online_backup                       VARCHAR(3),
    device_protection_plan              VARCHAR(3),
    premium_tech_support                VARCHAR(3),
    streaming_tv                        VARCHAR(3),
    streaming_movies                    VARCHAR(3),
    streaming_music                     VARCHAR(3),
    unlimited_data                      VARCHAR(3),
    CONSTRAINT fk_services_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Billing / contract / tenure facts
-- ---------------------------------------------------------------------
CREATE TABLE customer_billing (
    customer_id                     VARCHAR(10) PRIMARY KEY,
    tenure_months                   SMALLINT UNSIGNED,
    number_of_referrals             SMALLINT UNSIGNED,
    contract                        VARCHAR(20),   -- Month-to-Month / One Year / Two Year
    paperless_billing                VARCHAR(3),
    payment_method                   VARCHAR(30),
    monthly_charge                   DECIMAL(8,2),
    total_charges                    DECIMAL(10,2),
    total_refunds                    DECIMAL(10,2),
    total_extra_data_charges         DECIMAL(10,2),
    total_long_distance_charges      DECIMAL(10,2),
    total_revenue                    DECIMAL(10,2),  -- Total Charges - Refunds + Extra Data + Long Distance
    CONSTRAINT fk_billing_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Churn outcome for the quarter
-- ---------------------------------------------------------------------
CREATE TABLE customer_churn_status (
    customer_id       VARCHAR(10) PRIMARY KEY,
    customer_status   VARCHAR(10),   -- Stayed / Churned / Joined
    churn_category    VARCHAR(30),   -- Attitude / Competitor / Dissatisfaction / Other / Price / NULL
    churn_reason      VARCHAR(120),
    CONSTRAINT fk_churn_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB;

-- Helpful indexes for the analytical queries in 04/05
CREATE INDEX idx_billing_contract      ON customer_billing (contract);
CREATE INDEX idx_billing_payment       ON customer_billing (payment_method);
CREATE INDEX idx_services_internet     ON customer_services (internet_type);
CREATE INDEX idx_status_status         ON customer_churn_status (customer_status);
CREATE INDEX idx_customers_zip         ON customers (zip_code);
