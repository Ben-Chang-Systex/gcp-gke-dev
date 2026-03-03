terraform {
  backend "gcs" {
    bucket = "ben-test-terraform-state-bucket"
    prefix = "terraform/app/state"
  }
}