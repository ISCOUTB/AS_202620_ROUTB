from fastapi import FastAPI

app = FastAPI(
    title="ROUTB API",
    description="Esqueleto ejecutable de ROUTB",
    version="0.1.0"
)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def read_root():
    return {"message": "Bienvenido al esqueleto ejecutable de ROUTB"}