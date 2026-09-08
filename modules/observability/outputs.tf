output "application_log_group_name" {
  description = "Name of the shared CloudWatch application log group."
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "ARN of the shared CloudWatch application log group."
  value       = aws_cloudwatch_log_group.application.arn
}

