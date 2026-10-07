# Deliberately broken HCL syntax -- throwaway, testing the Terraform-Plan-fails path
resource "this_is_not_valid" {
  this will not parse ???
}
