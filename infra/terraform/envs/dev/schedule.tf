resource "aws_iam_role" "scheduler_role" {
  name = "${var.project_name}-${var.env}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "scheduler.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_policy" {
  name = "${var.project_name}-${var.env}-scheduler-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "glue:StartJobRun"
      ],
      Resource = aws_glue_job.tlc_yellow_curate.arn
    }]
  })
}

resource "aws_scheduler_schedule" "daily_glue_job" {
  name        = "${var.project_name}-${var.env}-daily-tlc-yellow-curate"
  description = "Daily schedule for TLC Yellow curate Glue job"
  state       = "ENABLED"

  # Daily at 01:00 AM Eastern Time
  schedule_expression          = "cron(0 1 * * ? *)"
  schedule_expression_timezone = "America/New_York"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:glue:startJobRun"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      JobName = aws_glue_job.tlc_yellow_curate.name
      # (optional) Arguments override can go here later
    })
  }
}