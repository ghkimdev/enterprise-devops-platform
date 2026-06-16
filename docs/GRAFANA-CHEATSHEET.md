# Grafana 빠른 시작 가이드 & Cheat Sheet

## 🚀 5분 안에 시작하기

### Docker Compose

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

  grafana:
    image: grafana/grafana:latest
    container_name: monitoring-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: "admin"
      GF_INSTALL_PLUGINS: "grafana-clock-panel"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana-provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
```

### 실행 및 접속

```bash
docker-compose up -d grafana

# 접속
http://localhost:3000
# 계정: admin / admin
```

---

## 📝 초기 설정

### 1. 대시보드 로그인

```
화면 → Grafana 로그인
Email: admin
Password: admin (또는 설정한 비밀번호)

첫 로그인 시:
→ 비밀번호 변경 권유 (필수)
→ 새 비밀번호 입력 및 저장
```

### 2. Data Source 추가 (Prometheus)

```
좌측 메뉴 → Configuration → Data Sources → Add data source

설정:
┌─────────────────────────────────────┐
│ Prometheus 선택                     │
├─────────────────────────────────────┤
│ Name: Prometheus                    │
│ URL: http://prometheus:9090         │
│ Access: Server (default)            │
│ Scrape interval: 15s                │
│ Query timeout: 60s                  │
└─────────────────────────────────────┘

Save & Test
→ "Data source is working" 확인
```

---

## 📊 대시보드 생성

### 방법 1: 기본 패널 생성

```
좌측 메뉴 → Create → Dashboard

패널 추가:
1. Panel 클릭
2. 쿼리 입력
3. 시각화 선택
4. 저장
```

### 방법 2: JSON으로 Import

```
좌측 메뉴 → Create → Import

방법 A: JSON 붙여넣기
방법 B: Grafana.com에서 ID 찾기
       (ID 입력 후 자동 로드)
```

---

## 🎨 시각화 유형

### 1. Graph (라인 차트)

```
용도: 시계열 데이터 (메트릭 추이)
설정:
├─ Panel title: "CPU Usage"
├─ Query: rate(node_cpu_seconds_total[5m])
├─ Legend: show=true, values=current
├─ Axes:
│  ├─ Y-axis format: Percent
│  └─ Y-axis max: 100
└─ Thresholds: 80 (경고 색상)
```

### 2. Gauge (게이지)

```
용도: 현재값 표시 (퍼센티지, 온도 등)
설정:
├─ Panel title: "Memory Usage"
├─ Query: node_memory_usage_percent
├─ Format: Percent
├─ Min: 0, Max: 100
└─ Thresholds: 50,80 (노랑, 빨강)
```

### 3. Stat (숫자 표시)

```
용도: 큰 숫자 표시 (요청 수, 에러 등)
설정:
├─ Panel title: "Total Requests"
├─ Query: sum(increase(http_requests_total[1h]))
├─ Value calculation: Calculation → last
└─ Color scheme: 비율에 따라 색상 변경
```

### 4. Table (테이블)

```
용도: 상세한 데이터 표시
설정:
├─ Panel title: "Top 10 Slow Endpoints"
├─ Query: topk(10, ...)
├─ Columns: 자동 또는 수동 선택
└─ Sorting: 클릭으로 정렬
```

### 5. Heatmap (히트맵)

```
용도: 분포 시각화
설정:
├─ Panel title: "Response Time Distribution"
├─ Query: histogram으로 끝나는 메트릭
└─ Bucket size: 자동 또는 수동
```

### 6. Pie Chart (파이 차트)

```
용도: 비율 표시
설정:
├─ Panel title: "Request Status"
├─ Query: sum by (status) (http_requests_total)
└─ Legend: show=true
```

---

## 📈 실전 대시보드 예제

### 완전한 대시보드 JSON

```json
{
  "dashboard": {
    "title": "System Overview",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode='idle'}[5m])) * 100)"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "((node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes) * 100"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100"
          }
        ]
      },
      {
        "title": "Network I/O",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "Receive"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "Transmit"
          }
        ]
      }
    ]
  }
}
```

---

## 🔧 고급 기능

### Variable 사용 (동적 대시보드)

```
대시보드 설정 → Variables → New variable

예: Instance 선택
┌─────────────────────────────────┐
│ Name: instance                  │
│ Type: Query                     │
│ Data source: Prometheus         │
│ Query: label_values(up, instance)
│ Multi-value: on                 │
│ Include all option: on          │
└─────────────────────────────────┘

쿼리에서 사용:
node_cpu_seconds_total{instance="$instance"}
```

### Templating (변수 활용)

```
쿼리에서 변수 사용:
rate(node_cpu_seconds_total{instance=~"$instance"}[5m])

패널 제목에서도 사용:
"CPU Usage for $instance"

드롭다운으로 값 선택:
All, localhost:9100, 192.168.1.1:9100, ...
```

### Alert 설정

```
Panel 편집 → Alert → New alert

조건:
┌─────────────────────────────────┐
│ Evaluate: node_cpu > 80         │
│ For: 5m (5분 동안 지속)         │
│ Send to: email@example.com      │
│ Message: CPU usage is high      │
└─────────────────────────────────┘
```

### Annotation (주석)

```
패널에 특정 이벤트 표시:

Tags: deployment, bug
Title: Deployment v1.0.0
Time: 2024-05-15 10:30:00

그래프에 선이 그어져 변화 시점 표시
```

---

## 📊 자주 쓰는 대시보드 구성

### 호스트 모니터링 대시보드

```
행(Row) 1: 시스템 개요
├─ CPU Usage (Gauge)
├─ Memory Usage (Gauge)
├─ Disk Usage (Gauge)
└─ Load Average (Stat)

행 2: 리소스 추이
├─ CPU Timeline (Graph)
├─ Memory Timeline (Graph)
└─ Network I/O (Graph)

행 3: 상세 정보
├─ Process List (Table)
├─ Network Connections (Stat)
└─ Disk I/O (Graph)
```

### 애플리케이션 모니터링 대시보드

```
행 1: 키 메트릭
├─ RPS (Requests Per Second) - Stat
├─ P95 Latency (ms) - Gauge
├─ Error Rate (%) - Gauge
└─ Uptime - Stat

행 2: 상세 그래프
├─ Response Time (Graph)
├─ Request Count (Graph)
└─ Error Count (Graph)

행 3: 상태
├─ Status Code Distribution (Pie)
├─ Endpoint Performance (Table)
└─ Database Queries (Graph)
```

---

## 🔍 유용한 쿼리 패턴

### Prometheus 데이터를 Grafana에서 사용

```
단순 쿼리:
up

범위와 함께:
rate(http_requests_total[5m])

필터링:
http_requests_total{status="200"}

집계:
sum(rate(http_requests_total[5m]))
avg by (instance) (node_load1)

조건:
histogram_quantile(0.95, ...)

변수 활용:
node_cpu_seconds_total{instance="$instance"}
```

---

## 💾 대시보드 관리

### 저장 및 공유

```
대시보드 우측 상단:

1. Save
   → 변경사항 저장

2. Share
   → Link: 대시보드 링크 공유
   → Embed: 웹사이트에 임베드
   → Export: JSON 다운로드

3. Export
   → 백업용 JSON 저장
```

### 백업 및 복구

```bash
# JSON 내보내기
curl -H "Authorization: Bearer $API_TOKEN" \
  http://localhost:3000/api/dashboards/db/system-overview > dashboard.json

# JSON 가져오기
curl -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  http://localhost:3000/api/dashboards/db
```

---

## 🎯 팁과 트릭

### 1. 반응형 대시보드

```
패널 설정:
- Mobile: 체크
- Grid position: auto 설정
- 패널 크기: flexible하게
```

### 2. 색상 커스터마이징

```
Panel → Visualization → Colors

Options:
- Single color: 고정 색상
- From thresholds: 임계값에 따라
- By value: 값에 따라 자동

Thresholds 설정:
- 0: 파랑
- 50: 노랑
- 80: 빨강
```

### 3. 시계열 평활화

```
데이터가 불안정할 때:

Panel → Transform data → Reduce

Method: Mean
Interval: 5m (5분 평균)
```

---

## ⚠️ 트러블슈팅

### 데이터가 안 보임

```
확인 사항:
1. Data Source 연결 확인
   Configuration → Data Sources → Test

2. 쿼리 문법 확인
   Prometheus UI에서 직접 테스트

3. 메트릭 존재 확인
   Prometheus → Targets 탭에서 up 상태 확인

4. 시간 범위 확인
   대시보드 우상단 시간 범위 조정
```

### 대시보드 로딩 느림

```
해결방법:
1. 쿼리 최적화
   - 더 작은 시간 범위 사용
   - 불필요한 메트릭 제거

2. 샘플링 추가
   rate(metric[1m])  # 범위 줄이기

3. Panel 개수 줄이기
   - 큰 대시보드 분할
   - 탭(Tab) 사용으로 구성

4. Prometheus 최적화
   - 리텐션 조정
   - 스크랩 간격 조정
```

---

## 🎯 빠른 참조

```bash
# Grafana 실행
docker-compose up -d grafana

# 접속
http://localhost:3000
admin / admin

# API로 대시보드 조회
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/search

# 대시보드 내보내기
curl http://localhost:3000/api/dashboards/db/dashboard-name > db.json

# 대시보드 가져오기
curl -X POST -d @db.json \
  http://localhost:3000/api/dashboards/db
```

---

**Grafana로 아름답고 강력한 대시보드를 만들 수 있습니다!** 📊

Prometheus 메트릭을 시각화하여 실시간 모니터링을 시작하세요! 🚀✨
