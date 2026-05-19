# Instructions for Nano Banana 2: Simple Application Flowchart

## Goal
Generate a **simple flowchart** for the Enterprise Claim AI Platform that includes **only** the components/tools/functionality currently used by this application.

## Scope Constraints
- Keep the diagram minimal and easy to read.
- Use **boxes only** (rectangles) and directional arrows.
- Do **not** include speculative/future components.
- Do **not** include internal implementation details not represented in this repo’s documented architecture.

## Components to Include (and only these)
Use one box for each of the following, in this order:

1. **Agent Portal**
2. **API Gateway**
3. **Lambda API (FastAPI claims endpoint)**
4. **EventBridge**
5. **Step Functions AI Workflow**
6. **RAG Retrieval (OpenSearch)**
7. **Fraud Scoring (SageMaker Endpoint)**
8. **LLM Reasoning (Amazon Bedrock Claude)**
9. **Evaluation Layer**
10. **DynamoDB Audit & Governance Logs**
11. **S3 Data Lake (artifacts/evidence)**

## Flow Requirements
- Primary flow should be top-down (or left-to-right) with arrows.
- Show that the AI workflow orchestrates the three AI tasks:
  - RAG Retrieval (OpenSearch)
  - Fraud Scoring (SageMaker)
  - LLM Reasoning (Bedrock Claude)
- Show final persistence to:
  - DynamoDB Audit & Governance Logs
  - S3 Data Lake

## Labeling Requirements
- Box labels should match the component names above exactly (minor formatting differences are acceptable).
- Avoid extra annotations, legends, or color keys unless absolutely necessary.

## Output Format
Produce:
1. A clean flowchart image (PNG or SVG).
2. A plain-text version of the same flow (ASCII or Mermaid) for easy version control.

## Mermaid Template (Preferred)
Use this exact structure as baseline and keep it simple:

```mermaid
flowchart TD
    A[Agent Portal] --> B[API Gateway]
    B --> C[Lambda API (FastAPI claims endpoint)]
    C --> D[EventBridge]
    D --> E[Step Functions AI Workflow]

    E --> F[RAG Retrieval (OpenSearch)]
    E --> G[Fraud Scoring (SageMaker Endpoint)]
    E --> H[LLM Reasoning (Amazon Bedrock Claude)]

    E --> I[Evaluation Layer]
    I --> J[DynamoDB Audit & Governance Logs]
    I --> K[S3 Data Lake (artifacts/evidence)]
```

## Acceptance Checklist
- [ ] Diagram uses only boxes and arrows.
- [ ] Diagram includes only listed in-scope components.
- [ ] Orchestration from Step Functions to RAG/Fraud/LLM is explicit.
- [ ] Outputs to DynamoDB and S3 are explicit.
- [ ] No extra or future-state services are added.
