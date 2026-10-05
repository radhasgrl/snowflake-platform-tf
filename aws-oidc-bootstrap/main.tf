# GitHub's OIDC issuer — one provider per AWS account, shared across all repos/projects.
# If this AWS account already has a GitHub OIDC provider (from another project),
# do not create a second one — reuse the existing provider's ARN instead.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Role the pipeline assumes via AssumeRoleWithWebIdentity — no stored AWS secret required.
# Scoped to this specific repo; any branch/PR in the repo can assume it.
# Tighten the "sub" condition to a specific branch/environment if stricter scoping is needed.
resource "aws_iam_role" "github_actions_terraform" {
  name = "snowflake-platform-tf-github-oidc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # GitHub's current sub claim format includes stable account/repo IDs
            # (e.g. repo:owner@ownerId/repo@repoId:ref:...), not just owner/repo.
            # This is more secure than name-based matching (immune to repo renames).
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@*/${var.github_repo}@*:*"
          }
        }
      }
    ]
  })
}

# Same S3 permissions the static IAM user (terraform-platform-svc) has today —
# read/write/list on the Terraform state bucket only.
resource "aws_iam_role_policy" "terraform_state_access" {
  name = "terraform-state-s3-access"
  role = aws_iam_role.github_actions_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.state_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.state_bucket_name}/*"
      }
    ]
  })
}

# Expands this same CI role's permissions so it can also manage the ingestion-domain AWS
# resources defined in the main module's ingestion_aws_infra.tf (migrated from Repo 2's
# standalone aws/ Terraform root — see that file's header comment). Narrowly scoped to the
# exact resource names/ARNs involved, not a blanket S3/IAM grant, to keep this identity's
# blast radius limited to the resources it's actually meant to manage.
resource "aws_iam_role_policy" "ingestion_infra_management" {
  name = "ingestion-aws-infra-management"
  role = aws_iam_role.github_actions_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageIngestionBucket"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketLocation",
          "s3:GetEncryptionConfiguration",
          "s3:ListBucket",
        ]
        Resource = "arn:aws:s3:::data-ingestion-raw-525218385225"
      },
      {
        Sid    = "ManageIngestionRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
        ]
        Resource = [
          "arn:aws:iam::525218385225:role/data-ingestion-raw-github-oidc",
          "arn:aws:iam::525218385225:role/data-ingestion-raw-snowflake-storage-integration",
        ]
      },
      {
        Sid      = "ReadSharedOidcProvider"
        Effect   = "Allow"
        Action   = ["iam:GetOpenIDConnectProvider"]
        Resource = aws_iam_openid_connect_provider.github_actions.arn
      }
    ]
  })
}
