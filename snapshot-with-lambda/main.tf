provider "aws" {
  region = "us-west-1"
}

variable "retention_days" {
  description = "Number of days to retain EBS snapshots"
  default     = 7
}


# Create Lambda function package, comment out if using s3 bucket
#data "archive_file" "lambda_function" {
#  type        = "zip"
#  source_dir  = "${path.module}/ebs_snapshot_creator"
#  output_path = "${path.module}/ebs_snapshot_creator/ebs_snapshot_creator.zip"
#}

resource "aws_lambda_function" "ebs_snapshot" {
  function_name = "ebs_snapshot_lambda"

#Two ways to deploy lambda package, s3 bucket and upload from local

# using s3 bucket to upload lambda package
  s3_bucket = "anson-ebs-daily"
  s3_key    = "ebs_snapshot_creator.zip"

# upload lambda package from local.
#  filename = "${path.module}/ebs_snapshot_creator/ebs_snapshot_creator.zip"
#  source_code_hash = data.archive_file.lambda_function.output_base64sha256


  handler = "lambda_function.lambda_handler"
  runtime = "python3.8"
  role    = aws_iam_role.lambda_execution_role.arn

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  timeout = 60
}

# create aws role
resource "aws_iam_role" "lambda_execution_role" {
  name = "ebs_snapshot_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# create iam role policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "ebs_snapshot_lambda_execution_policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ec2:DescribeVolumes",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# create aws cloudwatch event rule and schedule
resource "aws_cloudwatch_event_rule" "daily_ebs_snapshot" {
  name                = "daily_ebs_snapshot"
  description         = "Trigger daily EBS snapshot creation"
  schedule_expression = "cron(45 20 * * ? *)" # Daily at 12:00 UTC
}

# create aws cloudwatch event target
resource "aws_cloudwatch_event_target" "daily_ebs_snapshot_target" {
  rule      = aws_cloudwatch_event_rule.daily_ebs_snapshot.name
  target_id = "ebs_snapshot_lambda"
  arn       = aws_lambda_function.ebs_snapshot.arn
}

# create aws lamdba permission
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_ebs_snapshot.arn
}

