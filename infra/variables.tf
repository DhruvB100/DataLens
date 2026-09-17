# passed in via terraform.tfvars (gitignored), never hardcoded here
variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name"
}

# secret - also comes from terraform.tfvars, sensitive hides it from plan/apply output
variable "gemini_api_key" {
  type        = string
  description = "Gemini LLM API key"
  sensitive   = true
}