// vars/stackPython.groovy
//
// FastAPI 등 Python 앱의 스택별 빌드 동작.
// venv 는 packaging 에 포함하지 않고 배포 VM 에서 새로 생성한다.

def validateSource() {
    sh '''
        test -f requirements.txt
        test -d app
    '''
}

def installAndTest(Map cfg) {
    sh """
        python3 -m venv .venv
        . .venv/bin/activate
        pip install --upgrade pip
        pip install \
            --index-url ${cfg.pipIndexUrl} \
            --trusted-host ${cfg.pipTrustedHost} \
            -r requirements.txt

        PYTHONPATH=. pytest --junitxml=test-results.xml
    """
    junit(allowEmptyResults: true, testResults: 'test-results.xml')
}

/** 소스 tar.gz 생성 후 Nexus raw repo 업로드. ARTIFACT_URL 반환. */
def packageAndUpload(Map cfg) {
    sh """
        cat > build-info.json <<EOF
{
  "app": "${cfg.appName}",
  "release_name": "${cfg.releaseName}",
  "timestamp": "${cfg.timestamp}",
  "svn_revision": "${cfg.svnRevision}",
  "jenkins_build_url": "${env.BUILD_URL}"
}
EOF

        tar czf "${cfg.tarName}" \
            --exclude='.venv' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='tests' \
            --exclude='.svn' \
            app/ requirements.txt build-info.json
    """
    return nexusHelper.uploadRaw(cfg, cfg.tarName)
}
