# Test Plan: Enterprise Claim AI Platform

## System Test Overview
This document describes how to test the end-to-end behavior of the enterprise claim AI platform. The objective is to validate API ingestion, workflow orchestration, AI component integration, and governance logging.

## Prerequisites
- API endpoint deployed locally or in AWS.
- Access to EventBridge and Step Functions execution logs.
- Bedrock model access enabled for Claude.
- SageMaker fraud endpoint deployed and `InService`.
- OpenSearch vector index populated with policy docs.
- DynamoDB governance table created.

## Local API Testing
Run local API:
```bash
uvicorn backend.api.app:app --reload --port 8000
```

Send request:
```bash
curl -X POST http://127.0.0.1:8000/claims/analyze \
  -H 'Content-Type: application/json' \
  -d '{"claim_id":"CLM1001"}'
```

Expected local API acknowledgment:
```json
{
  "status": "queued",
  "event": "ClaimAnalysisRequested"
}
```

## Example API Request
```http
POST /claims/analyze
Content-Type: application/json

{
  "claim_id": "CLM1001"
}
```

Expected downstream workflow business response example:
```json
{
  "claim_summary": "...",
  "fraud_risk_score": 0.73,
  "recommended_action": "Investigate claim"
}
```

## Integration Testing
### Goal
Verify all platform integrations work as one pipeline.

### Steps
1. Submit `/claims/analyze` request.
2. Confirm event emitted to EventBridge (`ClaimAnalysisRequested`).
3. Confirm Step Functions execution starts.
4. Confirm OpenSearch retrieval and SageMaker scoring states succeed.
5. Confirm Bedrock reasoning state returns schema-valid output.
6. Confirm final record written to DynamoDB.

### Pass Criteria
- No failed Step Functions states.
- Output includes claim summary, fraud risk score, and recommendation.
- Governance record exists and includes execution metadata.

## Workflow Testing
### Goal
Validate orchestration behavior (retries, catches, state transitions).

### Steps
1. Execute state machine with a known valid claim.
2. Execute with intentionally malformed or missing claim context.
3. Inspect retry behavior and error handling branches.
4. Confirm terminal statuses map to expected operational outcomes.

### Pass Criteria
- Success path completes all required states.
- Failure path logs error and routes to fallback/manual-review state.

## Bedrock Inference Test
### Goal
Validate Claude reasoning service connectivity and schema consistency.

### Steps
1. Send structured prompt with claim facts and retrieved policy snippets.
2. Capture model response.
3. Validate output keys and value types.

### Pass Criteria
- Model responds within configured timeout.
- Output follows required JSON schema.
- Recommendation text references context rather than unsupported claims.

## SageMaker Endpoint Test
### Goal
Validate fraud scoring endpoint performance and output.

### Steps
1. Invoke `fraud-claim-endpoint` with sample feature payload.
2. Measure latency and parse response.
3. Verify score range is between 0 and 1.

### Pass Criteria
- Endpoint responds successfully (`HTTP 200`).
- Response includes `fraud_risk_score` and optional explanation fields.

## RAG Retrieval Test
### Goal
Validate retrieval quality from OpenSearch vector index.

### Steps
1. Query index with claim-related text.
2. Retrieve top-K policy passages.
3. Inspect relevance and metadata quality.

### Pass Criteria
- Returned snippets are policy-relevant.
- Metadata includes identifiers usable for audit (doc ID/section/version).

## Governance and Audit Validation
### Goal
Ensure every analysis is traceable.

### Steps
1. Run end-to-end claim analysis.
2. Query DynamoDB by `claim_id`.
3. Verify stored fields: execution ID, timestamps, model references, outputs.

### Pass Criteria
- One or more audit entries exist for execution.
- Stored data is complete enough for compliance review.
