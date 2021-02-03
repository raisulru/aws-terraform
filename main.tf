
terraform {
  backend "s3" {
    bucket = "raisul-test-bucket"
    key    = "backend"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# EC2 instance
resource "aws_instance" "test_ec2" {
  ami           = "ami-096fda3c22c1c990a"
  instance_type = "t2.micro"
}

# s3 bucket
resource "aws_s3_bucket" "raisul_s3_bucket" {
  bucket = "raisul-terraform-test-bucket"
  acl    = "private"

  tags = {
    Name        = "Practice bucket"
    Environment = "Dev"
  }
}

# SQS
resource "aws_sqs_queue" "sqs" {
  name        = var.name
  name_prefix = var.name_prefix
}

data "aws_arn" "arn" {
  arn = aws_sqs_queue.sqs.arn
}

# Dynamodb
resource "aws_dynamodb_table" "example" {
  name = "test-db"
  hash_key = "userId"
  range_key = "department"
  billing_mode = "PAY_PER_REQUEST"

  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = true }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "department"
    type = "S"
  }

  ttl {
    enabled = true
    attribute_name = "expires"
  }

  tags = {
    Environment = "production"
  }
}

# Secret Manager
# resource "aws_secretsmanager_secret" "example" {
#   name = "example"
# }

# Lambda Function
provider "archive" {}

data "archive_file" "zip_validate" {
  type        = "zip"
  source_file = "my_function.py"
  output_path = "my_function.zip"
}


data "archive_file" "zip_not_validate" {
  type        = "zip"
  source_file = "not_validated.py"
  output_path = "not_validated.zip"
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_raisul_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_lambda_function" "lambda1" {
  function_name = "lambda_validate"

  filename         = data.archive_file.zip_validate.output_path
  source_code_hash = data.archive_file.zip_validate.output_base64sha256

  role    = aws_iam_role.iam_for_lambda.arn
  handler = "my_function.validate_somthing"
  runtime = "python3.8"
}

resource "aws_lambda_function" "lambda2" {
  function_name = "lambda_not_validate"

  filename         = data.archive_file.zip_not_validate.output_path
  source_code_hash = data.archive_file.zip_not_validate.output_base64sha256

  role    = aws_iam_role.iam_for_lambda.arn
  handler = "my_function.not_validated"
  runtime = "python3.8"
}

# Cloud Watch Event
resource "aws_cloudwatch_event_rule" "console" {
  name        = "capture-aws-sign-in"
  description = "Capture each AWS Console Sign In"

  event_pattern = <<EOF
  {
    "detail-type": [
      "AWS Console Sign In via CloudTrail"
    ]
  }
  EOF
}


# Step Function
resource "aws_sfn_state_machine" "my_first_step_function" {
  name       = "test_step_function"
  role_arn   = aws_iam_role.iam_for_lambda.arn
  definition = data.template_file.step_function_definition.rendered
}

data "template_file" "step_function_definition" {
  template = file("${path.module}/sf.json")

  vars = {
    validate_function = aws_lambda_function.lambda1.arn
    not_validate_func = aws_lambda_function.lambda2.arn
  }
}
