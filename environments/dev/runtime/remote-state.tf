data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket       = var.terraform_state_bucket_name
    key          = var.foundation_state_key
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}
