// vars/metricsHelper.groovy
//
// CI/CD 메트릭을 Pushgateway 로 push 하는 헬퍼. (svnHelper / nexusHelper / dockerHelper 와 동일 컨벤션)
// Jenkins 에이전트가 cicd-net 에서 돌기 때문에 pushgateway:9091 에 직접 닿는다.
//
// Pushgateway 는 "마지막 값"만 저장하므로 이벤트 카운트는 timestamp 게이지 + changes() 로 센다.
// 그룹키(job/app/env/result)는 카디널리티를 고정하기 위한 것이며,
// 매 push 시 해당 그룹 아래 메트릭이 통째로 교체된다(= 누적되지 않음).
//
// 사용:
//   metricsHelper.pushDeploy(app: 'sample-spring', env: 'prod', team: 'payment-team',
//                            release: env.RELEASE_NAME, version: env.APP_VERSION, result: 'success')

// ── 배포 메트릭 (DORA: 배포 빈도 / 변경 실패율 / 배포 소요시간) ──────────────
def pushDeploy(Map m) {
    if (!m.app || !m.env || !m.result) {
        echo "metricsHelper.pushDeploy: app/env/result 누락 — push 스킵"
        return
    }

    def now     = (System.currentTimeMillis() / 1000L) as long
    def dur     = (m.durationSec ?: ((currentBuild.duration ?: 0) / 1000L)) as long
    def team    = (m.team    ?: 'unknown')
    def release = (m.release ?: 'unknown')
    def version = (m.version ?: 'unknown')

    def url = groupUrl(m.gateway, 'cd_deploy', [app: m.app, env: m.env, result: m.result])
    def body = """\
# TYPE cd_deploy_timestamp_seconds gauge
cd_deploy_timestamp_seconds ${now}
# TYPE cd_deploy_duration_seconds gauge
cd_deploy_duration_seconds ${dur}
# TYPE cd_deploy_info gauge
cd_deploy_info{team="${team}",release="${release}",version="${version}"} 1
"""
    emit(url, body)
    echo "metricsHelper → cd_deploy{app=${m.app},env=${m.env},result=${m.result}} dur=${dur}s"
}

// ── 내부 공통 ────────────────────────────────────────────────────────────────
// 그룹키 URL 생성: http://pushgateway:9091/metrics/job/<job>/<k>/<v>/...
def groupUrl(String gateway, String job, Map labels) {
    def base = (gateway ?: 'http://pushgateway:9091') + "/metrics/job/${job}"
    def path = labels.collect { k, v -> "${k}/${v}" }.join('/')
    return path ? "${base}/${path}" : base
}

// Prometheus 텍스트 포맷 body 를 push. 'PROM' 을 따옴표로 감싸 셸의 추가 확장을 막는다.
def emit(String url, String body) {
    sh """
        cat <<'PROM' | curl -fsS --max-time 5 --data-binary @- "${url}"
${body.trim()}
PROM
    """.stripIndent()
}
