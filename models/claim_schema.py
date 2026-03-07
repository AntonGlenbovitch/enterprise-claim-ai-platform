from datetime import date

from pydantic import BaseModel


class ClaimSchema(BaseModel):
    claim_id: str
    member_id: str
    provider_id: str
    procedure_code: str
    diagnosis_code: str
    claim_amount: float
    claim_date: date
