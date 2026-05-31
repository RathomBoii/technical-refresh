import os

from fastapi import FastAPI, Query, Request

app = FastAPI()

# Injected by Kubernetes via secretKeyRef (synced from AWS Secrets Manager
# by the CSI Secrets Store driver). Falls back to None if not set.
API_KEY = os.environ.get("API_KEY")


@app.get("/")
def read_root():
    return {"message": "Hello from Kubernetes"}


@app.get("/health")
def read_health():
    return {"message": "Service is healthy"}


@app.get("/secret-check")
def secret_check():
    """Returns whether the API key is loaded — never expose the actual value."""
    return {"api_key_loaded": API_KEY is not None}

@app.get("/secret-value")
def secret_value(request: Request, key: str = Query(..., description="Env var name to look up, e.g. API_KEY")):
    """Returns the actual env var value — for testing only, not for production.
    
    Usage: /secret-value?key=API_KEY
    """
    value = os.environ.get(key)
    client_ip = request.client.host

    if value is not None:
        return {"client_ip": client_ip, "key": key, "value": value}
    else:
        return {"client_ip": client_ip, "error": f"'{key}' not found in environment variables"}

    



