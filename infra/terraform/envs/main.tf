terraform {
  backend "local" {}
}

output "project" {
  value = {
    project_name = var.project_name
    aws_region   = var.aws_region
    env          = var.env
  }
}