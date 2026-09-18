# SQL Query Guide

## Script sequence

| Script | Purpose |
| --- | --- |
| `01_schema.sql` | Creates the database, normalized tables, constraints, and indexes |
| `02_load_data.sql` | Loads the ZIP reference and customer CSV through a staging table |
| `03_data_cleaning_and_validation.sql` | Runs quality checks and records unresolved anomalies |
| `04_basic_queries.sql` | Answers foundational churn and revenue questions |
| `05_advanced_queries.sql` | Applies CTEs, window functions, subqueries, bucketing, and multi-table joins |
| `06_views.sql` | Creates reusable reporting views |

## Core techniques

### Conditional aggregation

`SUM(CASE WHEN ... THEN 1 ELSE 0 END)` counts churned, stayed, and joined customers within grouped results. This supports churn-rate calculations without separate queries.

### Joins

The analytical queries join demographics, services, billing, churn status, and population data through `customer_id` and `zip_code`.

### Common table expressions

CTEs calculate contract-level averages once, define tenure buckets, and aggregate location-level churn before ranking. A CTE replaced a correlated subquery that repeatedly calculated contract averages and exceeded the Workbench read timeout.

### Window functions

- `NTILE(4)` divides eligible customers into historical-revenue quartiles.
- `RANK()` orders churned customers and ZIP areas without collapsing detail rows.
- `SUM() OVER()` produces cumulative historical revenue for the highest-value churned customers.

### Views

The views separate reusable reporting logic from one-off exploration. A BI tool can query the customer 360 view or standardized segment summaries without rebuilding the joins.

## Interpretation rules

- Churn rate across all customers uses 7,043 as the denominator.
- Churn rate excluding recent joins uses 6,589 customers classified as Stayed or Churned.
- `total_revenue` represents cumulative historical revenue through the snapshot date.
- The retention view is a transparent targeting rule, not a machine-learning prediction.
- Negative monthly charges are excluded from charge averages because their true values are unknown.
