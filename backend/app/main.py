import json
import logging
import sys
import time
from datetime import datetime, timezone
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.modules.auth.infrastructure.router import router as auth_router
from app.modules.requests.infrastructure.router import router as requests_router
from app.modules.trips.infrastructure.router import router as trips_router
from app.modules.users.infrastructure.router import router as users_router

# Configuración de logger estructurado a stdout
logger = logging.getLogger("routb.access")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.propagate = False

app = FastAPI(
    title="ROUTB API",
    description="ROUTB",
    version="0.2.0",
)

@app.middleware("http")
async def structured_logging_middleware(request: Request, call_next):
    start_time = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - start_time) * 1000, 2)

    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "method": request.method,
        "path": request.url.path,
        "status_code": response.status_code,
        "duration_ms": duration_ms,
        "client_ip": request.client.host if request.client else None,
    }
    logger.info(json.dumps(log_entry))
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(trips_router, prefix="/trips", tags=["trips"])
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(requests_router, prefix="/requests", tags=["requests"])


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def read_root():
    return {"message": "Bienvenido a ROUTB"}