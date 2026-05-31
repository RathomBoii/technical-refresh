import json
import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI

app = FastAPI()


def get_secret(secret_name: str, region: str = "ap-southeast-1") -> dict:
    """Fetch a secret from AWS Secrets Manager and return it as a dict."""
    client = boto3.client("secretsmanager", region_name=region)
    try:
        response = client.get_secret_value(SecretId=secret_name)
    except ClientError as e:
        raise RuntimeError(f"Failed to retrieve secret '{secret_name}': {e}")

    return json.loads(response["SecretString"])


@app.get("/")
def read_root():
    return {"message": "Hello from Kubernetes"}


@app.get("/secret-demo")
def secret_demo():
    """
    Demo endpoint: reads a secret from Secrets Manager and returns the keys (not values!).
    In a real app, you'd use the values internally (e.g., connect to a DB) — never expose them.
    """
    secret = get_secret("helloworld/app/config")
    return {
        "message": "Successfully read secret from AWS Secrets Manager",
        "secret_keys_found": list(secret.keys()),  # only show keys, not values
    }
