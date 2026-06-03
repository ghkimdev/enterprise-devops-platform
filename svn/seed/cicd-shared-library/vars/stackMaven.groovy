// vars/stackMaven.groovy
//
// Spring 등 Maven 앱의 스택별 빌드 동작.
// 버전을 timestamp 로 set 한 뒤 verify, 그리고 mvn deploy 로 maven-releases 에 업로드.

def validateSource() {
    sh '''
        test -f pom.xml
        test -f settings.xml
    '''
}

def installAndTest(Map cfg) {
    withCredentials([usernamePassword(
            credentialsId: cfg.nexusCreds,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        sh """
            mvn -s settings.xml -B \
                versions:set \
                -DnewVersion=${cfg.mavenVersion} \
                -DgenerateBackupPoms=false

            mvn -s settings.xml -B clean verify
        """
    }
    junit(allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml')
}

/** mvn deploy 로 maven-releases 업로드. 산출 JAR 의 ARTIFACT_URL 반환. */
def packageAndUpload(Map cfg) {
    withCredentials([usernamePassword(
            credentialsId: cfg.nexusCreds,
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS')]) {
        sh """
            mvn -s settings.xml -B -DskipTests deploy
        """
    }
    def groupPath = cfg.mavenGroupId.replace('.', '/')
    return "${cfg.nexusBase}/repository/${cfg.mavenReleasesRepo}/" +
           "${groupPath}/${cfg.mavenArtifactId}/" +
           "${cfg.mavenVersion}/${cfg.mavenArtifactId}-${cfg.mavenVersion}.jar"
}
