## Change Summary

<!-- What does this PR change, and why? -->

## Layer(s) Affected

- [ ] Terraform (account/platform layer: OIDC identities, future security/network policies, external cloud infrastructure)
- [ ] DCM (database object layer: databases, schemas, warehouses, functional roles, grants, masking/row-access policies)
- [ ] CI/CD workflows
- [ ] Documentation only

## Validation Checklist

- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes
- [ ] `terraform plan` output reviewed (posted as a PR comment by the `plan` job)
- [ ] `snow dcm plan` output reviewed (posted as a PR comment by the `dcm-plan` job)
- [ ] No secrets or credentials included in this change
- [ ] Environment-specific values are scoped to the correct `env/<env>/` (Terraform) or target in `manifest.yml` (DCM)

## Environment Impact

<!-- Which environment(s) will this change apply to once merged and deployed? -->

## Rollback Plan

<!-- If this change needs to be reverted after deployment, explain the rollback approach. -->
