from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from Kubernetes"}

@app.get("/health")
def read_health():
    return {"message": "Service is healthy"}


