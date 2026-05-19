# Enterprise Claim AI Platform

## Project Overview
The **Enterprise Claim AI Platform** is a production-oriented reference architecture for AI-assisted insurance claim analysis. It combines event-driven AWS services and multiple AI components to help claim agents quickly understand claims, evaluate fraud risk, and decide next actions.

The platform is designed to:
- intake claim-analysis requests from an agent portal,
- orchestrate AI and ML services in a governed workflow,
- retrieve policy context with RAG,
- score fraud risk using SageMaker,
- reason over evidence using Amazon Bedrock (Claude), and
- persist audit trails for governance and compliance.

## Architecture Diagram (ASCII)
```text
+-------------------+
| Agent Portal      |
+-------------------+
          |
          v
+-------------------+
| API Gateway       |
+-------------------+
          |
          v
+-------------------+
| Lambda API        |
+-------------------+
          |
          v
+-------------------+
| EventBridge       |
+-------------------+
          |
          v
+------------------------------+
| Step Functions AI Workflow   |
+------------------------------+
          |
          v
+------------------------------+
| AI Orchestrator              |
| - RAG retrieval (OpenSearch) |
| - Fraud model (SageMaker)    |
| - Bedrock Claude reasoning   |
+------------------------------+
          |
          v
+-------------------+
| Evaluation Layer  |
+-------------------+
          |
          v
+-------------------+
| DynamoDB Audit    |
| & Governance Logs |
+-------------------+
```

## Key Features
- **Event-driven claim analysis** with decoupled ingestion and processing.
- **RAG-based policy grounding** using OpenSearch-backed retrieval.
- **Fraud scoring service** hosted on Amazon SageMaker endpoints.
- **LLM reasoning with Bedrock Claude** for summary, risk explanation, and recommendations.
- **Step Functions orchestration** for resilient, observable, and stateful AI workflows.
- **Governance-first design** with DynamoDB audit logs and traceability.
- **S3 data lake integration** for claim evidence, policy corpus, and workflow artifacts.

## Technology Stack
- **API & Compute**: Amazon API Gateway, AWS Lambda, Python/FastAPI
- **Eventing & Orchestration**: Amazon EventBridge, AWS Step Functions
- **Generative AI**: Amazon Bedrock (Claude)
- **ML Inference**: Amazon SageMaker endpoint (fraud scoring)
- **Retrieval Layer**: Amazon OpenSearch (vector retrieval / RAG)
- **Storage & Governance**: Amazon S3, Amazon DynamoDB
- **Infrastructure as Code (present in repo)**: Terraform

## Repository Structure
```text
enterprise-claim-ai-platform/
├── backend/
│   ├── api/                    # FastAPI routes (claim analysis endpoint)
│   ├── services/               # Event publishing, RAG, fraud, LLM services
│   ├── evaluation/             # Response quality and evaluation hooks
│   ├── governance/             # Governance-related modules
│   └── models/                 # API/domain models
├── docs/
│   ├── architecture.md         # Detailed architecture and data flow
│   └── aws_setup.md            # AWS deployment/setup guide
├── terraform/                  # Infrastructure templates (providers, vars, outputs)
├── tests/
│   └── test.md                 # End-to-end testing guide
└── README.md
```

## System Workflow
1. A claim agent initiates analysis from the portal.
2. `POST /claims/analyze` is called via API Gateway.
3. Lambda API validates payload and emits a `ClaimAnalysisRequested` event.
4. EventBridge routes the event to a Step Functions state machine.
5. The workflow invokes:
   - OpenSearch retrieval for policy and precedent context,
   - SageMaker fraud endpoint for risk scoring,
   - Bedrock Claude for claim reasoning and recommendation.
6. An evaluation layer checks output quality and policy consistency.
7. Final output and decision metadata are written to DynamoDB governance logs.
8. Optional artifacts and intermediate payloads are persisted to S3.

## Local Development Setup
1. Clone repository:
   ```bash
   git clone <your-repo-url>
   cd enterprise-claim-ai-platform
   ```
2. Create and activate Python virtual environment:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run API locally:
   ```bash
   uvicorn backend.api.app:app --reload --port 8000
   ```
5. Test endpoint:
   ```bash
   curl -X POST http://127.0.0.1:8000/claims/analyze \
     -H 'Content-Type: application/json' \
     -d '{"claim_id":"CLM1001"}'
   ```

## AWS Deployment Overview
- Provision foundational resources (S3, OpenSearch, DynamoDB).
- Enable Bedrock model access and configure Knowledge Base ingestion.
- Deploy SageMaker fraud scoring endpoint.
- Create EventBridge rule and Step Functions workflow.
- Deploy Lambda API and expose route with API Gateway.
- Validate complete request-to-analysis flow and governance logging.

For detailed deployment steps, see [docs/aws_setup.md](docs/aws_setup.md).

## Example API Request
**Request**
```http
POST /claims/analyze
Content-Type: application/json

{
  "claim_id": "CLM1001"
}
```

**Typical asynchronous acknowledgment (current API contract):**
```json
{
  "status": "queued",
  "event": "ClaimAnalysisRequested"
}
```

**Downstream workflow result (target business output):**
```json
{
  "claim_summary": "Rear-end collision with moderate vehicle damage and no injury.",
  "fraud_risk_score": 0.73,
  "recommended_action": "Investigate claim"
}
```

## Future Improvements
- Add multi-model routing and fallback across Bedrock model families.
- Introduce confidence calibration and human-in-the-loop escalation thresholds.
- Implement policy citation tracing in every generated recommendation.
- Add red-team evaluation suites for hallucination and bias control.
- Expand observability with CloudWatch dashboards and cost/performance KPIs.
