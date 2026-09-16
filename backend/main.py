from fastapi import APIRouter, FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

# Expose /metrics. Must run before the app starts serving.
Instrumentator().instrument(app).expose(app)

api = APIRouter(prefix="/api")

@api.get("/health")
def health():
    return {"status": "ok"}


app.include_router(api)