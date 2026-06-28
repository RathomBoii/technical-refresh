FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# CMD instruction specifies the command to run when the container starts.
# using uvicorn as the ASGI server to run the FastAPI application, specifying the host and port to listen on.
# main:app refers to the main.py file and the app instance within that file, which is the FastAPI application we want to run.
# host 0.0.0.0 allows the application to be accessible from outside the container.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]