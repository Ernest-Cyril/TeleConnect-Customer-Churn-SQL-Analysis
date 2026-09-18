# Database Rebuild

The authoritative rebuild method uses the ordered scripts in `sql` together with the original CSV files in `data`.

The supplied handover contained an executed database dump in which negative monthly-charge anomalies had been converted to absolute values. That assumption was not retained in the audited portfolio version because the true replacement values cannot be established from the available source documentation. The original dump is therefore intentionally excluded from this public package.

Run the scripts from `01_schema.sql` through `06_views.sql`. Update the two `LOAD DATA INFILE` paths in `02_load_data.sql` to match the folder returned by:

```sql
SHOW VARIABLES LIKE 'secure_file_priv';
```

The source CSV files remain unchanged, and the corrected SQL scripts flag rather than overwrite the 120 negative monthly-charge records.
