from fastapi import FastAPI

from backend.api.claims import router as claims_router

app = FastAPI(title="Enterprise Claim AI Platform")
app.include_router(claims_router)
