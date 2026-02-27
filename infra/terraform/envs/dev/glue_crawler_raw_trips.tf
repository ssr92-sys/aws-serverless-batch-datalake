resource "aws_glue_crawler" "raw_trips" {
  name          = "${var.project_name}-${var.env}-raw-trips-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.datalake.name

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/tlc_yellow/year=2024/month=01/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}