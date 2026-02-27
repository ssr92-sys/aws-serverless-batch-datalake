resource "aws_iam_role" "glue_job_role" {
  name = "${var.project_name}-${var.env}-glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Baseline permissions Glue jobs expect
resource "aws_iam_role_policy_attachment" "glue_job_service_role" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# S3 + Catalog access for this job (read raw + write curated + read catalog)
resource "aws_iam_role_policy" "glue_job_data_access" {
  name = "${var.project_name}-${var.env}-glue-job-data-access"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RawReadAndScriptRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.raw.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.raw.bucket}/*"
        ]
      },
      {
        Sid    = "CuratedWrite"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.curated.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.curated.bucket}/*"
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_job" "tlc_yellow_curate" {
  name     = "${var.project_name}-${var.env}-tlc-yellow-curate"
  role_arn = aws_iam_role.glue_job_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.raw.bucket}/glue-scripts/tlc_yellow_curate.py"
  }

  # keep cost low
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  default_arguments = {
    "--enable-glue-datacatalog" = "true"
    "--job-language"           = "python"

    # Our script args
    "--glue_db"         = aws_glue_catalog_database.datalake.name
    "--raw_trips_table" = "month_01"
    "--ref_table"       = "ref"
    "--curated_s3_path" = "s3://${aws_s3_bucket.curated.bucket}/tlc_yellow_curated/"
  }
}

output "glue_job_name" {
  value = aws_glue_job.tlc_yellow_curate.name
}