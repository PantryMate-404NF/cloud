terraform {
  # Start with local state so this configuration can bootstrap its own S3 bucket.
  # Migrate to an S3 backend with state locking before team use.
  backend "local" {}
}
