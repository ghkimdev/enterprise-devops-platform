// vars/dockerHelper.groovy
//
// Nexus(도커 레지스트리) 로그인 후 이미지를 빌드하고 release / latest 태그로 push.

/**
 * args:
 *   registry     : 도커 레지스트리 호스트
 *   image        : 전체 이미지 경로 (registry 포함)
 *   nexusCreds   : 레지스트리 로그인 credentialsId
 *   releaseTag   : 릴리스 태그 (이미지 태그로 사용)
 *   buildArgs    : [k:v] 형태의 --build-arg 맵 (선택)
 */
def buildAndPush(Map args) {
    def buildArgFlags = (args.buildArgs ?: [:])
        .collect { k, v -> "--build-arg ${k}=${v}" }
        .join(' ')

    withCredentials([usernamePassword(
            credentialsId: args.nexusCreds,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        sh """
            echo "\$NEXUS_PASS" | docker login ${args.registry} \
                -u "\$NEXUS_USER" --password-stdin

            docker build ${buildArgFlags} \
                -t ${args.image}:${args.releaseTag} \
                -t ${args.image}:latest \
                .

            docker push ${args.image}:${args.releaseTag}
            docker push ${args.image}:latest
        """
    }
}

def logout(String registry) {
    sh "docker logout ${registry}"
}
