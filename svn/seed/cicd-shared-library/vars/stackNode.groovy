// vars/stackNode.groovy
//
// React 등 Node 앱의 스택별 빌드 동작.
// dist/ 를 tar.gz 로 묶어 Nexus raw repo 에 업로드한다.

def validateSource() {
    sh '''
        test -f package.json
        test -f package-lock.json || {
            echo "package-lock.json required for immutable build"
            exit 1
        }
    '''
}

def installAndTest(Map cfg) {
    // npm 인증용 .npmrc 생성 후 npm ci
    withCredentials([usernamePassword(
            credentialsId: cfg.nexusCreds,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        withEnv(["NPM_REGISTRY=${cfg.npmRegistry}"]) {
            sh '''
                NPM_TOKEN=$(printf '%s' "$NEXUS_USER:$NEXUS_PASS" | openssl base64 -A)
                REGISTRY_HOST=$(echo "$NPM_REGISTRY" | sed -E 's#https?://([^/]+)/.*#\\1#')
                cat > ~/.npmrc <<NPMRC
registry=${NPM_REGISTRY}
//${REGISTRY_HOST}/:_auth=${NPM_TOKEN}
always-auth=true
strict-ssl=false
NPMRC
                npm ci
            '''
        }
    }

    sh '''
        npm run lint
        npm run test -- --run
    '''

    sh """
        VITE_APP_VERSION=${cfg.releaseName} npm run build
        test -d dist
        test -f dist/index.html
    """
}

/** dist/ 를 tar.gz 로 묶어 Nexus raw repo 업로드. ARTIFACT_URL 반환. */
def packageAndUpload(Map cfg) {
    sh """
        cat > dist/build-info.json <<EOF
{
  "app": "${cfg.appName}",
  "release_name": "${cfg.releaseName}",
  "timestamp": "${cfg.timestamp}",
  "svn_revision": "${cfg.svnRevision}",
  "jenkins_build_url": "${env.BUILD_URL}"
}
EOF

        tar czf "${cfg.tarName}" -C dist .
    """
    return nexusHelper.uploadRaw(cfg, cfg.tarName)
}
