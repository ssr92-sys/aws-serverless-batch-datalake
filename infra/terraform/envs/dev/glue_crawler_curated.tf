resource "aws_glue_crawler" "curated_yellow" {
  name          = "${var.project_name}-${var.env}-curated-yellow-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.datalake.name

  s3_target {
    path = "s3://${aws_s3_bucket.curated.bucket}/tlc_yellow_curated/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}