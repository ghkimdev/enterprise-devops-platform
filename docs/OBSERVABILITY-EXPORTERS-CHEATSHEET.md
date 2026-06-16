# Node Exporter, cAdvisor, Pushgateway, Blackbox Exporter Cheat Sheet

## 1️⃣ Node Exporter (호스트 메트릭)

### 빠른 시작

```yaml
# docker-compose.yml
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: monitoring-node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring
```

### Prometheus에 추가

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### 주요 메트릭

```
CPU 메트릭:
├─ node_cpu_seconds_total: CPU 시간
├─ node_load1, node_load5, node_load15: 로드 평균
└─ node_context_switches_total: 컨텍스트 스위치

메모리 메트릭:
├─ node_memory_MemTotal_bytes: 전체 메모리
├─ node_memory_MemFree_bytes: 여유 메모리
├─ node_memory_MemAvailable_bytes: 사용 가능 메모리
└─ node_memory_SwapTotal_bytes: 스왑 용량

디스크 메트릭:
├─ node_filesystem_size_bytes: 파티션 크기
├─ node_filesystem_avail_bytes: 여유 공간
├─ node_disk_reads_completed_total: 읽기 완료
└─ node_disk_writes_completed_total: 쓰기 완료

네트워크 메트릭:
├─ node_network_receive_bytes_total: 수신 바이트
├─ node_network_transmit_bytes_total: 전송 바이트
└─ node_network_tcp_connection_states: TCP 연결 상태

프로세스 메트릭:
├─ node_processes_running: 실행 중인 프로세스
├─ node_processes_blocked: 블로킹된 프로세스
└─ node_context_switches_total: 컨텍스트 스위치
```

### Collector 설정

```bash
# 특정 Collector만 활성화
docker run ... prom/node-exporter:latest \
  --collector.cpu \
  --collector.meminfo \
  --collector.diskstats \
  --no-collector.wifi

# Collector 확인
curl http://localhost:9100/metrics | head -20
```

---

## 2️⃣ cAdvisor (컨테이너 메트릭)

### 빠른 시작

```yaml
# docker-compose.yml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: monitoring-cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    networks:
      - monitoring
    command:
      - '--port=8080'
      - '--housekeeping_interval=10s'
      - '--global_housekeeping_interval=30s'
```

### Prometheus에 추가

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    metrics_path: '/metrics'
```

### 주요 메트릭

```
CPU:
├─ container_cpu_usage_seconds_total: CPU 사용 시간
├─ container_cpu_cfs_throttled_duration_seconds_total: CPU throttling
└─ container_cpu_system_seconds_total: 시스템 CPU

메모리:
├─ container_memory_usage_bytes: 메모리 사용량
├─ container_memory_max_usage_bytes: 최대 메모리 사용
└─ container_memory_working_set_bytes: 워킹셋

네트워크:
├─ container_network_receive_bytes_total: 수신 바이트
├─ container_network_transmit_bytes_total: 전송 바이트
└─ container_network_tcp_usage_total: TCP 연결 수

스토리지:
├─ container_fs_usage_bytes: 파일시스템 사용량
├─ container_fs_limit_bytes: 파일시스템 제한
└─ container_fs_io_current: I/O 현재값
```

### PromQL 예제

```promql
# 컨테이너 CPU 사용률 (%)
rate(container_cpu_usage_seconds_total{container_name!=""}[5m]) * 100

# 컨테이너 메모리 사용률 (%)
(container_memory_usage_bytes{container_name!=""} / 
 container_spec_memory_limit_bytes{container_name!=""}) * 100

# 컨테이너별 네트워크 받는 속도
rate(container_network_receive_bytes_total[5m]) / 1024 / 1024
```

---

## 3️⃣ Pushgateway (메트릭 푸시)

### 빠른 시작

```yaml
# docker-compose.yml
services:
  pushgateway:
    image: prom/pushgateway:latest
    container_name: monitoring-pushgateway
    restart: unless-stopped
    ports:
      - "9091:9091"
    networks:
      - monitoring
    command:
      - '--persistence.file=/pushgateway/metrics'
      - '--persistence.interval=5m'
```

### Prometheus에 추가

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true  # 푸시된 라벨 유지
    static_configs:
      - targets: ['pushgateway:9091']
```

### 메트릭 푸시하기

```bash
# 간단한 메트릭 푸시
cat <<EOF | curl --data-binary @- http://localhost:9091/metrics/job/batch-job
# TYPE my_batch_duration_seconds gauge
my_batch_duration_seconds 10.5
# TYPE my_batch_items_total counter
my_batch_items_total 1000
EOF

# 라벨과 함께 푸시
curl -X POST --data-binary @metrics.txt \
  http://localhost:9091/metrics/job/backup_job/instance/server1

# 메트릭 삭제
curl -X DELETE http://localhost:9091/metrics/job/backup_job

# 모든 메트릭 삭제
curl -X DELETE http://localhost:9091/metrics/job/backup_job/instance/server1
```

### Python 예제

```python
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

registry = CollectorRegistry()

# 메트릭 정의
duration = Gauge('batch_duration_seconds', 'Job duration', registry=registry)
items = Gauge('batch_items_total', 'Items processed', registry=registry)

# 값 설정
duration.set(10.5)
items.set(1000)

# Pushgateway에 푸시
push_to_gateway('localhost:9091', 
                job='batch-job', 
                registry=registry)
```

### 사용 사례

```
배치 작업:
├─ Cron job
├─ 일회성 작업
└─ 단기 프로세스

→ Pushgateway로 메트릭 전송
→ Prometheus가 수집

Pull 모델을 쓸 수 없는 경우:
├─ 임시 컨테이너
├─ Serverless 함수
└─ 짧은 Job
```

---

## 4️⃣ Blackbox Exporter (외부 모니터링)

### 빠른 시작

```yaml
# docker-compose.yml
services:
  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: monitoring-blackbox
    restart: unless-stopped
    ports:
      - "9115:9115"
    volumes:
      - ./config/blackbox.yml:/config/blackbox.yml
    command:
      - '--config.file=/config/blackbox.yml'
    networks:
      - monitoring
```

### 설정 (config/blackbox.yml)

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      preferred_ip_protocol: "ip4"
      no_follow_redirects: false
      
  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      headers:
        Content-Type: "application/json"
      body: '{"key": "value"}'
  
  tcp_connect:
    prober: tcp
    timeout: 5s
  
  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
  
  dns:
    prober: dns
    timeout: 5s
    dns:
      nameservers:
        - "8.8.8.8"
      query_name: "example.com"
      valid_rcodes:
        - NOERROR
        - NXDOMAIN
```

### Prometheus에 추가

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'blackbox-http'
    static_configs:
      - targets:
          - https://example.com
          - https://google.com
          - https://github.com
    metrics_path: /probe
    params:
      module: [http_2xx]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  - job_name: 'blackbox-tcp'
    static_configs:
      - targets:
          - localhost:8080
          - localhost:3306
    metrics_path: /probe
    params:
      module: [tcp_connect]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  - job_name: 'blackbox-ping'
    static_configs:
      - targets:
          - 8.8.8.8
          - 1.1.1.1
    metrics_path: /probe
    params:
      module: [icmp]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### 주요 메트릭

```
HTTP:
├─ probe_success: 프로브 성공 여부 (1=성공, 0=실패)
├─ probe_duration_seconds: 응답 시간
├─ probe_http_status_code: HTTP 상태 코드
└─ probe_http_ssl: SSL 인증서 유효성

TCP:
├─ probe_success: TCP 연결 성공 여부
└─ probe_duration_seconds: 연결 시간

ICMP:
├─ probe_success: Ping 성공 여부
└─ probe_duration_seconds: Ping 응답 시간

DNS:
├─ probe_success: DNS 쿼리 성공 여부
└─ probe_dns_lookup_time_seconds: 조회 시간
```

### PromQL 예제

```promql
# 엔드포인트 가용성
probe_success

# 응답 시간 (ms)
probe_duration_seconds * 1000

# SSL 인증서 만료일까지 남은 일수
(probe_ssl_earliest_cert_expiry - time()) / 86400

# HTTP 상태 코드별 실패율
rate(probe_http_status_code{code!="200"}[5m])

# 엔드포인트별 응답 시간
avg by (instance) (probe_duration_seconds)
```

---

## 🎯 통합 Docker Compose

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: monitoring-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: monitoring-node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: monitoring-cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

  pushgateway:
    image: prom/pushgateway:latest
    container_name: monitoring-pushgateway
    ports:
      - "9091:9091"
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: monitoring-blackbox
    ports:
      - "9115:9115"
    volumes:
      - ./config/blackbox.yml:/config/blackbox.yml
    command:
      - '--config.file=/config/blackbox.yml'
    networks:
      - monitoring

volumes:
  prometheus_data:

networks:
  monitoring:
    driver: bridge
```

---

## 🚀 빠른 시작 명령어

```bash
# 모든 서비스 실행
docker-compose up -d

# 상태 확인
docker-compose ps

# 메트릭 확인
curl http://localhost:9100/metrics          # Node Exporter
curl http://localhost:8080/metrics          # cAdvisor
curl http://localhost:9091/metrics          # Pushgateway
curl http://localhost:9115/probe?target=example.com&module=http_2xx  # Blackbox

# 로그 확인
docker-compose logs -f prometheus
docker-compose logs -f node-exporter

# 중지
docker-compose down
```

---

**이 4가지 도구로 호스트, 컨테이너, 외부 서비스까지 완벽하게 모니터링할 수 있습니다!** 🚀

Prometheus + Grafana와 함께 사용하면 강력한 모니터링 시스템이 완성됩니다! 📊✨
