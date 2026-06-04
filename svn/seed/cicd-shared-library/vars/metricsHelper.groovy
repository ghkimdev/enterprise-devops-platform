// vars/metricsHelper.groovy
//
// CI/CD 이력을 두 갈래로 전송한다.
//   1) Pushgateway : app/team[/env] 별 "최신 상태" 게이지(결과·소요시간·시각). 매 실행 덮어쓰기.
//   2) Loki        : 빌드/배포 "이벤트" 로그(build-info.json/deploy-info.json 보강본). 이력/감사용.
//
// 에이전트가 cicd-net에 있어 pushgateway:9091 / loki:3100 로 바로 접근 가능.
// 어떤 전송 실패도 파이프라인을 깨면 안 되므로 전부 best-effort(try/catch).
//
// 사용(파이프라인 post 블록):
//   metricsHelper.record([
//     kind: 'build', app: config.appName, team: config.team ?: 'na',
//     env: config.autoDeployEnv, result: currentBuild.currentResult,
//     durationSec: <초>, infoFile: 'build-info.json'
//   ])

import groovy.transform.Field

@Field String PUSHGATEWAY = 'http://pushgateway:9091'
@Field String LOKI        = 'http://loki:3100'

/** 최신 상태 게이지 → Pushgateway. 그룹 키(app/team[/env])는 고정이라 매 실행 덮어쓴다. */
def pushState(Map m) {
    def kind = m.kind
    def ok   = (m.result == 'SUCCESS') ? 1 : 0
    def dur  = (m.durationSec ?: 0) as long
    def now  = sh(returnStdout: true, script: 'date +%s').trim()

    def group = "job/jenkins_${kind}/app/${m.app}/team/${m.team}"
    if (m.env) group += "/env/${m.env}"

    def body = """# TYPE ci_${kind}_result gauge
ci_${kind}_result ${ok}
# TYPE ci_${kind}_duration_seconds gauge
ci_${kind}_duration_seconds ${dur}
# TYPE ci_${kind}_timestamp_seconds gauge
ci_${kind}_timestamp_seconds ${now}
"""
    writeFile file: '.ci-metrics.prom', text: body
    try {
        sh(label: "push ${kind} state -> pushgateway",
           script: "curl -sf --max-time 10 --data-binary @.ci-metrics.prom '${PUSHGATEWAY}/metrics/${group}'")
    } catch (e) {
        echo "metricsHelper: pushgateway 전송 실패(무시) - ${e.message}"
    }
}

/** 이벤트 로그 → Loki. 라벨은 저카디널리티만, 상세 필드는 라인(JSON) 안에 둔다. */
def pushEvent(Map m) {
    def data = [:]
    if (m.infoFile && fileExists(m.infoFile)) {
        data = readJSON file: m.infoFile
    }
    data.kind             = m.kind
    data.result           = m.result
    data.duration_seconds = (m.durationSec ?: 0) as long
    data.app              = data.app ?: m.app
    data.team             = m.team
    if (m.env) data.env   = m.env
    data.event_time       = sh(returnStdout: true, script: 'date -u +%Y-%m-%dT%H:%M:%SZ').trim()

    writeJSON file: '.ci-line.json', json: data
    def line = readFile('.ci-line.json').trim()
    def ts   = sh(returnStdout: true, script: 'date +%s%N').trim()

    def stream = [
        job   : 'jenkins',
        app   : data.app.toString(),
        team  : m.team.toString(),
        kind  : m.kind.toString(),
        result: m.result.toString()
    ]
    if (m.env) stream.env = m.env.toString()

    writeJSON file: '.ci-event.json',
              json: [streams: [[stream: stream, values: [[ts, line]]]]]
    try {
        sh(label: "push ${m.kind} event -> loki",
           script: "curl -sf --max-time 10 -H 'Content-Type: application/json' " +
                   "-X POST '${LOKI}/loki/api/v1/push' --data-binary @.ci-event.json")
    } catch (e) {
        echo "metricsHelper: loki 전송 실패(무시) - ${e.message}"
    }
}

/** state + event 한 번에. post 블록에서 이것만 호출하면 된다. */
def record(Map m) {
    m.result      = m.result ?: 'UNKNOWN'
    m.team        = m.team ?: 'na'
    m.durationSec = m.durationSec ?: 0
    pushState(m)
    pushEvent(m)
}
