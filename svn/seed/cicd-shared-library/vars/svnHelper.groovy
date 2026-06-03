// vars/svnHelper.groovy
//
// SVN 관련 공통 동작 모음. 모든 메서드는 credentialsId 로 svn-creds 를 받아
// withCredentials 로 SVN_USER / SVN_PASS 를 노출한 뒤 svn 명령을 실행한다.

/** trunk(또는 임의 URL)을 현재 워크스페이스에 체크아웃한다. */
def checkout(String url, String credsId) {
    withCredentials([usernamePassword(
            credentialsId: credsId,
            usernameVariable: 'SVN_USER',
            passwordVariable: 'SVN_PASS')]) {
        sh """
            svn checkout \
                --username "\$SVN_USER" \
                --password "\$SVN_PASS" \
                --no-auth-cache \
                --non-interactive \
                ${url} .
        """
    }
}

/** 주어진 URL 의 현재 revision 번호를 문자열로 반환한다. */
def revisionOf(String url, String credsId) {
    def rev
    withCredentials([usernamePassword(
            credentialsId: credsId,
            usernameVariable: 'SVN_USER',
            passwordVariable: 'SVN_PASS')]) {
        rev = sh(
            returnStdout: true,
            script: """
                svn info --username "\$SVN_USER" --password "\$SVN_PASS" \
                    --no-auth-cache --show-item revision ${url}
            """
        ).trim()
    }
    return rev
}

/**
 * old:new revision 범위에 대해 변경 파일 목록과 커밋 로그를 파일로 남긴다.
 * changed-files.txt, commit-log.txt 를 워크스페이스에 생성.
 */
def diffAndLog(String url, String credsId, String oldRev, String newRev) {
    withCredentials([usernamePassword(
            credentialsId: credsId,
            usernameVariable: 'SVN_USER',
            passwordVariable: 'SVN_PASS')]) {
        sh """
            svn diff --summarize \
                --username "\$SVN_USER" --password "\$SVN_PASS" --no-auth-cache \
                -r ${oldRev}:${newRev} \
                ${url} > changed-files.txt

            svn log \
                --username "\$SVN_USER" --password "\$SVN_PASS" --no-auth-cache \
                -r ${oldRev}:${newRev} \
                ${url} > commit-log.txt
        """
    }
}

/**
 * trunk@revision 을 불변(immutable) release tag 로 복사한다.
 * 이미 동일 tag 가 있으면 실패시킨다(동일 timestamp 충돌 방지).
 */
def createReleaseTag(Map cfg) {
    withCredentials([usernamePassword(
            credentialsId: cfg.svnCreds,
            usernameVariable: 'SVN_USER',
            passwordVariable: 'SVN_PASS')]) {
        sh """
            if svn info --username "\$SVN_USER" --password "\$SVN_PASS" --no-auth-cache \
                    "${cfg.releaseTag}" 2>/dev/null; then
                echo "Tag already exists: ${cfg.releaseTag}"
                exit 1
            fi
            svn copy \
                --username "\$SVN_USER" --password "\$SVN_PASS" --no-auth-cache \
                -m "Create release ${cfg.releaseName} from trunk@r${cfg.svnRevision}" \
                -r ${cfg.svnRevision} \
                "${cfg.svnTrunk}" \
                "${cfg.releaseTag}"
        """
    }
}
