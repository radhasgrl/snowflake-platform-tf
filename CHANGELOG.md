# Changelog

## [1.1.1](https://github.com/radhasgrl/snowflake-platform-tf/compare/v1.1.0...v1.1.1) (2026-10-07)


### Bug Fixes

* **terraform:** allow TEST Customer storage integration's external ID ([#40](https://github.com/radhasgrl/snowflake-platform-tf/issues/40)) ([5985b3d](https://github.com/radhasgrl/snowflake-platform-tf/commit/5985b3dd6bac73f725af8b209b113a07bebabfe5))

## [1.1.0](https://github.com/radhasgrl/snowflake-platform-tf/compare/v1.0.0...v1.1.0) (2026-10-07)


### Features

* add AWS OIDC provider/role Terraform (human-applied, not pipeline) ([e386bed](https://github.com/radhasgrl/snowflake-platform-tf/commit/e386bede87a652056908c07a750fa2b9ce3425b0))
* add environment-aware Snowflake RBAC foundation ([54875e3](https://github.com/radhasgrl/snowflake-platform-tf/commit/54875e33b1cb8b7efb39c259b513ca4adde8836d))
* add GITHUB_DEV_INGEST_SVC identity + RBAC for Repo 2 (data-ingestion-raw) ([fc7c4b0](https://github.com/radhasgrl/snowflake-platform-tf/commit/fc7c4b0a12dfd43720bf408f0a88125490006892))
* add read-only-scoped Snowflake OIDC identity for terraform-plan.yml (Stage 1) ([886f4a5](https://github.com/radhasgrl/snowflake-platform-tf/commit/886f4a53059e4185deeebff8a8980eeb9bf4e19d))
* add terraform plan and apply GitHub Actions workflows ([e6df0d3](https://github.com/radhasgrl/snowflake-platform-tf/commit/e6df0d342e4b7f9241454d6a14deceeb9880f922))
* add workflow_dispatch trigger for manual pipeline runs ([848cf7e](https://github.com/radhasgrl/snowflake-platform-tf/commit/848cf7ee57c89a9a0638b8b81f425f10491f01df))
* **ci:** add promote.yml for version-based TEST environment promotion ([#39](https://github.com/radhasgrl/snowflake-platform-tf/issues/39)) ([af72ff7](https://github.com/radhasgrl/snowflake-platform-tf/commit/af72ff797b6a59920b9b1b45a3e488a959832171))
* **ci:** add release-please for Conventional-Commits-driven versioning ([#30](https://github.com/radhasgrl/snowflake-platform-tf/issues/30)) ([116b795](https://github.com/radhasgrl/snowflake-platform-tf/commit/116b795c6ef5f4d2bfabeffec2804272e1d70827))
* **ci:** enforce Conventional Commits on PR titles ([#29](https://github.com/radhasgrl/snowflake-platform-tf/issues/29)) ([6832a9b](https://github.com/radhasgrl/snowflake-platform-tf/commit/6832a9b1d5809ae003c4dea1bc0d508b5d43c98d))
* create GitHub OIDC service user for Snowflake (Stage 1) ([afd86cf](https://github.com/radhasgrl/snowflake-platform-tf/commit/afd86cf69a1cc82ef3df385c9d08e2c04b50e4a7))
* **dcm:** add CUSTOMER_TEST target to Customer domain manifest ([#38](https://github.com/radhasgrl/snowflake-platform-tf/issues/38)) ([0af3987](https://github.com/radhasgrl/snowflake-platform-tf/commit/0af3987c56a37a7d45a80ed3708920a34bd82957))
* migrate GitHub Actions AWS auth to OIDC (AssumeRoleWithWebIdentity) ([06b7312](https://github.com/radhasgrl/snowflake-platform-tf/commit/06b7312004f3da5a0bbba1464205c80636812b75))
* move Repo 2's AWS infra (S3 bucket + IAM roles) into this repo's Terraform ([#7](https://github.com/radhasgrl/snowflake-platform-tf/issues/7)) ([7ac1342](https://github.com/radhasgrl/snowflake-platform-tf/commit/7ac13422d6c87bf44bb94dad104307a5f6d4af76))
* Phase 0-2 foundation - Terraform provider, S3 remote state, bootstrap ([42b3b61](https://github.com/radhasgrl/snowflake-platform-tf/commit/42b3b61985f9162e44fdc780d3e3621470c57bb9))
* Phase 4 - Snowflake foundation databases, schemas, warehouses (DEV) ([469fc2e](https://github.com/radhasgrl/snowflake-platform-tf/commit/469fc2e10391bea716c201867a7017d4c6492515))
* scaffold placeholder masking policy and row access policy ([2f93847](https://github.com/radhasgrl/snowflake-platform-tf/commit/2f938472dd9c9b1aafb92fdd2d4463ce94589e25))
* switch terraform-apply.yml to Snowflake OIDC auth (Stage 2/3) ([2b67e80](https://github.com/radhasgrl/snowflake-platform-tf/commit/2b67e80457d6c9175008087fb6d526bed34da7e1))
* switch terraform-plan.yml to Snowflake OIDC auth (Stage 2) ([6fde03a](https://github.com/radhasgrl/snowflake-platform-tf/commit/6fde03aa9381c1abadd39a3fa709ee4aac924380))
* switch terraform-plan.yml to Snowflake OIDC auth (Stage 2) ([b0c3cfd](https://github.com/radhasgrl/snowflake-platform-tf/commit/b0c3cfd2e0ee5e263923d3902f4224beab477c36))
* **terraform:** add TEST_ADMIN_DB for TEST-tier DCM project homes ([#36](https://github.com/radhasgrl/snowflake-platform-tf/issues/36)) ([8309cfe](https://github.com/radhasgrl/snowflake-platform-tf/commit/8309cfe35e96ae0eb1bc1852a9d49d7e9bbf4d7e))
* **terraform:** add TEST-scoped Customer domain identities ([#37](https://github.com/radhasgrl/snowflake-platform-tf/issues/37)) ([6abca73](https://github.com/radhasgrl/snowflake-platform-tf/commit/6abca7355724bbf803b6629cdadac23ab78ee9b9))
* **terraform:** add TEST-tier platform OIDC identities ([#35](https://github.com/radhasgrl/snowflake-platform-tf/issues/35)) ([2c2e2d6](https://github.com/radhasgrl/snowflake-platform-tf/commit/2c2e2d64a7885ec988c74440efb0546d94f2faa6))
* **terraform:** rename env/qa to env/test ([#34](https://github.com/radhasgrl/snowflake-platform-tf/issues/34)) ([94e72d3](https://github.com/radhasgrl/snowflake-platform-tf/commit/94e72d3fe5e2981afdfca9147cac410e6a478454))


### Bug Fixes

* 'CREATE OR ALTER USER' is not valid Snowflake syntax ([761f11b](https://github.com/radhasgrl/snowflake-platform-tf/commit/761f11bb80fbcba629c8325f567f663545e9f011))
* add missing 'snow dcm create --if-not-exists' step before plan/deploy ([6c336d1](https://github.com/radhasgrl/snowflake-platform-tf/commit/6c336d1f715f7cf2703901a64fcc3d156db2ef99))
* add write access (MARTS) and CREATE VIEW (STAGING) for dbt ([602f1c2](https://github.com/radhasgrl/snowflake-platform-tf/commit/602f1c2f1eb258708d2025a6aefd44e489f27117))
* **ci:** drop component prefix from release-please tags ([#32](https://github.com/radhasgrl/snowflake-platform-tf/issues/32)) ([0101d30](https://github.com/radhasgrl/snowflake-platform-tf/commit/0101d306d2818815c0931a98c06b06f5523bf78c))
* correct GitHub OIDC subject claim format (includes owner/repo IDs) ([d28d884](https://github.com/radhasgrl/snowflake-platform-tf/commit/d28d8847b3a6d64b07fdd9eca737a5dd0b4e7c3b))
* create individual Snowflake RBAC grants ([0efdc85](https://github.com/radhasgrl/snowflake-platform-tf/commit/0efdc853bd56cfcf058dc2a6bed50de8b038e2c3))
* GITHUB_DEV_DCM_SVC session had no role (defaulted to PUBLIC) ([5fa81a7](https://github.com/radhasgrl/snowflake-platform-tf/commit/5fa81a7901ef8f2cd694cfc7d9c2966e7038ec7e))
* grant CREATE SCHEMA on DEV_CUSTOMER_DB to the transform functional role ([6899f04](https://github.com/radhasgrl/snowflake-platform-tf/commit/6899f0428ecdc5a38b113fff6be08b3893eba5e8))
* migrate S3 state backend from eu-west-1 to ap-southeast-2 (Sydney) ([cd87333](https://github.com/radhasgrl/snowflake-platform-tf/commit/cd8733321cd9bcd3d9be1a30c2f7bfbbd45b9b14))
* remove misleading qa/prod dropdown, add terraform fmt/validate CI checks ([#6](https://github.com/radhasgrl/snowflake-platform-tf/issues/6)) ([5ebf549](https://github.com/radhasgrl/snowflake-platform-tf/commit/5ebf54943d49969017f74f571944b7ab5a7da1ba))
* revert TERRAFORM_SVC/DBT_SVC to CREATE USER IF NOT EXISTS (avoid unnecessary churn) ([931f35d](https://github.com/radhasgrl/snowflake-platform-tf/commit/931f35d0b6217eadf79e7f9ab046216e4f6be217))

## 1.0.0 (2026-10-07)


### Features

* add AWS OIDC provider/role Terraform (human-applied, not pipeline) ([e386bed](https://github.com/radhasgrl/snowflake-platform-tf/commit/e386bede87a652056908c07a750fa2b9ce3425b0))
* add environment-aware Snowflake RBAC foundation ([54875e3](https://github.com/radhasgrl/snowflake-platform-tf/commit/54875e33b1cb8b7efb39c259b513ca4adde8836d))
* add GITHUB_DEV_INGEST_SVC identity + RBAC for Repo 2 (data-ingestion-raw) ([fc7c4b0](https://github.com/radhasgrl/snowflake-platform-tf/commit/fc7c4b0a12dfd43720bf408f0a88125490006892))
* add read-only-scoped Snowflake OIDC identity for terraform-plan.yml (Stage 1) ([886f4a5](https://github.com/radhasgrl/snowflake-platform-tf/commit/886f4a53059e4185deeebff8a8980eeb9bf4e19d))
* add terraform plan and apply GitHub Actions workflows ([e6df0d3](https://github.com/radhasgrl/snowflake-platform-tf/commit/e6df0d342e4b7f9241454d6a14deceeb9880f922))
* add workflow_dispatch trigger for manual pipeline runs ([848cf7e](https://github.com/radhasgrl/snowflake-platform-tf/commit/848cf7ee57c89a9a0638b8b81f425f10491f01df))
* **ci:** add release-please for Conventional-Commits-driven versioning ([#30](https://github.com/radhasgrl/snowflake-platform-tf/issues/30)) ([116b795](https://github.com/radhasgrl/snowflake-platform-tf/commit/116b795c6ef5f4d2bfabeffec2804272e1d70827))
* **ci:** enforce Conventional Commits on PR titles ([#29](https://github.com/radhasgrl/snowflake-platform-tf/issues/29)) ([6832a9b](https://github.com/radhasgrl/snowflake-platform-tf/commit/6832a9b1d5809ae003c4dea1bc0d508b5d43c98d))
* create GitHub OIDC service user for Snowflake (Stage 1) ([afd86cf](https://github.com/radhasgrl/snowflake-platform-tf/commit/afd86cf69a1cc82ef3df385c9d08e2c04b50e4a7))
* migrate GitHub Actions AWS auth to OIDC (AssumeRoleWithWebIdentity) ([06b7312](https://github.com/radhasgrl/snowflake-platform-tf/commit/06b7312004f3da5a0bbba1464205c80636812b75))
* move Repo 2's AWS infra (S3 bucket + IAM roles) into this repo's Terraform ([#7](https://github.com/radhasgrl/snowflake-platform-tf/issues/7)) ([7ac1342](https://github.com/radhasgrl/snowflake-platform-tf/commit/7ac13422d6c87bf44bb94dad104307a5f6d4af76))
* Phase 0-2 foundation - Terraform provider, S3 remote state, bootstrap ([42b3b61](https://github.com/radhasgrl/snowflake-platform-tf/commit/42b3b61985f9162e44fdc780d3e3621470c57bb9))
* Phase 4 - Snowflake foundation databases, schemas, warehouses (DEV) ([469fc2e](https://github.com/radhasgrl/snowflake-platform-tf/commit/469fc2e10391bea716c201867a7017d4c6492515))
* scaffold placeholder masking policy and row access policy ([2f93847](https://github.com/radhasgrl/snowflake-platform-tf/commit/2f938472dd9c9b1aafb92fdd2d4463ce94589e25))
* switch terraform-apply.yml to Snowflake OIDC auth (Stage 2/3) ([2b67e80](https://github.com/radhasgrl/snowflake-platform-tf/commit/2b67e80457d6c9175008087fb6d526bed34da7e1))
* switch terraform-plan.yml to Snowflake OIDC auth (Stage 2) ([6fde03a](https://github.com/radhasgrl/snowflake-platform-tf/commit/6fde03aa9381c1abadd39a3fa709ee4aac924380))
* switch terraform-plan.yml to Snowflake OIDC auth (Stage 2) ([b0c3cfd](https://github.com/radhasgrl/snowflake-platform-tf/commit/b0c3cfd2e0ee5e263923d3902f4224beab477c36))


### Bug Fixes

* 'CREATE OR ALTER USER' is not valid Snowflake syntax ([761f11b](https://github.com/radhasgrl/snowflake-platform-tf/commit/761f11bb80fbcba629c8325f567f663545e9f011))
* add missing 'snow dcm create --if-not-exists' step before plan/deploy ([6c336d1](https://github.com/radhasgrl/snowflake-platform-tf/commit/6c336d1f715f7cf2703901a64fcc3d156db2ef99))
* add write access (MARTS) and CREATE VIEW (STAGING) for dbt ([602f1c2](https://github.com/radhasgrl/snowflake-platform-tf/commit/602f1c2f1eb258708d2025a6aefd44e489f27117))
* correct GitHub OIDC subject claim format (includes owner/repo IDs) ([d28d884](https://github.com/radhasgrl/snowflake-platform-tf/commit/d28d8847b3a6d64b07fdd9eca737a5dd0b4e7c3b))
* create individual Snowflake RBAC grants ([0efdc85](https://github.com/radhasgrl/snowflake-platform-tf/commit/0efdc853bd56cfcf058dc2a6bed50de8b038e2c3))
* GITHUB_DEV_DCM_SVC session had no role (defaulted to PUBLIC) ([5fa81a7](https://github.com/radhasgrl/snowflake-platform-tf/commit/5fa81a7901ef8f2cd694cfc7d9c2966e7038ec7e))
* grant CREATE SCHEMA on DEV_CUSTOMER_DB to the transform functional role ([6899f04](https://github.com/radhasgrl/snowflake-platform-tf/commit/6899f0428ecdc5a38b113fff6be08b3893eba5e8))
* migrate S3 state backend from eu-west-1 to ap-southeast-2 (Sydney) ([cd87333](https://github.com/radhasgrl/snowflake-platform-tf/commit/cd8733321cd9bcd3d9be1a30c2f7bfbbd45b9b14))
* remove misleading qa/prod dropdown, add terraform fmt/validate CI checks ([#6](https://github.com/radhasgrl/snowflake-platform-tf/issues/6)) ([5ebf549](https://github.com/radhasgrl/snowflake-platform-tf/commit/5ebf54943d49969017f74f571944b7ab5a7da1ba))
* revert TERRAFORM_SVC/DBT_SVC to CREATE USER IF NOT EXISTS (avoid unnecessary churn) ([931f35d](https://github.com/radhasgrl/snowflake-platform-tf/commit/931f35d0b6217eadf79e7f9ab046216e4f6be217))
