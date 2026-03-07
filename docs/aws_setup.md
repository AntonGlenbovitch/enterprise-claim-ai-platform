# AWS Infrastructure Setup – Enterprise Claim AI Platform

This document describes how to provision AWS infrastructure for the **enterprise-claim-ai-platform** using the AWS Management Console, with optional AWS CLI commands for automation.

## Prerequisites

- AWS account with permissions to administer: IAM, Bedrock, S3, OpenSearch Serverless, Bedrock Knowledge Bases, SageMaker, EventBridge, Step Functions, Lambda, API Gateway, and DynamoDB.
- AWS CLI v2 configured (`aws configure`) with an administrator or equivalent deployment role.
- A supported region for Amazon Bedrock Claude models (for example `us-east-1` or `us-west-2`; verify current availability in the Bedrock console).
- Python 3.11 and `boto3` if testing SageMaker invocation from local scripts.

---

## Step 1 — Enable Bedrock

### Purpose
Enable access to Anthropic Claude models used by the AI reasoning stage in claim analysis.

### Console Steps
1. Open **Amazon Bedrock** in your target region.
2. Go to **Model access**.
3. Select **Manage model access**.
4. Enable access for **Anthropic Claude** models required by your environment.
5. Submit access request if the account has not previously enabled these models.

### Optional CLI Commands
Model access for foundation models is primarily managed in the console. Use CLI to confirm region and identity context:

```bash
aws sts get-caller-identity
aws configure get region
```

### Configuration Settings
- **Region**: Must be a Bedrock-supported region with Anthropic availability.
- **IAM permissions** for execution roles calling Bedrock should include:
  - `bedrock:InvokeModel`
  - `bedrock:InvokeModelWithResponseStream` (optional streaming)
  - `bedrock:ListFoundationModels` (for discovery)
- If using guardrails or KB retrieval later, add relevant Bedrock permissions as needed.

### Validation Checks
- In Bedrock console, Claude models show as **Access granted**.
- Test a simple invocation from a permitted role (via app or SDK) without `AccessDeniedException`.

---

## Step 2 — Create S3 Data Lake

### Purpose
Provide durable object storage for raw claims, policy documentation used in RAG, and platform logs.

### Console Steps
1. Go to **Amazon S3** → **Create bucket**.
2. Set bucket name: `insurance-ai-datalake` (globally unique; append suffix if needed).
3. Keep **Block Public Access** enabled.
4. Enable **Versioning** (recommended for governance).
5. Create bucket.
6. Open the bucket and create folders (prefixes):
   - `claims/`
   - `policy_docs/`
   - `logs/`

### Optional CLI Commands
```bash
aws s3 mb s3://insurance-ai-datalake
aws s3api put-bucket-versioning \
  --bucket insurance-ai-datalake \
  --versioning-configuration Status=Enabled

aws s3api put-object --bucket insurance-ai-datalake --key claims/
aws s3api put-object --bucket insurance-ai-datalake --key policy_docs/
aws s3api put-object --bucket insurance-ai-datalake --key logs/
```

### Configuration Settings
- `claims/`: JSON/CSV claim intake payloads, claim evidence metadata.
- `policy_docs/`: Policy PDFs, endorsements, rule manuals for retrieval augmentation.
- `logs/`: Execution traces, model prompts/responses (sanitized), audit exports.
- Apply server-side encryption (SSE-S3 or SSE-KMS).
- Add lifecycle policies for archival and cost control.

### Validation Checks
- Upload and retrieve a test file from each prefix.
- Confirm bucket policy denies public access.
- Confirm versioning status is **Enabled**.

---

## Step 3 — Create OpenSearch Vector Database

### Purpose
Store vector embeddings of policy content and run low-latency similarity search for RAG.

### Console Steps
1. Open **Amazon OpenSearch Service** → **Serverless**.
2. Create collection:
   - Name: `policy-vector-db`
   - Type: **Vector search**
3. Configure security:
   - Encryption policy (AWS owned key or KMS CMK)
   - Network policy (VPC-restricted preferred for production)
   - Data access policy allowing Bedrock Knowledge Base role and admin role.
4. After collection is active, create index `policy_vectors` using OpenSearch APIs or Dev Tools.

### Optional CLI Commands
Use the OpenSearch endpoint with signed requests (sample payload for index creation):

```bash
curl -X PUT "https://<opensearch-endpoint>/policy_vectors" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "index": {
        "knn": true
      }
    },
    "mappings": {
      "properties": {
        "text": { "type": "text" },
        "source": { "type": "keyword" },
        "chunk_id": { "type": "keyword" },
        "embedding": {
          "type": "knn_vector",
          "dimension": 1536,
          "method": {
            "name": "hnsw",
            "space_type": "cosinesimil",
            "engine": "faiss"
          }
        }
      }
    }
  }'
```

### Configuration Settings
- **Vector dimension**: Match embedding model output (Titan embeddings often 1536; verify model version).
- **Similarity search**: Cosine similarity (common for semantic embeddings).
- **Security**:
  - Encrypt at rest.
  - Restrict network access (private endpoints where possible).
  - Least-privilege data access policies for ingestion/query roles.

### Validation Checks
- Collection status is **Active**.
- `policy_vectors` index exists.
- A test vector insert + KNN query returns nearest results.

---

## Step 4 — Create Bedrock Knowledge Base

### Purpose
Connect policy documents in S3 to a managed retrieval layer backed by OpenSearch vectors.

### Console Steps
1. In **Amazon Bedrock**, go to **Knowledge bases** → **Create**.
2. Choose name (for example, `policy-rag-kb`).
3. Select **Data source**: Amazon S3.
4. Set S3 URI to `s3://insurance-ai-datalake/policy_docs/`.
5. Choose vector store: **Amazon OpenSearch Serverless**.
6. Select collection `policy-vector-db` and index `policy_vectors`.
7. Select embedding model: **Titan Embeddings**.
8. Provide/create IAM service role for Bedrock KB with S3 read + OpenSearch access.
9. Create knowledge base and run initial sync/ingestion job.

### Optional CLI Commands
Knowledge base creation is typically console-first; use CLI for sync operations (when available in your AWS CLI version):

```bash
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id <KB_ID> \
  --data-source-id <DATA_SOURCE_ID>

aws bedrock-agent get-ingestion-job \
  --knowledge-base-id <KB_ID> \
  --data-source-id <DATA_SOURCE_ID> \
  --ingestion-job-id <JOB_ID>
```

### Configuration Settings
- Chunking strategy: start with default; tune chunk size/overlap after retrieval quality testing.
- Metadata mapping: include policy version, jurisdiction, line of business for filtering.
- IAM role must include:
  - `s3:GetObject`, `s3:ListBucket`
  - OpenSearch Serverless data access actions
  - Bedrock KB service permissions.

### Validation Checks
- Ingestion job completes with status **Succeeded**.
- Test retrieval in Knowledge Base console returns expected policy excerpts.

---

## Step 5 — Deploy SageMaker Fraud Model

### Purpose
Host and expose a fraud detection model for near-real-time scoring during claim analysis.

### Console Steps
1. Open **Amazon SageMaker** → **Models** → **Create model**.
2. Provide model artifacts (S3 URI) and inference container image.
3. Create **Endpoint configuration** with instance type and variant weights.
4. Create endpoint:
   - Name: `fraud-claim-endpoint`
5. Wait until endpoint status is **InService**.

### Optional CLI Commands
```bash
aws sagemaker create-model --model-name fraud-claim-model --primary-container Image=<ecr-image>,ModelDataUrl=s3://<bucket>/<model.tar.gz> --execution-role-arn <role-arn>

aws sagemaker create-endpoint-config --endpoint-config-name fraud-claim-config --production-variants VariantName=AllTraffic,ModelName=fraud-claim-model,InitialInstanceCount=1,InstanceType=ml.m5.large

aws sagemaker create-endpoint --endpoint-name fraud-claim-endpoint --endpoint-config-name fraud-claim-config
```

Example `boto3` invocation:

```python
import json
import boto3

runtime = boto3.client("sagemaker-runtime", region_name="us-east-1")

payload = {
    "claim_id": "CLM-100045",
    "claim_amount": 18450.75,
    "incident_type": "collision",
    "policy_tenure_months": 14,
    "prior_claim_count": 2
}

resp = runtime.invoke_endpoint(
    EndpointName="fraud-claim-endpoint",
    ContentType="application/json",
    Body=json.dumps(payload)
)

result = json.loads(resp["Body"].read())
print(result)
```

### Configuration Settings
- Enable data capture/model monitor if governance requires drift tracking.
- Endpoint role should allow CloudWatch logging and model artifact read from S3.
- Define timeout/retry policy in calling Lambda or Step Functions task.

### Validation Checks
- Endpoint status is **InService**.
- Test invocation returns a fraud score and confidence payload.

---

## Step 6 — Create EventBridge Event

### Purpose
Decouple API ingestion from orchestration by emitting domain events that trigger workflows.

### Console Steps
1. Open **Amazon EventBridge** → **Event buses**.
2. Use default bus or create a custom bus (recommended for platform isolation).
3. Create a rule for event type `ClaimAnalysisRequested`.
4. Set target as Step Functions state machine `ClaimAnalysisWorkflow`.
5. Configure input transformer/passthrough so event detail becomes workflow input.

### Optional CLI Commands
Example event publish:

```bash
aws events put-events --entries '[
  {
    "Source": "enterprise.claims.api",
    "DetailType": "ClaimAnalysisRequested",
    "Detail": "{\"claim_id\":\"CLM-100045\",\"policy_id\":\"POL-5561\"}",
    "EventBusName": "default"
  }
]'
```

Event pattern example for the rule:

```json
{
  "source": ["enterprise.claims.api"],
  "detail-type": ["ClaimAnalysisRequested"]
}
```

### Configuration Settings
- Standardize `source` and `detail-type` naming.
- Add DLQ/retry settings for resilient delivery.
- Ensure EventBridge rule role can `states:StartExecution` on the workflow.

### Validation Checks
- Send test event and confirm rule metrics show matched invocation.
- Verify a Step Functions execution is started with expected input.

---

## Step 7 — Create Step Functions Workflow

### Purpose
Orchestrate the end-to-end claim analysis flow across retrieval, fraud scoring, LLM reasoning, and persistence.

### Console Steps
1. Open **AWS Step Functions** → **State machines** → **Create**.
2. Choose **Standard** workflow.
3. Name: `ClaimAnalysisWorkflow`.
4. Paste ASL JSON definition (example below).
5. Attach execution role with access to Lambda, Bedrock, SageMaker, and DynamoDB actions used in tasks.
6. Create and test with sample input.

### Optional CLI Commands
```bash
aws stepfunctions create-state-machine \
  --name ClaimAnalysisWorkflow \
  --type STANDARD \
  --definition file://claim-analysis-workflow.json \
  --role-arn <step-functions-role-arn>
```

Example state machine JSON:

```json
{
  "Comment": "Enterprise claim analysis orchestration",
  "StartAt": "retrieve_claim",
  "States": {
    "retrieve_claim": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "retrieve-claim-lambda",
        "Payload.$": "$"
      },
      "ResultPath": "$.claim",
      "Next": "retrieve_policy"
    },
    "retrieve_policy": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "retrieve-policy-rag-lambda",
        "Payload.$": "$"
      },
      "ResultPath": "$.policy_context",
      "Next": "run_fraud_model"
    },
    "run_fraud_model": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:sagemakerruntime:invokeEndpoint",
      "Parameters": {
        "EndpointName": "fraud-claim-endpoint",
        "Body.$": "States.JsonToString($.claim.Payload)",
        "ContentType": "application/json"
      },
      "ResultPath": "$.fraud",
      "Next": "llm_reasoning"
    },
    "llm_reasoning": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "bedrock-reasoning-lambda",
        "Payload.$": "$"
      },
      "ResultPath": "$.llm",
      "Next": "store_result"
    },
    "store_result": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Parameters": {
        "TableName": "ai_claim_analysis",
        "Item": {
          "claim_id": { "S.$": "$.claim.Payload.claim_id" },
          "analysis_result": { "S.$": "States.JsonToString($.llm.Payload)" },
          "audit_logs": { "S.$": "States.JsonToString($)" },
          "timestamp": { "S.$": "$$.State.EnteredTime" }
        }
      },
      "End": true
    }
  }
}
```

### Configuration Settings
- Task timeouts and retries for Bedrock/SageMaker calls.
- CloudWatch Logs enabled for execution history.
- Consider Express workflow only if ultra-high throughput and short duration are prioritized.

### Validation Checks
- Manual execution completes successfully.
- Each state returns expected output and writes final record to DynamoDB.

---

## Step 8 — Create Lambda API

### Purpose
Expose backend API logic for claim analysis requests and event publication/orchestration kickoff.

### Console Steps
1. Open **AWS Lambda** → **Create function**.
2. Choose **Author from scratch**:
   - Function name: `claim-analysis-api`
   - Runtime: `Python 3.11`
   - Handler: `claim_routes.handler`
3. Upload deployment package or connect to CI/CD pipeline.
4. Configure environment variables (example below).
5. Attach IAM role with least-privilege permissions.

### Optional CLI Commands
```bash
zip function.zip claim_routes.py requirements.txt
aws lambda create-function \
  --function-name claim-analysis-api \
  --runtime python3.11 \
  --handler claim_routes.handler \
  --zip-file fileb://function.zip \
  --role <lambda-role-arn>
```

### Configuration Settings
Suggested environment variables:
- `EVENT_BUS_NAME` = `default` (or custom bus)
- `STATE_MACHINE_ARN` = ARN of `ClaimAnalysisWorkflow` (if invoking directly)
- `DDB_TABLE` = `ai_claim_analysis`
- `BEDROCK_REGION` = target Bedrock region

Required IAM role permissions (adjust to implementation):
- `events:PutEvents`
- `states:StartExecution` (if direct workflow start)
- `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:UpdateItem`
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

### Validation Checks
- Lambda test event returns HTTP-style response payload.
- CloudWatch logs confirm successful event publish/workflow start.

---

## Step 9 — Configure API Gateway

### Purpose
Provide secure HTTP endpoint for portal/backend integrations to submit claim analysis requests.

### Console Steps
1. Open **Amazon API Gateway** → **Create API** → **REST API**.
2. Create resource path `/claims` and child resource `/analyze`.
3. Add method `POST` on `/claims/analyze`.
4. Integration type: **Lambda Function**.
5. Select function `claim-analysis-api`.
6. Enable CORS if React portal calls this endpoint from browser.
7. Deploy API to stage (for example, `prod`).

### Optional CLI Commands
```bash
# Example invocation once deployed
curl -X POST "https://<api-id>.execute-api.<region>.amazonaws.com/prod/claims/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "claim_id": "CLM-100045",
    "policy_id": "POL-5561",
    "customer_id": "CUST-7782",
    "claim_amount": 18450.75,
    "incident_description": "Rear-end collision at traffic signal"
  }'
```

### Configuration Settings
- Enable request validation/model schemas for contract enforcement.
- Configure throttling and usage plans where needed.
- Use IAM/Cognito/authorizer for authenticated access.

### Validation Checks
- `POST /claims/analyze` returns 2xx and request identifier.
- API Gateway execution logs show successful Lambda integration.

---

## Step 10 — Create DynamoDB Table

### Purpose
Persist final AI analysis artifacts and audit trail fields for governance, explainability, and compliance.

### Console Steps
1. Open **Amazon DynamoDB** → **Create table**.
2. Table name: `ai_claim_analysis`.
3. Partition key: `claim_id` (String).
4. Use on-demand capacity unless predictable high throughput suggests provisioned mode.
5. Enable point-in-time recovery (recommended).

### Optional CLI Commands
```bash
aws dynamodb create-table \
  --table-name ai_claim_analysis \
  --attribute-definitions AttributeName=claim_id,AttributeType=S \
  --key-schema AttributeName=claim_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Configuration Settings
Recommended attributes in each item:
- `claim_id` (PK)
- `analysis_result` (LLM explanation + decision metadata)
- `audit_logs` (workflow steps, model versions, prompt references)
- `timestamp` (ISO 8601 or epoch)

Governance support:
- Full decision lineage for auditors.
- Reproducibility inputs (model IDs/version tags).
- Traceability for adverse action explanations and policy compliance.

### Validation Checks
- Insert and retrieve a test item.
- Confirm Step Functions `store_result` task writes expected fields.

---

## Verifying the System

Run an end-to-end test of the operational path:

1. **Agent sends request** to `POST /claims/analyze` (API Gateway).
2. **API Gateway invokes Lambda** `claim-analysis-api`.
3. **Lambda publishes EventBridge event** (`ClaimAnalysisRequested`) or starts workflow directly.
4. **EventBridge triggers Step Functions** `ClaimAnalysisWorkflow`.
5. **Step Functions orchestrates AI services**:
   - Retrieves claim/policy context (Lambda + Knowledge Base retrieval)
   - Calls SageMaker `fraud-claim-endpoint`
   - Calls Bedrock Claude for explanation synthesis
6. **Workflow stores output in DynamoDB** table `ai_claim_analysis`.

Example `curl` request:

```bash
curl -X POST "https://<api-id>.execute-api.<region>.amazonaws.com/prod/claims/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "claim_id": "CLM-100045",
    "policy_id": "POL-5561",
    "incident_type": "collision",
    "claim_amount": 18450.75,
    "incident_description": "Rear-end collision at traffic signal",
    "attachments": ["s3://insurance-ai-datalake/claims/CLM-100045/evidence-1.jpg"]
  }'
```

Expected verification outcomes:
- API response returns accepted/request ID.
- EventBridge metrics show event publication and matched rule.
- Step Functions execution succeeds with all five states completed.
- DynamoDB record for `claim_id=CLM-100045` includes `analysis_result`, `audit_logs`, and `timestamp`.
- CloudWatch logs contain correlated trace IDs across API, Lambda, and workflow components.

---

## Operational Recommendations

- Use Infrastructure as Code (CloudFormation/Terraform/CDK) after validating this console-first setup.
- Enforce least privilege IAM and KMS encryption for all data services.
- Enable centralized observability (CloudWatch dashboards, alarms, X-Ray where applicable).
- Add cost controls: S3 lifecycle, OpenSearch capacity planning, SageMaker autoscaling, and API throttling.
