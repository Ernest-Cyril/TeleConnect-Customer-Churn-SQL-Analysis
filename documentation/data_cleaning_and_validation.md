# Data Cleaning and Validation

## Purpose

The cleaning workflow protects the raw source, tests structural and business rules, and records unresolved anomalies without inventing replacement values.

## Validation results

| Check | Result | Treatment |
| --- | ---: | --- |
| Customer rows | 7,043 | Confirmed expected volume |
| Unique customer IDs | 7,043 | Primary key suitable |
| Duplicate customer IDs | 0 | No removal required |
| ZIP codes missing from reference table | 0 | Referential-integrity check passed |
| Missing churn reasons among churned customers | 0 | Business rule passed |
| Total-revenue formula mismatches | 0 | Financial reconciliation passed |
| Negative monthly-charge records | 120 | Flagged; source retained |

## Null-value treatment

Nulls were evaluated against service status rather than filled automatically. Internet-related fields are null when Internet Service is `No`; phone-related fields can be null when Phone Service is `No`; and churn category and reason are null for customers who did not churn. These values represent non-applicability rather than missing observations.

## Negative monthly-charge anomaly

The source contains 120 monthly-charge values between -10 and -1. The data dictionary describes the field as the customer's current total monthly charge but does not explain negative values. Converting a value such as -4 to 4 would not establish the actual charge and could create false precision.

The final portfolio treatment is therefore:

1. Preserve the imported value.
2. Record the customer and value in `data_cleaning_log`.
3. Mark the replacement value as unknown.
4. Exclude negative values from monthly-charge averages and comparisons.
5. State the limitation in the README and final report.

After excluding these anomalies, the average monthly charge is $74.62 for churned customers and $62.96 for customers who stayed.

## Revenue reconciliation

For every customer, the following formula was recalculated:

```text
Total Revenue = Total Charges - Total Refunds
                + Total Extra Data Charges
                + Total Long Distance Charges
```

All 7,043 records matched the stored total revenue to two decimal places.

## Source preservation

The CSV files in `data` remain unchanged. Transformations and analytical exclusions are implemented in SQL so another reviewer can reproduce and challenge each decision.
