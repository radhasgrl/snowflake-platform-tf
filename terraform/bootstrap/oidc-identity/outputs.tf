output "oidc_provider_arn" {
  description = "Paste into future stacks that need to reference the shared GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "Paste into .github/workflows/*.yml as the role-to-assume value"
  value       = aws_iam_role.github_actions_terraform.arn
}
