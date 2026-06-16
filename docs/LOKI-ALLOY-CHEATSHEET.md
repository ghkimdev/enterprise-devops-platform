# Loki & Grafana Alloy (텔레메트리 수집) Cheat Sheet

## 1️⃣ Loki (로그 집계)

### 개념

```
Loki = Prometheus-like 로그 시스템

Prometheus: 메트릭 (시계열 데이터)
Loki: 로그 (전체 텍스트)
Tempo: 트레이싱 (요청 흐름)

특징:
├─ 레이블 기반 인덱싱 (풀스캔 X)
├─ 저비용 저장소
├─ Grafana와 통합
└─ PromQL 유사 문법
```

### 빠른 시작

```yaml
# docker-compose.yml
services:
  loki:
    image: grafana/loki:latest
    container_name: monitoring-loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - ./config/loki.yml:/etc/loki/local-config.yml
      - loki_data:/loki
    command:
      - '-config.file=/etc/loki/local-config.yml'
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:latest
    container_name: monitoring-promtail
    restart: unless-stopped
    volumes:
      - ./config/promtail.yml:/etc/promtail/config.yml
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - '-config.file=/etc/promtail/config.yml'
    depends_on:
      - loki
    networks:
      - monitoring

volumes:
  loki_data:

networks:
  monitoring:
    driver: bridge
```

### Loki 설정 (config/loki.yml)

```yaml
auth_enabled: false

ingester:
  chunk_idle_period: 5m
  chunk_retain_period: 1m
  max_chunk_age: 1h
  chunk_encoding: snappy

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

server:
  http_listen_port: 3100
  log_level: info

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
  filesystem:
    directory: /loki/chunks
```

### Promtail 설정 (config/promtail.yml)

```yaml
server:
  http_listen_port: 9080
  log_level: info

clients:
  - url: http://loki:3100/loki/api/v1/push

positions:
  filename: /tmp/positions.yaml

scrape_configs:
  # 시스템 로그
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog

  # Docker 로그
  - job_name: docker
    docker:
      host: unix:///var/run/docker.sock
      labels:
        container_name: ''
        image_name: ''
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'
      - source_labels: ['__meta_docker_container_label_app']
        target_label: 'app'

  # 애플리케이션 로그
  - job_name: app
    static_configs:
      - targets:
          - localhost
        labels:
          job: app
          __path__: /opt/app/logs/*.log
    pipeline_stages:
      - json:
          expressions:
            timestamp: time
            level: level
            message: message
      - timestamp:
          source: timestamp
          format: '2006-01-02T15:04:05Z07:00'
```

### LogQL (로그 쿼리 언어)

```logql
# 모든 로그
{job="app"}

# 필터링
{job="app"} |= "error"
{job="app"} != "warning"
{job="app"} |~ "error.*connection"

# 라벨 필터
{job="app", level="error"}
{job="app"} | json | level="ERROR"

# 로그 라인 개수
count_over_time({job="app"}[5m])

# 에러 로그 개수
count_over_time({job="app"} |= "error" [5m])

# 바이트 수
bytes_over_time({job="app"} [5m])

# 비율
rate({job="app"} |= "error" [5m])

# 범위 쿼리
{job="app"} | json | level | label_format level={{ .level | upper }}
```

### Grafana에서 Loki 데이터소스 추가

```
Configuration → Data Sources → Add data source

Loki 선택:
┌──────────────────────────────────────┐
│ Name: Loki                           │
│ URL: http://loki:3100               │
│ Access: Server                       │
│ Auth: disabled                       │
└──────────────────────────────────────┘

Save & Test
```

### 실전 쿼리 예제

```logql
# HTTP 요청 에러 로그
{job="web"} |= "error" | json | status_code="5.."

# 느린 쿼리 (1초 이상)
{job="database"} | json | duration > 1000

# 특정 사용자의 활동
{job="api"} | json | user_id="123"

# 배포 후 에러 증가
{job="app"} |= "error" 
| json 
| timestamp > "2024-05-15T10:00:00Z"

# 에러율 계산
sum(rate({job="api"} |= "error" [5m])) / sum(rate({job="api"} [5m])) * 100
```

---

## 2️⃣ Grafana Alloy (텔레메트리 수집기)

### 개념

```
Alloy = Telemetry Distribution Platform

기능:
├─ Metrics 수집 (Prometheus Scraping)
├─ Logs 수집 (Promtail + Filebeat)
├─ Traces 수집 (OpenTelemetry)
└─ Profiles 수집

이전 도구들 (Promtail, Otel Collector 등)을 통합!
```

### 빠른 시작

```yaml
# docker-compose.yml
services:
  alloy:
    image: grafana/alloy:latest
    container_name: monitoring-alloy
    restart: unless-stopped
    ports:
      - "12345:12345"  # Web UI
      - "4317:4317"    # OTLP gRPC
      - "4318:4318"    # OTLP HTTP
      - "9411:9411"    # Zipkin
    volumes:
      - ./config/alloy.river:/etc/alloy/config.river
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - run
      - /etc/alloy/config.river
      - --server.http.listen-addr=0.0.0.0:12345
    networks:
      - monitoring
```

### Alloy 설정 (config/alloy.river)

```river
// Alloy 설정 언어: River

// 로컬 파일 로그 수집
local.file_match "app_logs" {
  path_targets = [{
    __path__  = "/var/log/app/*.log"
    __labels__ = {
      job = "app"
    }
  }]
}

// 파일 읽기
loki.source.file "app" {
  targets    = local.file_match.app_logs.targets
  forward_to = [loki.process.app_pipeline.receiver]
}

// 로그 처리
loki.process "app_pipeline" {
  stage.json {
    expressions = {
      timestamp = "time"
      level = "level"
      message = "message"
    }
  }
  
  stage.timestamp {
    source = "timestamp"
    format = "2006-01-02T15:04:05Z07:00"
  }
  
  forward_to = [loki.write.local.receiver]
}

// Loki에 쓰기
loki.write "local" {
  loki_push_api {
    api_url = "http://loki:3100"
  }
}

// ============================================
// Prometheus 메트릭 수집
// ============================================

prometheus.scrape "docker" {
  targets = [
    {
      __address__ = "localhost:9100"
      job = "node"
    }
  ]
  
  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.local.receiver]
}

// Prometheus에 쓰기
prometheus.remote_write "local" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

// ============================================
// OpenTelemetry 트레이싱 수집
// ============================================

otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  output {
    traces  = [otelcol.processor.batch.default.input]
    metrics = [otelcol.processor.batch.default.input]
    logs    = [otelcol.processor.batch.default.input]
  }
}

// 배치 처리
otelcol.processor.batch "default" {
  send_batch_size = 1000
  timeout         = "10s"
  
  output {
    traces  = [otelcol.exporter.prometheus.default.input]
    metrics = [otelcol.exporter.prometheus.default.input]
    logs    = [otelcol.exporter.loki.default.input]
  }
}

// Prometheus로 내보내기
otelcol.exporter.prometheus "default" {
  forward_to = [prometheus.remote_write.local.receiver]
}

// Loki로 내보내기
otelcol.exporter.loki "default" {
  loki {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

### 간단한 설정 (빠른 시작)

```river
// 최소 설정

// 메트릭 수집
prometheus.scrape "prometheus" {
  targets = [
    {
      __address__ = "localhost:9090"
      job = "prometheus"
    }
  ]
  
  forward_to = [prometheus.remote_write.prometheus.receiver]
}

// Prometheus에 쓰기
prometheus.remote_write "prometheus" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

// 로그 수집
local.file_match "logs" {
  path_targets = [{
    __path__  = "/var/log/app.log"
    __labels__ = {
      job = "app"
    }
  }]
}

loki.source.file "logs" {
  targets    = local.file_match.logs.targets
  forward_to = [loki.write.loki.receiver]
}

// Loki에 쓰기
loki.write "loki" {
  loki_push_api {
    api_url = "http://loki:3100"
  }
}
```

### Web UI

```
접속: http://localhost:12345

화면:
├─ Graph: 수집 파이프라인 시각화
├─ Configuration: 현재 설정 확인
└─ Logs: 수집 로그 확인
```

---

## 🎯 통합 설정

### 완전한 Observability Stack

```yaml
# docker-compose.yml (전체)

version: '3.8'

services:
  # 메트릭
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - monitoring

  # 메트릭 수집
  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    networks:
      - monitoring

  # 로그
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./config/loki.yml:/etc/loki/local-config.yml
    networks:
      - monitoring

  # 텔레메트리 수집기 (메트릭 + 로그 + 트레이스)
  alloy:
    image: grafana/alloy:latest
    ports:
      - "12345:12345"
      - "4317:4317"
      - "4318:4318"
    volumes:
      - ./config/alloy.river:/etc/alloy/config.river
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki

  # 시각화
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: "admin"
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki

networks:
  monitoring:
    driver: bridge
```

### 데이터 흐름

```
┌─────────────────────────────────────────┐
│  데이터 소스                             │
├─────────────────────────────────────────┤
│ • 애플리케이션 (OpenTelemetry)          │
│ • 호스트 (Node Exporter)                │
│ • 컨테이너 (cAdvisor)                   │
│ • 로그 파일                             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Grafana Alloy (수집)                   │
├─────────────────────────────────────────┤
│ • Scrape: Prometheus 메트릭             │
│ • File: 파일 기반 로그                  │
│ • OTLP: OpenTelemetry 데이터            │
└──────────┬──────────────────────────────┘
           │
        ┌──┴──────┬─────────┐
        ▼         ▼         ▼
    Prometheus  Loki    (Tempo)
    (메트릭)  (로그)   (트레이싱)
        │         │
        └────┬────┘
             ▼
         Grafana
      (시각화 & 알림)
```

---

## 🚀 빠른 시작

```bash
# 모든 서비스 시작
docker-compose up -d

# 접속
Prometheus: http://localhost:9090
Loki: http://localhost:3100
Grafana: http://localhost:3000 (admin/admin)
Alloy: http://localhost:12345

# 상태 확인
curl http://localhost:12345/stats

# 로그 확인
docker-compose logs -f alloy
docker-compose logs -f loki

# 중지
docker-compose down
```

---

## 💡 팁

### Alloy vs Promtail

```
Promtail (이전):
├─ 로그만 수집
└─ Loki로 전송

Alloy (새 버전):
├─ 메트릭, 로그, 트레이싱 수집
├─ 더 강력한 처리 기능
└─ 여러 백엔드로 전송 가능

→ Alloy로 마이그레이션 권장!
```

### OpenTelemetry 연동

```
애플리케이션에서 Alloy로 텔레메트리 전송:

const exporter = new OTLPTraceExporter({
  url: 'http://localhost:4318/v1/traces'
});

const tracer = trace.getTracer('my-app');
const span = tracer.startSpan('request');
span.end();
```

---

**Loki + Alloy로 완벽한 로깅 및 텔레메트리 시스템을 구축할 수 있습니다!** 📊

Prometheus(메트릭) + Loki(로그) + Tempo(트레이싱) = 완벽한 Observability! 🚀✨
