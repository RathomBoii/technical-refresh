# todo: revise to align with this guide: https://testdriven.io/blog/docker-best-practices/
FROM python:3.14.5-slim

WORKDIR /app

COPY requirements.txt .

#  --no-cache-dir: Avoids caching the package index and installed packages, which can save space in the Docker image.
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# CMD instruction specifies the command to run when the container starts.
# using uvicorn as the ASGI server to run the FastAPI application, specifying the host and port to listen on.
# main:app refers to the main.py file and the app instance within that file, which is the FastAPI application we want to run.
# host 0.0.0.0 allows the application to be accessible from outside the container.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]