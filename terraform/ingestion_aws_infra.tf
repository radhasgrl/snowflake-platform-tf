# Ingestion-domain AWS infrastructure for Repo 2 (data-ingestion-raw). Provisioned here,
# not in Repo 2, because this repo's stated purpose is "provision resources" for the whole
# platform — Repo 2 is scoped to ingestion CODE only (the SQL that defines the storage
# integration/stage/pipe), not infrastructure. Mirrors exactly how this repo already
# provisions Repo 2's and Repo 3's Snowflake identities (oidc_service_user.tf) — this just
# extends the same pattern to Repo 2's AWS-side resources.
#
# Migrated from a standalone aws/ Terraform root in Repo 2 via `terraform import` (not
# destroy+recreate) — same bucket, same IAM roles, same ARNs, zero resource disruption.
# See data-ingestion-raw's git history (aws/main.tf, now deleted) for the original.

# GitHub's OIDC provider is one-per-AWS-account — already created by bootstrap/oidc-identity/ (relative to this terraform/ folder).
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# Role data-ingestion-raw's own GitHub Actions workflows assume via
# AssumeRoleWithWebIdentity — scoped to that repo specifically (this repo's own AWS OIDC
# role, snowflake-platform-tf-github-oidc, is scoped only to snowflake-platform-tf and
# can't be reused by a different repo's workflows).
resource "aws_iam_role" "github_actions_ingestion" {
  name = "data-ingestion-raw-github-oidc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:radhasgrl@*/data-ingestion-raw@*:*"
          }
        }
      }
    ]
  })
}

# Source bucket for the ingestion demo — CSV files land here and Snowpipe loads them into
# DEV_CUSTOMER_DB.RAW.CUSTOMERS.
resource "aws_s3_bucket" "ingestion_raw" {
  bucket = "data-ingestion-raw-525218385225"
}

resource "aws_s3_bucket_versioning" "ingestion_raw" {
  bucket = aws_s3_bucket.ingestion_raw.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role_policy" "ingestion_bucket_access" {
  name = "ingestion-raw-s3-access"
  role = aws_iam_role.github_actions_ingestion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.ingestion_raw.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.ingestion_raw.arn}/*"
      }
    ]
  })
}

# Separate IAM role: the one Snowflake itself assumes (via STORAGE_AWS_IAM_USER_ARN) to
# read the bucket for the storage integration / external stage — distinct from the GitHub
# Actions role above. Trust policy already tightened to Snowflake's real IAM user (not a
# placeholder) — values confirmed via `DESC INTEGRATION DEV_CUSTOMER_RAW_S3_INTEGRATION`
# when this was first set up in Repo 2.
#
# sts:ExternalId is a LIST, not a single value: each separate storage integration object
# (one per domain per environment -- e.g. the DEV Customer integration and the TEST
# Customer integration created for promote.yml) gets its own unique external ID from
# Snowflake, even though they all share this same IAM user ARN. Confirmed via a real
# `DESC INTEGRATION CUSTOMER_TEST_RAW_S3_INTEGRATION` during Repo 2's Phase B TEST
# promotion work -- its external ID genuinely differs from the original DEV integration's.
resource "aws_iam_role" "snowflake_storage_integration" {
  name = "data-ingestion-raw-snowflake-storage-integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::465768368231:user/z5d32000-s"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = [
              "VI78575_SFCRole=5067_APry05W3ikq5QIYzhvgRm9D+Yi8=", # DEV Customer integration
              "VI78575_SFCRole=5470_NPWnwPsunUhyGynZ6Xfu5WYxNvw=", # TEST Customer integration
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "snowflake_storage_integration_access" {
  name = "snowflake-storage-integration-s3-access"
  role = aws_iam_role.snowflake_storage_integration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.ingestion_raw.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.ingestion_raw.arn
      }
    ]
  })
}
