resource "aws_glue_catalog_database" "datalake" {
  name = "${replace(var.project_name, "-", "_")}_${var.env}"
}