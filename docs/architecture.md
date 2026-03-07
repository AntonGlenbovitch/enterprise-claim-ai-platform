# Architecture: Enterprise Claim AI Platform

## 1) System Overview
The platform provides AI-assisted claim analysis for insurance agents. A request enters through an API, is transformed into an event, and then processed through an orchestrated AI workflow. The workflow combines retrieval, fraud scoring, and language-model reasoning to produce explainable recommendations. Governance metadata is stored for audit and compliance.

## 2) Architecture Components
```text
+---------------------+     +-------------------+     +---------------------+
| Agent Portal / CRM  +---->+ API Gateway       +---->+ Lambda API           |
+---------------------+     +-------------------+     +---------------------+
                                                               |
                                                               v
                                                     +-------------------+
                                                     | EventBridge       |
                                                     +-------------------+
                                                               |
                                                               v
                                                     +-------------------+
                                                     | Step Functions    |
                                                     | State Machine     |
                                                     +-------------------+
                                                               |
        +----------------------------+-------------------------+---------------------------+
        |                            |                         |                           |
        v                            v                         v                           v
+------------------+      +------------------+      +----------------------+    +-----------------+
| OpenSearch       |      | SageMaker        |      | Bedrock Claude       |    | S3 Data Lake    |
| (RAG retrieval)  |      | Fraud Endpoint   |      | Reasoning            |    | (docs/artifacts)|
+------------------+      +------------------+      +----------------------+    +-----------------+
                                                               |
                                                               v
                                                     +-------------------+
                                                     | Evaluation Layer  |
                                                     +-------------------+
                                                               |
                                                               v
                                                     +-------------------+
                                                     | DynamoDB          |
                                                     | Governance Logs   |
                                                     +-------------------+
```

Component responsibilities:
- **API Gateway**: external API exposure, authentication, throttling, request routing.
- **Lambda API**: request validation and event publication.
- **EventBridge**: domain event routing and decoupling.
- **Step Functions**: orchestration, retries, branch logic, timeout/error handling.
- **OpenSearch**: vector retrieval for policy and historical knowledge.
- **SageMaker**: fraud score and risk feature inference.
- **Bedrock (Claude)**: explainable reasoning over claim + retrieved context + fraud features.
- **S3**: raw inputs, policy corpora, intermediate and final artifacts.
- **DynamoDB**: immutable/append-style governance and audit records.

## 3) AI Orchestration Layer
The AI orchestration layer is implemented as Step Functions states plus service-specific Lambda tasks (or direct service integrations). A common sequence:
1. Normalize claim payload.
2. Retrieve contextual documents (RAG).
3. Score claim fraud probability.
4. Build structured prompt with claim + context + fraud features.
5. Invoke Claude for analysis and recommendation.
6. Evaluate answer quality and policy alignment.
7. Persist outputs and audit records.

Design considerations:
- Idempotency key based on `claim_id` and request timestamp.
- Retry policies for transient failures (Bedrock throttling, OpenSearch timeouts).
- DLQ/error path for manual review.

## 4) RAG Knowledge Retrieval
The RAG layer uses an OpenSearch vector index populated from policy documents stored in S3.

Retrieval flow:
1. Ingest policy documents from S3.
2. Chunk text and generate embeddings.
3. Store vectors + metadata in OpenSearch.
4. At runtime, query with claim-specific embedding.
5. Return top-K snippets with metadata (policy section, version, jurisdiction).

```text
S3 policy_docs/ --> Chunk + Embed --> OpenSearch Vector Index --> Top-K context --> Prompt Context
```

Best practices:
- Filter retrieval by product line and policy version.
- Keep chunk size tuned for semantic coherence.
- Record retrieval citations for downstream auditability.

## 5) Fraud Detection Model
Fraud scoring runs as a managed SageMaker endpoint.

Typical inference features:
- claim amount,
- claimant history,
- policy tenure,
- incident type,
- anomaly indicators.

Output usually includes:
- `fraud_risk_score` (0 to 1),
- optional explanation features or SHAP-like attributions.

This score is fed into the reasoning stage as structured context, not as a deterministic decision.

## 6) Bedrock Claude Reasoning
Bedrock Claude receives a structured prompt containing:
- normalized claim facts,
- retrieved policy/legal excerpts,
- fraud scoring signals,
- business response schema.

Expected reasoning outputs:
- concise claim summary,
- consistency checks against policy terms,
- recommended action (approve/review/investigate),
- confidence indicators and rationale.

Guardrails:
- prompt templates for deterministic formatting,
- response validation to enforce output schema,
- optional hallucination checks before finalization.

## 7) Event-Driven Workflow
EventBridge enables asynchronous, loosely coupled architecture.

```text
ClaimAnalysisRequested event
  -> EventBridge rule
  -> Step Functions execution
  -> AI/ML tasks + evaluations
  -> Persist final decision + audit trail
```

Advantages:
- independent scaling of API and workflow tiers,
- easier replay/backfill from event archive,
- clearer operational visibility for each processing stage.

## 8) AI Evaluation Layer
The evaluation layer checks quality before delivering outcomes.

Evaluation dimensions:
- **Factual grounding**: whether summary aligns with claim inputs.
- **Policy consistency**: recommendation aligns with retrieved policy excerpts.
- **Fraud coherence**: recommendation reflects fraud score appropriately.
- **Schema validity**: required JSON fields present and typed.

Failed checks can route to:
- regeneration with adjusted prompts,
- manual review queue,
- incident alerting.

## 9) Governance and Audit Logging
DynamoDB stores governance artifacts keyed by `claim_id` + execution ID.

Common attributes:
- request metadata (who, when, source channel),
- retrieval references (doc IDs/sections),
- model versions/endpoints,
- fraud score and thresholds,
- final recommendation and evaluation results,
- timestamps and workflow status.

Governance goals:
- traceability for regulators and internal audit,
- reproducibility for post-incident review,
- lifecycle retention and compliance controls.

## 10) Data Flow
```text
(1) Agent submits claim_id
(2) API Gateway -> Lambda validates request
(3) Lambda publishes ClaimAnalysisRequested to EventBridge
(4) EventBridge triggers Step Functions state machine
(5) Workflow loads claim context and evidence from S3
(6) Workflow queries OpenSearch for policy/context snippets (RAG)
(7) Workflow invokes SageMaker endpoint for fraud score
(8) Workflow invokes Bedrock Claude with consolidated context
(9) Evaluation layer validates quality and policy alignment
(10) Workflow writes outputs + audit record to DynamoDB
(11) Result becomes available to agent-facing systems
```

Service interaction summary:
- **API Gateway + Lambda** handle ingress and domain event creation.
- **EventBridge + Step Functions** coordinate resilient asynchronous processing.
- **OpenSearch + S3 + Bedrock Knowledge Base pattern** provide grounding context.
- **SageMaker + Bedrock** combine predictive risk with generative reasoning.
- **DynamoDB** preserves governance state and decision history.
