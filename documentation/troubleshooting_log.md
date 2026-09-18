# Troubleshooting Log

## Slow Table Data Import Wizard

The Workbench wizard inserted the wide customer file row by row and remained incomplete after more than 30 minutes. The project switched to `LOAD DATA INFILE`, which loaded 7,043 rows in under one second.

## LOAD DATA LOCAL INFILE restriction

The client rejected `LOAD DATA LOCAL INFILE` with Error 2068 even after the server option was enabled. The working approach used the server's `secure_file_priv` directory and plain `LOAD DATA INFILE`.

## Blank numeric fields

Legitimate blanks in usage fields caused Error 1366 when loaded directly into numeric columns. The staging table received these fields as text, `NULLIF` converted blank strings to SQL nulls, and the normalized insert cast valid values to numeric types.

## Correlated-subquery timeout

A contract-average comparison exceeded the 30-second Workbench read timeout because the correlated subquery recalculated the same aggregate repeatedly. A CTE calculated each contract average once and joined it to the customer rows.

## Analytical terminology review

The audit distinguished cumulative historical revenue from future revenue loss and treated the 442-customer output as a rule-based priority segment. It also replaced an unsupported absolute-value correction with anomaly flagging and explicit exclusion from charge averages.
