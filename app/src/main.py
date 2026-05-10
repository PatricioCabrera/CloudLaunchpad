from fastapi import FastAPI

# FastAPI instance — this is what uvicorn serves
app = FastAPI(title="CloudLaunchpad API")

@app.get("/health")
def health_check():
    # ALB target group hits this — must return 200 or task is marked unhealthy
    return {"status": "ok"}

@app.post("/visit")
def register_visit():
    # Stub — RDS integration comes in Month 2
    return {"message": "visit registered"}

@app.get("/visits")
def list_visits(limit: int = 100):
    # Stub — will query PostgreSQL when RDS module is wired
    return {"visits": [], "limit": limit}


@app.post("/notes")
def create_note():
    # Stub
    return {"message": "note created"}


@app.get("/notes/{note_id}")
def get_note(note_id: int):
    # Stub
    return {"note_id": note_id, "content": None}


@app.get("/metrics")
def get_metrics():
    # Stub — will return CloudWatch-sourced SLIs for the dashboard
    return {"p95_latency_ms": None, "error_rate": None}