# AWS Setup Guide: Enterprise Claim AI Platform

This guide provides a step-by-step setup path for deploying the platform on AWS.

## Prerequisites
- AWS account with permissions for Bedrock, S3, OpenSearch, SageMaker, EventBridge, Step Functions, Lambda, API Gateway, and DynamoDB.
- Region that supports required Bedrock models (for example `us-east-1`).
- IAM role strategy (separate roles for API Lambda, workflow tasks, and Bedrock KB ingestion).

---

## 1) Enable Bedrock and Claude Access
### Console Instructions
1. Open **Amazon Bedrock** in target region.
2. Go to **Model access**.
3. Select **Manage model access**.
4. Request/enable access for Anthropic Claude models.

### Configuration Parameters
- Region: `us-east-1` (example)
- Model ID examples: `anthropic.claude-3-5-sonnet-*` (region-dependent)
- IAM permissions:
  - `bedrock:InvokeModel`
  - `bedrock:InvokeModelWithResponseStream`

### Verification Steps
- Claude model shows **Access granted** in console.
- A test invoke from allowed role succeeds without `AccessDeniedException`.

---

## 2) Create S3 Data Lake Bucket
### Console Instructions
1. Open **Amazon S3** → **Create bucket**.
2. Name bucket (example): `enterprise-claim-ai-datalake-<env>-<account-id>`.
3. Keep **Block Public Access** enabled.
4. Enable **Versioning**.
5. Create prefixes:
   - `claims/`
   - `policy_docs/`
   - `artifacts/`
   - `logs/`

### Configuration Parameters
- Encryption: SSE-KMS (recommended)
- Lifecycle policy: transition logs/artifacts to infrequent access/archive tiers

### Verification Steps
- Upload and download a test file in each prefix.
- Confirm bucket is private and versioning is enabled.

---

## 3) Create OpenSearch Vector Database
### Console Instructions
1. Open **Amazon OpenSearch Service** (Serverless).
2. Create collection:
   - Name: `claim-policy-vector`
   - Type: **Vector search**
3. Configure encryption, network, and data access policies.
4. Create vector index `policy_vectors` in the collection.

### Configuration Parameters
- Vector field: `embedding`
- Dimension: `1536` (match embedding model)
- Similarity: cosine
- Metadata fields: `doc_id`, `policy_version`, `jurisdiction`, `section`

### Verification Steps
- Collection status is **Active**.
- Insert a sample vector and run KNN query successfully.

---

## 4) Configure Bedrock Knowledge Base
### Console Instructions
1. In Bedrock, open **Knowledge bases** → **Create**.
2. Name: `claim-policy-kb`.
3. Data source: S3 URI `s3://.../policy_docs/`.
4. Vector store: existing OpenSearch Serverless collection.
5. Embedding model: Amazon Titan embeddings.
6. Create service role with S3 read + OpenSearch write/query permissions.
7. Run ingestion/sync job.

### Configuration Parameters
- Chunk size and overlap tuned for policy docs (e.g., 500–1000 tokens with overlap)
- Metadata mapping for filters (policy line, region, effective date)

### Verification Steps
- Ingestion job state: **Succeeded**.
- Test retrieval query returns relevant policy snippets.

---

## 5) Deploy SageMaker Fraud Model Endpoint
### Console Instructions
1. Open **Amazon SageMaker**.
2. Create model (container + model artifact S3 URI).
3. Create endpoint configuration.
4. Create endpoint named `fraud-claim-endpoint`.

### Configuration Parameters
- Instance type: `ml.m5.large` (example baseline)
- Initial instance count: `1`
- Content type: `application/json`
- Timeout/retry policy from caller Lambda or Step Functions task

### Verification Steps
- Endpoint status is **InService**.
- Invoke endpoint with sample claim and confirm score output.

---

## 6) Create EventBridge Event and Rule
### Console Instructions
1. Open **Amazon EventBridge** → **Event buses** (default or custom bus).
2. Create rule name: `claim-analysis-requested-rule`.
3. Event pattern:
   - source: `enterprise.claims`
   - detail-type: `ClaimAnalysisRequested`
4. Target: Step Functions state machine.

### Configuration Parameters
- Event detail JSON should include `claim_id`, `request_id`, timestamp, channel
- Optional dead-letter queue for failed invocations

### Verification Steps
- Send a test event and confirm Step Functions execution starts.

---

## 7) Create Step Functions Workflow
### Console Instructions
1. Open **AWS Step Functions** → **Create state machine**.
2. Use Standard workflow.
3. Add states for:
   - claim context load,
   - RAG retrieval,
   - fraud scoring,
   - Bedrock reasoning,
   - evaluation,
   - audit persistence.
4. Configure retries/catches for transient failures.

### Configuration Parameters
- Timeout: set per state and global execution
- Retry strategy: exponential backoff for Bedrock/OpenSearch/SageMaker calls
- Logging: enable CloudWatch execution logs

### Verification Steps
- Run test execution with known `claim_id`.
- Confirm state transitions complete and output schema is valid.

---

## 8) Deploy Lambda API
### Console Instructions
1. Open **AWS Lambda** → **Create function** (Python runtime).
2. Deploy API handler package.
3. Set environment variables:
   - `EVENT_BUS_NAME`
   - `STATE_MACHINE_ARN` (if needed by design)
   - `LOG_LEVEL`
4. Assign IAM role with EventBridge publish permissions.

### Configuration Parameters
- Memory: 512 MB (example)
- Timeout: 10–30s (API request path)
- Concurrency controls for traffic shaping

### Verification Steps
- Test Lambda with sample payload and verify event publish success.
- Check CloudWatch logs for no unhandled exceptions.

---

## 9) Configure API Gateway Route
### Console Instructions
1. Open **Amazon API Gateway**.
2. Create HTTP API (or REST API).
3. Integrate with Lambda API function.
4. Add route:
   - `POST /claims/analyze`
5. Enable CORS as needed for agent portal.
6. Deploy stage (e.g., `prod`).

### Configuration Parameters
- Auth: IAM/JWT authorizer (recommended)
- Throttling and request validation policies

### Verification Steps
- Call deployed endpoint with `{"claim_id":"CLM1001"}`.
- Confirm API returns queued acknowledgment and logs request.

---

## 10) Create DynamoDB Governance Table
### Console Instructions
1. Open **Amazon DynamoDB** → **Create table**.
2. Table name: `claim_governance_logs`.
3. Partition key: `claim_id` (String).
4. Sort key: `execution_id` (String).
5. Enable point-in-time recovery and encryption.

### Configuration Parameters
- Optional GSIs:
  - `status-index` for workflow status queries
  - `timestamp-index` for operational analytics
- TTL attribute for data retention policies

### Verification Steps
- Write a sample governance item.
- Query by `claim_id` and confirm audit record fields are persisted.

---

## Post-Deployment Validation Checklist
1. `POST /claims/analyze` creates EventBridge event.
2. Step Functions execution is triggered automatically.
3. Workflow successfully calls OpenSearch, SageMaker, and Bedrock.
4. Evaluation output is generated and stored.
5. DynamoDB includes complete audit entry for the run.
6. CloudWatch logs and metrics are visible for observability.
