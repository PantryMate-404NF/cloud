# ── Lambda 코드 패키징 ────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

# ── Lambda IAM Role ───────────────────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-webhook-relay-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.common_tags
}

# VPC 내부 Lambda에 필요한 기본 실행 권한 (CloudWatch Logs + ENI 생성)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# SSM에서 GitHub webhook secret 읽기 권한
data "aws_iam_policy_document" "lambda_ssm" {
  statement {
    sid    = "SSMReadWebhookSecret"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:*:*:parameter${var.github_webhook_secret_ssm_name}",
    ]
  }
  statement {
    sid       = "KMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_ssm" {
  name   = "ssm-read-webhook-secret"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_ssm.json
}

# ── Security Groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-webhook-relay-sg"
  description = "GitHub webhook relay Lambda - allows outbound to Jenkins NLB and SSM"
  vpc_id      = var.vpc_id

  # Jenkins NLB (port 8080)
  egress {
    description = "Jenkins NLB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSM Parameter Store (HTTPS)
  egress {
    description = "AWS SSM endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-webhook-relay-sg"
  })
}

# Lambda → Jenkins 인바운드 허용 (EKS 클러스터 SG에 규칙 추가)
resource "aws_vpc_security_group_ingress_rule" "jenkins_from_lambda" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Allow webhook-relay Lambda to reach Jenkins on port 8080"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-jenkins-from-lambda"
  })
}

# ── Lambda Function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "webhook_relay" {
  function_name    = "${var.name_prefix}-webhook-relay"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      JENKINS_URL                  = var.jenkins_internal_url
      GITHUB_WEBHOOK_SECRET_PARAM  = var.github_webhook_secret_ssm_name
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-webhook-relay"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_iam_role_policy.lambda_ssm,
  ]
}

# ── API Gateway HTTP API (공개 엔드포인트) ────────────────────────────────────
# GitHub이 webhook을 보낼 유일한 공개 엔드포인트입니다.
# Lambda만 호출하며 Jenkins에는 직접 접근할 수 없습니다.

resource "aws_apigatewayv2_api" "webhook" {
  name          = "${var.name_prefix}-github-webhook"
  protocol_type = "HTTP"
  description   = "GitHub webhook relay → Jenkins (internal)"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-webhook-api"
  })
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook_relay.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true

  tags = var.common_tags
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_relay.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*"
}
