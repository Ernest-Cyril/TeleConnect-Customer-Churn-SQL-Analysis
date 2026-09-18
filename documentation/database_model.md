# Database Model

## Design approach

The source customer file contains demographics, location, services, billing, and churn outcome in one 38-column table. The project separates these subjects into related tables to demonstrate relational modelling and reduce repeated business logic.

## Tables

### customers

Stores one record per customer, including gender, age, marital status, dependents, city, ZIP code, latitude, and longitude. `customer_id` is the primary key. `zip_code` links to `zip_population`.

### customer_services

Stores phone service, internet service, internet type, offer, download usage, streaming services, security, backup, device protection, technical support, and unlimited-data status. `customer_id` is both the primary key and a foreign key to `customers`.

### customer_billing

Stores tenure, referrals, contract, billing preferences, payment method, monthly charge, cumulative charges, refunds, extra-data charges, long-distance charges, and total historical revenue.

### customer_churn_status

Stores the customer outcome (`Stayed`, `Churned`, or `Joined`) and the churn category and reason where applicable.

### zip_population

Stores one population value per California ZIP code. `zip_code` is the primary key.

## Relationships

- `zip_population` has a one-to-many relationship with `customers`.
- `customers` has one-to-one analytical relationships with `customer_services`, `customer_billing`, and `customer_churn_status` because each customer appears once in each table.

## Supporting objects

- `stg_telecom_raw` mirrors the source CSV during loading.
- `data_cleaning_log` records data-quality exceptions.
- `vw_customer_360` joins the core tables into one reusable customer-level view.
- `vw_churn_rate_by_segment` standardizes contract, payment-method, and internet-type churn summaries.
- `vw_priority_retention_customers` returns the transparent 442-customer retention segment.

The MySQL EER diagram is available at `screenshots/02_mysql_eer_diagram.png`.
