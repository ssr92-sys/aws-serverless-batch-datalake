# AWS Serverless Batch Data Lakehouse (NYC TLC) — Architecture

## Goal
Build an end-to-end batch pipeline on AWS that:
- lands raw data in S3
- catalogs datasets in Glue Data Catalog
- transforms/enriches data using Glue (Spark)
- writes curated Parquet back to S3 (partitioned)
- enables analytics via Athena
- runs on a schedule (EventBridge Scheduler)
- is fully reproducible via Terraform

## Dataset
- Fact: NYC TLC Yellow Taxi trip records (Parquet) for `2024-01`
- Dim/lookup: Taxi zone lookup (CSV)

## High-level flow
1) **Raw landing (S3)**
   - Upload zone lookup CSV to raw reference path
   - Upload 1-month Yellow taxi Parquet file to raw partition path

2) **Catalog raw (Glue Crawlers → Glue Data Catalog)**
   - Crawler for `ref/` creates table `ref`
   - Crawler for `year=2024/month=01/` creates table `month_01`

3) **Transform + enrich (Glue ETL)**
   - Glue ETL logic:
     - compute `trip_duration_sec` from pickup/dropoff timestamps
     - derive partition columns: `year`, `month`
     - enrich with pickup/dropoff zone details using `ref` (two joins)
   - Output: curated Parquet to curated bucket, partitioned by `year` and `month`

4) **Catalog curated (Glue Crawler)**
   - Curated crawler scans curated prefix and creates curated table (e.g., `tlc_yellow_curated`)

5) **Analytics (Athena)**
   - Athena queries raw + curated tables through `AwsDataCatalog` (Glue Data Catalog)
   - Example analytics: trips by pickup borough, avg trip duration

6) **Scheduling (EventBridge Scheduler)**
   - EventBridge Scheduler triggers Glue job daily (cron schedule)
   - Target action: `glue:startJobRun`

---

## AWS resources created (Terraform)

### S3
- Raw bucket: `...-raw-dev`
  - `tlc_yellow/ref/taxi_zone_lookup.csv`
  - `tlc_yellow/year=2024/month=01/yellow_tripdata_2024-01.parquet`
  - `glue-scripts/tlc_yellow_curate.py`
  - `athena-results/`
- Curated bucket: `...-curated-dev`
  - `tlc_yellow_curated/` (partitioned Parquet)

Security:
- Block public access (both buckets)
- Default encryption (SSE-S3 / AES256)

### Glue Data Catalog
- Database: `ssr92_aws_serverless_batch_datalake_dev`
- Tables created by crawlers:
  - `ref` (CSV)
  - `month_01` (Parquet)
  - curated table created by curated crawler (Parquet, partitioned)

### Glue Crawlers
- Raw ref crawler → targets raw `ref/`
- Raw trips crawler → targets raw `year=2024/month=01/`
- Curated crawler → targets curated `tlc_yellow_curated/`

### Glue Job (Production ETL)
- Job name: `...-tlc-yellow-curate`
- Script location: `s3://<raw-bucket>/glue-scripts/tlc_yellow_curate.py`
- Reads from Glue Catalog tables: `month_01`, `ref`
- Writes curated Parquet to: `s3://<curated-bucket>/tlc_yellow_curated/`

### EventBridge Scheduler
- Schedule triggers Glue job using AWS SDK integration:
  - `glue:startJobRun`

---

## File layout (repo)
- `infra/terraform/envs/dev/`
  - `providers.tf`, `variables.tf`, `terraform.tfvars`
  - `s3.tf`
  - `glue_db.tf`
  - `glue_crawler_raw_ref.tf`
  - `glue_crawler_raw_trips.tf`
  - `glue_crawler_curated.tf`
  - `glue_job.tf`
  - `schedule.tf`
- `glue/jobs/tlc_yellow_curate.py`
- `docs/ARCHITECTURE.md`

---

## Notes / ops considerations
- Raw data is intentionally retained for reprocessing and audit.
- Crawlers are used for quick metadata discovery. In production, curated tables often move to:
  - managed schemas (DDL/Iceberg) and partition registration without crawling.
- Current curated partitions (`year`, `month`) appear as strings in Athena due to crawler partition typing. It’s acceptable for now; can be refined later.

---

## Next planned enhancements
- Notifications on Glue job success/failure (SNS + EventBridge rule)
- Incremental processing strategy:
  - process only new partitions/months (manifest or DynamoDB checkpoint)
- Optional serving layer:
  - load curated dataset into Redshift for dashboard performance