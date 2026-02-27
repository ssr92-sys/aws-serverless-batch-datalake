resource "aws_iam_role" "glue_crawler_role" {
  name = "${var.project_name}-${var.env}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue_crawler_policy" {
  name = "${var.project_name}-${var.env}-glue-crawler-policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow crawler to read the raw bucket (so it can infer schema)
      {
        Effect = "Allow"
        Action = [
           "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.raw.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.raw.bucket}/*",

          # CURATED bucket
        "arn:aws:s3:::${aws_s3_bucket.curated.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.curated.bucket}/*"
        ]
      },
      # Allow crawler to create/update table metadata in Glue Data Catalog
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      # Logs (so you can see crawler output in CloudWatch)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_crawler" "raw_ref" {
  name          = "${var.project_name}-${var.env}-raw-ref-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.datalake.name

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/tlc_yellow/ref/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}