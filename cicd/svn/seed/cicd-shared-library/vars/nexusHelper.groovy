// vars/nexusHelper.groovy
//
// Nexus raw repo 업로드 / 아티팩트 존재 확인.

/**
 * 로컬 파일을 Nexus raw repo 의 {repo}/{appName}/{fileName} 으로 업로드하고
 * 업로드된 전체 URL 을 반환한다.
 */
def uploadRaw(Map cfg, String fileName) {
    def baseUrl = "${cfg.nexusBase}/repository/${cfg.rawRepo}/${cfg.appName}"
    withCredentials([usernamePassword(
            credentialsId: cfg.nexusCreds,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        sh """
            curl -fsS --user "\$NEXUS_USER:\$NEXUS_PASS" \
                --upload-file "${fileName}" \
                "${baseUrl}/${fileName}"
        """
    }
    return "${baseUrl}/${fileName}"
}

/** HEAD 요청으로 아티팩트가 존재하는지 확인한다. 없으면 빌드 실패. */
def verifyExists(String url, String credsId) {
    withCredentials([usernamePassword(
            credentialsId: credsId,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        sh """
            echo "Checking: ${url}"
            if ! curl -fsS -I --user "\$NEXUS_USER:\$NEXUS_PASS" "${url}" > /dev/null; then
                echo "Artifact not found: ${url}"
                exit 1
            fi
        """
    }
}
