# Stage 1 - builder
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2 - runtime  
FROM python:3.12-slim
WORKDIR /app
RUN groupadd --system appgroup && useradd --system --gid appgroup --shell /bin/bash appuser
COPY --from=0 /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=0 /usr/local/bin/uvicorn /usr/local/bin/uvicorn
COPY src/ .
USER appuser
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]