# Prometheus 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose로 즉시 실행

```yaml
# docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: monitoring-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    networks:
      - monitoring

volumes:
  prometheus_data:

networks:
  monitoring:
    driver: bridge
```

### 설정 파일 (prometheus.yml)

```yaml
# config/prometheus.yml

global:
  scrape_interval: 15s           # 메트릭 수집 간격
  evaluation_interval: 15s       # 규칙 평가 간격
  external_labels:
    monitor: 'enterprise-monitor'

# Alertmanager 설정 (나중에 추가)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: ['localhost:9093']

# 규칙 파일 (나중에 추가)
# rule_files:
#   - "alert_rules.yml"

scrape_configs:
  # Prometheus 자체 모니터링
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  # Node Exporter (호스트 메트릭)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
  
  # Docker (cAdvisor)
  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']
  
  # Pushgateway
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
```

### 실행 및 접속

```bash
# 실행
docker-compose up -d prometheus

# 접속
http://localhost:9090

# 상태 확인
curl http://localhost:9090/-/ready
curl http://localhost:9090/api/v1/targets
```

---

## 📊 기본 개념

```
┌────────────────────────────────────────┐
│   Prometheus 아키텍처                  │
├────────────────────────────────────────┤
│                                        │
│  Exporters (메트릭 생산)               │
│  ├─ Node Exporter (호스트)            │
│  ├─ cAdvisor (컨테이너)               │
│  ├─ MySQL Exporter (DB)               │
│  └─ Custom Exporter                   │
│         │                              │
│         ├─→ Pull 방식 (기본)           │
│         │   (Prometheus가 주기적으로) │
│         │                              │
│         └─→ Push 방식 (Pushgateway)   │
│             (앱이 메트릭 전송)        │
│         │                              │
│         ▼                              │
│  ┌────────────────────┐               │
│  │   Prometheus       │               │
│  ├────────────────────┤               │
│  │ • 메트릭 수집      │               │
│  │ • 시계열 DB 저장   │               │
│  │ • 쿼리/계산        │               │
│  │ • 알림 규칙 평가   │               │
│  └────────────────────┘               │
│         │                              │
│         ▼                              │
│  Visualization                        │
│  ├─ Grafana (대시보드)                │
│  ├─ Prometheus UI                     │
│  └─ 기타 도구                         │
│                                        │
└────────────────────────────────────────┘
```

---

## 📈 주요 메트릭 타입

### 1. Counter (카운터)
```
특징: 계속 증가하는 값 (리셋 안함)
예: 요청 수, 에러 수, 바이트 전송량

쿼리:
rate(http_requests_total[5m])  # 5분 동안의 요청 속도
increase(http_requests_total[1h])  # 1시간 동안 증가량
```

### 2. Gauge (게이지)
```
특징: 증가/감소 가능한 값
예: CPU 사용률, 메모리 사용량, 동시 연결 수

쿼리:
node_memory_MemFree_bytes
container_memory_usage_bytes
```

### 3. Histogram (히스토그램)
```
특징: 값의 분포를 표현
예: 요청 응답 시간, 파일 크기

쿼리:
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # 95 백분위수
```

### 4. Summary (요약)
```
특징: 미리 계산된 분위수
예: 응답 시간의 백분위수

쿼리:
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

---

## 🔍 자주 사용하는 PromQL 쿼리

### 시스템 메트릭

```promql
# CPU 사용률 (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 메모리 사용률 (%)
((node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes) * 100

# 디스크 사용률 (%)
(1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100

# 네트워크 수신 속도 (MB/s)
rate(node_network_receive_bytes_total[5m]) / 1024 / 1024

# 네트워크 전송 속도 (MB/s)
rate(node_network_transmit_bytes_total[5m]) / 1024 / 1024
```

### 컨테이너 메트릭 (cAdvisor)

```promql
# 컨테이너 CPU 사용률 (%)
rate(container_cpu_usage_seconds_total{container_name!=""}[5m]) * 100

# 컨테이너 메모리 사용률 (%)
(container_memory_usage_bytes{container_name!=""} / container_spec_memory_limit_bytes{container_name!=""}) * 100

# 컨테이너 네트워크 송수신
rate(container_network_receive_bytes_total[5m]) / 1024 / 1024
```

### HTTP 요청 메트릭

```promql
# 초당 요청 수 (RPS)
rate(http_requests_total[5m])

# 요청 성공률 (%)
(rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])) * 100

# 95 백분위수 응답 시간
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 에러율 (%)
(rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])) * 100
```

### 범위와 필터

```promql
# 마지막 5분 데이터
node_memory_MemFree_bytes[5m]

# 호스트 필터
rate(node_cpu_seconds_total{instance="192.168.1.100:9100"}[5m])

# 여러 값 필터 (정규식)
http_requests_total{status=~"[45].."}

# 레이블 제외
node_cpu_seconds_total{mode!="idle"}

# 존재 여부
{job=~".*"}  # job 레이블이 있는 모든 메트릭
```

### 연산

```promql
# 사칙연산
rate(http_requests_total[5m]) * 2
node_memory_MemFree_bytes / 1024 / 1024  # MB로 변환

# 비교
http_requests_total > 100
node_load1 > on(instance) node_load5

# 집계
sum(rate(http_requests_total[5m]))      # 합계
avg(node_load1)                         # 평균
max(container_memory_usage_bytes)       # 최대값
min(node_filesystem_avail_bytes)        # 최소값

# 그룹화
sum by (instance) (rate(http_requests_total[5m]))
avg by (job, instance) (node_load1)
```

---

## 🎯 자주 쓰는 쿼리 템플릿

### 서버 성능 모니터링

```promql
# CPU 사용률 높은 호스트 (상위 5개)
topk(5, 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# 메모리 부족 호스트
((node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes) * 100 > 80

# 디스크 용량 부족 (80% 이상)
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 80

# 로드 어베리지
node_load1 / on(instance) count(node_cpu_seconds_total{mode="system"}) by (instance)
```

### 애플리케이션 성능 모니터링

```promql
# 초당 요청 수
rate(http_requests_total[1m])

# 요청 실패율
(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100

# 응답 시간 P95
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# 활성 연결 수
go_goroutines
```

---

## 📝 설정 고급 기능

### 1. Job 설정 (다양한 타겟)

```yaml
scrape_configs:
  # 정적 타겟
  - job_name: 'static'
    static_configs:
      - targets: 
          - 'localhost:9090'
          - 'localhost:9100'
        labels:
          group: 'production'
  
  # 파일 기반 서비스 디스커버리
  - job_name: 'file-sd'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/*.yml'
        refresh_interval: 30s
  
  # DNS 기반 서비스 디스커버리
  - job_name: 'dns-sd'
    dns_sd_configs:
      - names:
          - 'example.com'
        port: 9100
  
  # Docker 기반 서비스 디스커버리
  - job_name: 'docker-sd'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container_name
```

### 2. 메트릭 필터링

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    
    # 특정 메트릭만 수집
    metric_relabel_configs:
      # prometheus_sd_* 메트릭 제외
      - source_labels: [__name__]
        regex: 'prometheus_sd_.*'
        action: drop
      
      # http로 시작하는 메트릭만 포함
      - source_labels: [__name__]
        regex: 'http.*'
        action: keep
```

### 3. 레이블 추가

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          environment: 'production'
          team: 'platform'
          region: 'us-east-1'
```

---

## 💾 데이터 관리

### 리텐션 설정

```bash
# 15일 동안만 데이터 보관 (기본값은 15일)
docker run ... prom/prometheus:latest \
  --storage.tsdb.retention.time=15d

# 50GB까지만 저장
docker run ... prom/prometheus:latest \
  --storage.tsdb.retention.size=50GB
```

### 스냅샷 백업

```bash
# HTTP API로 스냅샷 생성
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# 결과 예시:
# {
#   "status": "success",
#   "data": {
#     "name": "20240515T140530Z-0123456789abcdef"
#   }
# }

# 스냅샷 다운로드 및 복구
docker cp prometheus:/prometheus/snapshots/20240515T140530Z-0123456789abcdef ./backup/
```

---

## 🔍 디버깅 및 모니터링

### 상태 확인

```bash
# Prometheus 상태
curl http://localhost:9090/-/ready
curl http://localhost:9090/-/healthy

# 메트릭 확인
curl http://localhost:9090/metrics

# 타겟 상태 확인
curl http://localhost:9090/api/v1/targets | jq

# 수집되는 메트릭 목록
curl http://localhost:9090/api/v1/label/__name__/values | jq
```

### 로그 확인

```bash
# 컨테이너 로그
docker logs -f monitoring-prometheus

# 특정 오류 확인
docker logs monitoring-prometheus | grep -i error
```

---

## 📊 Web UI 사용법

### 접속
```
http://localhost:9090
```

### 화면 구성

```
┌─────────────────────────────────────┐
│ Prometheus 1.0.0                    │
├─────────────────────────────────────┤
│ Graph | Alerts | Status | Help      │
├─────────────────────────────────────┤
│                                     │
│ 쿼리 입력:                          │
│ ┌──────────────────────────────┐   │
│ │ up{job="prometheus"}         │   │
│ └──────────────────────────────┘   │
│                                     │
│ [Graph] [Console] [Autocompl]      │
│                                     │
│ (그래프 표시 영역)                  │
│                                     │
└─────────────────────────────────────┘
```

### 주요 기능

```
1. 쿼리 실행
   - PromQL 쿼리 입력
   - Graph 탭에서 그래프 시각화
   - Console 탭에서 표 형식 확인

2. 자동완성
   - Ctrl + Space (또는 메트릭 시작 입력)
   - 메트릭명, 레이블명 자동완성

3. 범위 선택
   - 5m, 1h, 6h, 1d, 1w 등 버튼
   - 커스텀 범위 입력 가능
```

---

## ⚠️ 트러블슈팅

### 메트릭이 안 나옴

```bash
# 1. 타겟 확인
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets'

# 2. 타겟이 DOWN 상태?
# → 해당 서비스 실행 확인
docker ps | grep node-exporter

# 3. 포트 확인
netstat -tlnp | grep 9100

# 4. 네트워크 연결 확인
curl http://node-exporter:9100/metrics
```

### 메모리 부족

```bash
# 메모리 사용량 확인
docker stats monitoring-prometheus

# 리텐션 줄이기
docker-compose.yml 수정:
command:
  - '--storage.tsdb.retention.time=7d'
  - '--storage.tsdb.retention.size=10GB'

# 재시작
docker-compose restart prometheus
```

### 쿼리 느림

```bash
# 범위 줄이기
rate(http_requests_total[1m])  # 1분 범위로 제한

# 샘플링 추가
rate(http_requests_total[5m] offset 1h)

# 인덱싱 확인
# Prometheus Status → TSDB에서 확인
```

---

## 🎯 빠른 참조

```bash
# 실행
docker-compose up -d prometheus

# 접속
http://localhost:9090

# 쿼리 실행
up                              # 타겟 상태
rate(http_requests_total[5m])   # 요청 속도
node_memory_MemFree_bytes       # 여유 메모리

# 상태 확인
curl http://localhost:9090/-/healthy
curl http://localhost:9090/api/v1/targets

# 로그 확인
docker logs -f monitoring-prometheus

# 중지
docker-compose down
```

---

**Prometheus를 5분 안에 시작할 수 있습니다!** 🚀

다음 단계: Grafana와 연동하여 아름다운 대시보드를 만들어보세요! 📊✨
