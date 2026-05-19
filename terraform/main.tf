locals {
  lambda_function_name      = "claim-analysis-api"
  sagemaker_endpoint_name   = "fraud-claim-endpoint"
  opensearch_collection_name = "policy-vector-db"
  opensearch_index_name     = "policy_vectors"
}

module "s3_datalake" {
  source      = "./modules/s3_datalake"
  bucket_name = "insurance-ai-datalake"
}

module "opensearch_vector" {
  source               = "./modules/opensearch_vector"
  collection_name      = local.opensearch_collection_name
  collection_type      = var.opensearch_collection_type
  vector_index_name    = local.opensearch_index_name
  vector_dimension     = 1536
  vector_similarity    = "cosine"
}

module "dynamodb_audit" {
  source     = "./modules/dynamodb_audit"
  table_name = "ai_claim_analysis"
}

module "sagemaker_endpoint" {
  source                = "./modules/sagemaker_endpoint"
  endpoint_name         = local.sagemaker_endpoint_name
  endpoint_instance_type = "ml.m5.large"
  endpoint_instance_count = 1
}

module "lambda_api" {
  source                  = "./modules/lambda_api"
  function_name           = local.lambda_function_name
  bedrock_model           = var.bedrock_model
  sagemaker_endpoint_name = module.sagemaker_endpoint.endpoint_name
  opensearch_collection_arn = module.opensearch_vector.collection_arn
  opensearch_index_name   = module.opensearch_vector.vector_index_name
  s3_bucket_arn           = module.s3_datalake.bucket_arn
  dynamodb_table_arn      = module.dynamodb_audit.table_arn
}

module "step_functions" {
  source                 = "./modules/step_functions"
  state_machine_name     = "ClaimAnalysisWorkflow"
  lambda_function_arn    = module.lambda_api.lambda_function_arn
  lambda_function_name   = module.lambda_api.lambda_function_name
}

module "eventbridge" {
  source                   = "./modules/eventbridge"
  event_bus_name           = "claim-analysis-bus"
  rule_name                = "ClaimAnalysisRequested"
  state_machine_arn        = module.step_functions.state_machine_arn
  state_machine_name       = module.step_functions.state_machine_name
}

module "api_gateway" {
  source              = "./modules/api_gateway"
  api_name            = "claim-analysis-api"
  lambda_function_arn = module.lambda_api.lambda_function_arn
  lambda_function_name = module.lambda_api.lambda_function_name
}

module "bedrock_kb" {
  source                         = "./modules/bedrock_kb"
  knowledge_base_name            = "enterprise-claim-policy-kb"
  embedding_model_arn            = var.titan_embedding_model_arn
  s3_bucket_arn                  = module.s3_datalake.bucket_arn
  s3_policy_docs_prefix          = "policy_docs/"
  opensearch_collection_arn      = module.opensearch_vector.collection_arn
  opensearch_collection_endpoint = module.opensearch_vector.collection_endpoint
  vector_index_name              = module.opensearch_vector.vector_index_name
}
