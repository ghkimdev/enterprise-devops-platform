FROM python:3.12-slim

WORKDIR /app

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
ENV PYTHONUNBUFFERED=1

# Nexus pypi proxy 사용 예시 (Jenkins 에서 --index-url 로 주입 가능)
# ARG PIP_INDEX_URL=http://nexus.example.com/repository/pypi-proxy/simple/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
