# When you apply this code, Terraform will spit out an AWS API Gateway URL. 
# You will copy this URL and paste it into your GitHub App settings.

output "github_webhook_endpoint" {
  description = "Copy this URL and paste it into the Webhook URL field in your GitHub App settings"
  value       = module.github_runner.webhook.endpoint
}