from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from Kubernetes"}

@app.get("/health")
def read_health():
    return {"message": "Service is healthy"}

@app.get("/client-ip")
def get_client_ip(request: Request):
    x_forwarded_for = request.headers.get("x-forwarded-for")
    x_real_ip = request.headers.get("x-real-ip")

    if x_forwarded_for:
        client_ip = x_forwarded_for.split(",")[0].strip()
    elif x_real_ip:
        client_ip = x_real_ip
    else:
        client_ip = request.client.host

    return {"client_ip": client_ip}


