// Jenkins Job DSL seed.
//
// 변경사항:
//   - 각 앱마다 checkitem / build / deploy 3개 job만 생성

println "Starting Seed Job..."

// ───── Folder ─────
folder('applications') {
    displayName('Applications')
    description('Application Pipelines')
}


// ───── Pipeline job 생성 헬퍼 ─────
def createPipelineJob(String name, String repo, String script) {
    pipelineJob(name) {
        definition {
            cpsScm {
                lightweight(false)
                scm {
                    svn {
                        location(repo) {
                            credentials('svn-creds')
                        }
                    }
                }
                scriptPath(script)
            }
        }
        logRotator {
            numToKeep(30)
        }
        properties {
            disableConcurrentBuilds()
        }
    }
}


// ───── 앱별 job 생성 ─────
// 새 앱 추가 시 이 리스트에만 추가하면 됨.
def apps = [
    'sample-spring',
    'sample-react',
    'sample-fastapi'
]

apps.each { app ->
    def repo = "http://svn/svn/${app}/trunk"

    createPipelineJob(
        "applications/${app}-checkitem",
        repo,
        "Jenkinsfile.checkitem-${app.replace('sample-', '')}"
    )

    createPipelineJob(
        "applications/${app}-build",
        repo,
        "Jenkinsfile.build-${app.replace('sample-', '')}"
    )

    createPipelineJob(
        "applications/${app}-deploy",
        repo,
        "Jenkinsfile.deploy-${app.replace('sample-', '')}"
    )
}

println "Seed Job Complete: ${apps.size()} apps × 3 jobs = ${apps.size() * 3} jobs"
