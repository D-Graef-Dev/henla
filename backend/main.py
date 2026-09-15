from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

# Expose /metrics. Must run before the app starts serving.
Instrumentator().instrument(app).expose(app)


@app.get("/health")
def health():
    return {"status": "ok"}