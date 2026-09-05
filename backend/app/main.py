from fastapi import FastAPI
from app.core.database import engine, Base
from app.modules.users.router import router as users_router
from app.modules.trips.router import router as trips_router
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(
    title="ROUTB API",
    description="Esqueleto ejecutable de ROUTB",
    version="0.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(trips_router, prefix="/trips", tags=["trips"])

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def read_root():
    return {"message": "Bienvenido al esqueleto ejecutable de ROUTB"}