# Agent Portal: Detailed Explanation

## 1) What the Agent Portal Is
The **Agent Portal** is the front-end entry point used by insurance claim handlers to initiate AI-assisted claim analysis.
In this platform architecture, it is the user-facing system that starts the workflow by sending a request to the backend API.

In practical terms, the portal is where a claim agent:
- enters or selects a claim,
- submits that claim for analysis,
- receives an acknowledgment that analysis has started,
- later reviews AI-generated outputs such as summary, fraud risk, and recommended next actions.

> In this repository, the Agent Portal is represented as an architectural component (documented in `README.md`) and not implemented as a UI codebase.

---

## 2) What It Does
Within the current application flow, the Agent Portal has five core responsibilities.

### A. Claim Intake Trigger
The portal captures a claim identifier (for example, `CLM1001`) from the user and sends it to the analysis endpoint.
- Backend endpoint: `POST /claims/analyze`
- Request body shape: `{ "claim_id": "..." }`

### B. Initiates Asynchronous Processing
The portal does **not** execute AI tasks itself.
Instead, it starts an asynchronous backend pipeline through API Gateway and Lambda/FastAPI.

### C. Handles Immediate API Acknowledgment
After submission, the portal receives the immediate queued response:

```json
{
  "status": "queued",
  "event": "ClaimAnalysisRequested"
}
```

This tells the user the request is accepted and being processed.

### D. User Experience Layer for Analysis Lifecycle
The portal is the natural place to show lifecycle states such as:
- Submitted
- Queued
- In progress
- Completed
- Failed / Needs manual review

(These states are implied by architecture/workflow even though a full state UI is not implemented in this repo.)

### E. Operational and Governance Context Display (Future UI Responsibility)
Because the platform is governance-first, the portal should eventually surface:
- model outputs,
- confidence/risk indicators,
- policy context references,
- audit-friendly execution metadata.

---

## 3) How It Works in This Platform
The Agent Portal’s execution path, based on the current repository architecture, is:

1. Agent submits claim ID in the portal.
2. Portal calls API Gateway route for claim analysis.
3. Lambda API/FastAPI validates and accepts request.
4. Backend publishes `ClaimAnalysisRequested` domain event.
5. EventBridge routes event to Step Functions.
6. Step Functions orchestrates:
   - OpenSearch RAG retrieval,
   - SageMaker fraud scoring,
   - Bedrock Claude reasoning.
7. Evaluation layer validates output quality/consistency.
8. Final outputs and metadata are persisted for governance (DynamoDB, optionally S3 artifacts).
9. Portal can present final outcomes to the claim agent.

This means the portal acts as an orchestrator trigger and user interaction surface, while AI execution occurs fully in backend managed services.

---

## 4) Key Components of an Agent Portal (Reference Design)
Although not implemented in frontend code here, a production Agent Portal typically contains the following logical components.

### 4.1 Presentation Layer
- Claim search/select screen
- Claim analysis submission form
- Analysis results view
- Workflow status indicators

### 4.2 API Integration Layer
- HTTP client for `POST /claims/analyze`
- Authentication token handling
- Request/response schema mapping
- Retry and timeout handling for user-safe interactions

### 4.3 State Management Layer
- Tracks request lifecycle per `claim_id`
- Manages optimistic/pending states in UI
- Handles refresh/re-query logic for asynchronous completion

### 4.4 Notification/Update Mechanism
To reflect asynchronous completion, the portal usually uses one or more of:
- polling APIs,
- webhook callback relay,
- WebSocket/SSE push updates.

### 4.5 Security & Access Control
- User authentication (SSO/IAM/IdP)
- Role-based authorization (e.g., adjuster vs supervisor)
- Session security and audit capture

### 4.6 Compliance & Audit UX
- Expose decision rationale where available
- Provide timestamps and execution identifiers
- Preserve traceability for compliance review

---

## 5) Minimal Data Contract Used Today
Current portal-to-platform request/ack contract is minimal:

### Request
```http
POST /claims/analyze
Content-Type: application/json

{
  "claim_id": "CLM1001"
}
```

### Response
```json
{
  "status": "queued",
  "event": "ClaimAnalysisRequested"
}
```

This contract keeps the portal simple and decouples UI interaction from long-running AI orchestration.

---

## 6) Practical Implementation Notes
If building the actual Agent Portal implementation next, prioritize:

1. **Reliable async UX**: clear queued/in-progress/completed states.
2. **Error ergonomics**: actionable user messages for invalid claim ID, auth failure, or backend unavailability.
3. **Governance visibility**: display outcome, score, and trace metadata in a review-friendly format.
4. **Security hardening**: authn/authz and least-privilege access to claim data.
5. **Performance baseline**: quick submission path and non-blocking result retrieval.

---

## 7) Summary
The Agent Portal is the business-user interface that **starts** claim analysis and **surfaces** results, while backend cloud services execute the AI workflow. In this repository, it is an architectural boundary/component (not a shipped frontend), but its operational role is central: user input, submission control, status visibility, and governance-friendly result presentation.
