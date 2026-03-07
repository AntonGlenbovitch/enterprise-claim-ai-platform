# Terraform Infrastructure

This directory contains reusable Terraform modules for the enterprise claim AI platform.

## Modules

- `s3_datalake`
- `opensearch_vector`
- `bedrock_kb`
- `sagemaker_endpoint`
- `lambda_api`
- `api_gateway`
- `eventbridge`
- `step_functions`
- `dynamodb_audit`

Each module is scaffolded with `main.tf`, `variables.tf`, and `outputs.tf` to support incremental implementation.
