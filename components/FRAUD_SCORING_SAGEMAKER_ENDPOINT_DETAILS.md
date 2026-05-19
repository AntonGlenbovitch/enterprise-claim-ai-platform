# Fraud Scoring (SageMaker Endpoint): Detailed Explanation

## 1) What Fraud Scoring (SageMaker Endpoint) Is
The **Fraud Scoring** component is the machine-learning risk assessment stage in the claim-analysis workflow. Its purpose is to estimate the likelihood that a submitted claim exhibits fraud indicators.

In this architecture, the fraud model is deployed behind an **Amazon SageMaker real-time inference endpoint**. The orchestration workflow sends claim features to that endpoint and receives a fraud probability score used by downstream reasoning and decision support.

---

## 2) What It Does
Fraud Scoring has five core responsibilities in this platform.

### A. Produces Quantitative Fraud Risk Signal
It transforms structured claim input into a numeric risk output (typically a probability between `0.0` and `1.0`).

### B. Standardizes ML Inference Behind an Endpoint Interface
It exposes fraud prediction through a managed API boundary (SageMaker Runtime `invoke_endpoint`) so the orchestrator does not need model-internal logic.

### C. Supports Decisioning and Triage
Its score contributes to downstream recommendation logic, helping route claims to:
- auto-approve/low-risk review,
- standard review,
- or enhanced investigation/manual review.

### D. Enables Operational Scalability
Because inference runs in SageMaker-managed infrastructure, scaling and serving behavior are decoupled from API and orchestration code.

### E. Contributes to Governance/Auditability
The fraud score becomes part of persisted decision artifacts and helps explain why a claim was escalated or flagged.

---

## 3) How It Works in This Platform
Based on repository code and architecture docs, the runtime path is:

1. Claim-analysis workflow begins from a queued request event.
2. Workflow gathers/constructs claim payload needed for fraud inference.
3. Service layer calls SageMaker Runtime endpoint using JSON payload.
4. Endpoint returns prediction payload.
5. Platform extracts fraud probability and normalizes it to float.
6. Score is passed to downstream reasoning/evaluation/persistence stages.

In the current backend service implementation, this behavior is encapsulated in `predict_fraud_risk(claim_payload)`.

---

## 4) Service-Level Behavior in Current Code
The current fraud service implementation (`backend/services/fraud_service.py`) provides a clear inference wrapper.

### 4.1 Required Configuration
- Environment variable: `FRAUD_SAGEMAKER_ENDPOINT`
- If missing, the service raises `FraudPredictionError`.

### 4.2 Invocation Method
- Uses `boto3.client("sagemaker-runtime")`.
- Calls `invoke_endpoint` with:
  - `EndpointName=<value from FRAUD_SAGEMAKER_ENDPOINT>`
  - `ContentType="application/json"`
  - `Body=<json-encoded claim payload>`

### 4.3 Response Processing
- Reads response body bytes and parses JSON.
- Extracts a fraud probability via `_extract_probability(...)`.

Accepted response patterns include:
- raw number (`0.73`),
- list where first item is number (`[0.73]`),
- list of dict with key in `fraud_probability | probability | score`,
- dict with key in `fraud_probability | probability | score`.

### 4.4 Error Handling
Raises `FraudPredictionError` for:
- missing endpoint configuration,
- SageMaker invocation failures (`ClientError`, `BotoCoreError`),
- malformed/invalid response payloads.

This keeps the fraud-scoring integration predictable for orchestrator callers.

---

## 5) Key Components of Fraud Scoring Integration
A production-ready fraud scoring stage typically includes these logical components.

### 5.1 Feature Input Contract
- Well-defined schema for claim features (claim attributes, policy signals, behavioral indicators, metadata).
- Versioned payload format to avoid model/producer drift.

### 5.2 Inference Endpoint
- SageMaker real-time endpoint hosting the trained fraud model.
- Runtime endpoint name managed via environment/config.

### 5.3 Inference Client Wrapper
- Service function encapsulating call mechanics, serialization, deserialization, and exception mapping.
- In this repo, `predict_fraud_risk(...)` is that wrapper.

### 5.4 Output Normalization Layer
- Converts heterogeneous model output shapes into a stable scalar probability.
- Enforces type conversion and validation before downstream use.

### 5.5 Decision Threshold Layer (Workflow/Business Logic)
- Applies business thresholds to map probability to actions or review tiers.
- Example conceptual bands:
  - low risk: `0.00–0.30`
  - medium risk: `0.31–0.70`
  - high risk: `0.71–1.00`

### 5.6 Monitoring & Governance
- Capture endpoint latency/error rate.
- Track score distributions and drift.
- Persist score + model/version metadata for audit.

---

## 6) Input/Output Contract (Conceptual)

### Example Input Payload
```json
{
  "claim_id": "CLM1001",
  "claim_amount": 5400,
  "incident_type": "rear_end_collision",
  "prior_claim_count": 2,
  "policy_tenure_months": 18
}
```

### Example Endpoint Return Shapes Supported by Current Parser
```json
0.73
```

```json
[0.73]
```

```json
{"fraud_probability": 0.73}
```

```json
[{"score": 0.73}]
```

### Normalized Platform Output
```json
{
  "fraud_risk_score": 0.73
}
```

---

## 7) Reliability and Security Considerations
When hardening this stage, prioritize:

1. **Timeout/retry policy tuning** for endpoint calls.
2. **Idempotent orchestration behavior** for duplicate events.
3. **Schema validation** before invocation.
4. **Least-privilege IAM** for runtime invocation permissions.
5. **Model/version traceability** in governance records.
6. **Graceful degradation** if endpoint is unavailable (fallback/manual review branch).

---

## 8) How It Fits With Other AI Stages
Fraud scoring is one signal among several:
- **RAG retrieval** adds policy/legal context,
- **Bedrock reasoning** turns evidence + scores into narrative recommendations,
- **Evaluation layer** validates quality/consistency,
- **Governance stores** retain outputs for compliance.

This layered design reduces over-reliance on a single model score.

---

## 9) Summary
Fraud Scoring (SageMaker Endpoint) is the platform’s quantitative risk engine. It accepts claim features, returns a normalized fraud probability, and feeds downstream orchestration, reasoning, and governance decisions. In this repository, the integration is implemented through a focused service wrapper with explicit config requirements and robust payload parsing/error handling.
