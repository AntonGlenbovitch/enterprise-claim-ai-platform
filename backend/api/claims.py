from fastapi import APIRouter
from pydantic import BaseModel

from backend.services.event_publisher import publisher

router = APIRouter(prefix="/claims", tags=["claims"])


class AnalyzeClaimRequest(BaseModel):
    claim_id: str


class AnalyzeClaimResponse(BaseModel):
    status: str
    event: str


@router.post("/analyze", response_model=AnalyzeClaimResponse)
def analyze_claim(request: AnalyzeClaimRequest) -> AnalyzeClaimResponse:
    event_name = "ClaimAnalysisRequested"
    publisher.publish(event_name, payload={"claim_id": request.claim_id})
    return AnalyzeClaimResponse(status="queued", event=event_name)
