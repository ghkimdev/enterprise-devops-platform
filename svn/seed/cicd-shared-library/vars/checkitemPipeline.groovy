// vars/checkitemPipeline.groovy
//
// trunk 와 선택한 release tag 사이 변경사항을 정리해 archive 하고,
// 동일 svn revision 으로 빌드하도록 build 잡을 트리거한다.
//
// 필요한 config (Map):
//   appName               예: 'sample-fastapi'
//   agentImage            예: 'jenkins-agent-python:1.0.0'
//   svnBase / svnTrunk / svnTags   SVN 경로
//   svnCreds              예: 'svn-creds'
//   buildJob              트리거할 build 잡 full name (예: 'ml/sample-fastapi-build')
//   copyArtifactPermission  build 잡에 산출물 복사를 허용할 잡 이름 (예: 'sample-fastapi-build')

def call(Map config) {
    // tagsDir 파라미터(ListSubversionTags)는 동적이라 properties() 로 선언
    properties([
        parameters([
            [
                $class: 'ListSubversionTagsParameterDefinition',
                name: 'BASE_TAG',
                tagsDir: config.svnTags,
                credentialsId: config.svnCreds,
                reverseByDate: true,
                maxTags: '20'
            ]
        ])
    ])

    pipeline {
        agent {
            docker {
                image config.agentImage
                args '--network cicd-net'
            }
        }

        options {
            buildDiscarder(logRotator(numToKeepStr: '30'))
            disableConcurrentBuilds()
            timestamps()
            copyArtifactPermission(config.copyArtifactPermission)
        }

        environment {
            APP_NAME  = "${config.appName}"
            TEAM      = "${config.team}"
            SVN_TRUNK = "${config.svnTrunk}"
            SVN_TAGS  = "${config.svnTags}"
            SVN_CREDS = "${config.svnCreds}"
            BUILD_JOB = "${config.buildJob}"
        }

        stages {
            stage('Validate') {
                steps {
                    script {
                        if (!env.BASE_TAG?.trim()) {
                            error 'BASE_TAG is required.'
                        }
                    }
                }
            }

            stage('Checkout Trunk') {
                steps {
                    cleanWs()
                    script {
                        svnHelper.checkout(config.svnTrunk, config.svnCreds)
                    }
                }
            }

            stage('Collect Revisions') {
                steps {
                    script {
                        env.NEW_REVISION = svnHelper.revisionOf(config.svnTrunk, config.svnCreds)
                        env.OLD_REVISION = svnHelper.revisionOf(
                            "${config.svnTags}/${env.BASE_TAG}", config.svnCreds)
                        currentBuild.displayName = "#${env.BUILD_NUMBER} r${env.NEW_REVISION}"
                        echo """
==================================================
CHECKITEM METADATA
==================================================
APP             : ${config.appName}
BASE_TAG        : ${env.BASE_TAG}
OLD_REVISION    : ${env.OLD_REVISION}
NEW_REVISION    : ${env.NEW_REVISION}
=================================================="""
                    }
                }
            }

            stage('Generate Diff and Log') {
                steps {
                    script {
                        svnHelper.diffAndLog(
                            config.svnTrunk, config.svnCreds,
                            env.OLD_REVISION, env.NEW_REVISION)
                    }
                }
            }

            stage('Write checkitem.json') {
                steps {
                    script {
                        writeJSON file: 'checkitem.json', json: [
                            app: config.appName,
                            team: config.team,
                            latest_tag: env.BASE_TAG,
                            old_revision: env.OLD_REVISION,
                            new_revision: env.NEW_REVISION,
                            svn_revision: env.NEW_REVISION,
                            checkitem_build_number: env.BUILD_NUMBER,
                            checkitem_build_url: env.BUILD_URL
                        ], pretty: 2
                    }
                }
            }

            stage('Write release-note.md') {
                steps {
                    sh """
                        cat > release-note.md <<EOF
# Release Check Item

## Application
${config.appName}

## Base Tag
${env.BASE_TAG}

## Revision Range
- Old: r${env.OLD_REVISION}
- New: r${env.NEW_REVISION}

## Changed Files

EOF
                        cat changed-files.txt >> release-note.md

                        cat >> release-note.md <<EOF

## Commit Log

EOF
                        cat commit-log.txt >> release-note.md
                    """
                }
            }

            stage('Archive') {
                steps {
                    archiveArtifacts(
                        artifacts: 'checkitem.json,changed-files.txt,commit-log.txt,release-note.md',
                        fingerprint: true,
                        allowEmptyArchive: true
                    )
                }
            }

            stage('Summary') {
                steps {
                    script {
                        def changed = readFile('changed-files.txt').trim()
                        def commits = readFile('commit-log.txt').trim()
                        echo """
==================================================
CHECKITEM SUMMARY — ${config.appName}
==================================================
BASE_TAG     : ${env.BASE_TAG}
REVISION     : r${env.OLD_REVISION} → r${env.NEW_REVISION}
CHECKITEM #  : ${env.BUILD_NUMBER}

[ Changed Files ]
${changed}

[ Commit Log ]
${commits}

=================================================="""
                    }
                }
            }

            stage('Trigger Build') {
                steps {
                    build(
                        job: config.buildJob,
                        wait: false,
                        parameters: [
                            string(name: 'CHECKITEM_BUILD_NUMBER', value: env.BUILD_NUMBER)
                        ]
                    )
                }
            }
        }

        post {
            success {
                echo """
==================================================
CHECKITEM SUCCESS — ${config.appName}
==================================================
NEW_REVISION    : ${env.NEW_REVISION}
CHECKITEM #     : ${env.BUILD_NUMBER}

=================================================="""
            }
            always {
                script {
                    metricsHelper.record([
                        kind       : 'checkitem',
                        app        : config.appName,
                        team       : config.team,
                        env        : params.TARGET_ENV,
                        result     : currentBuild.currentResult,
                        durationSec: ((currentBuild.duration ?:
                                      (System.currentTimeMillis() - currentBuild.startTimeInMillis)).intdiv(1000)),
                        infoFile   : 'checkitem-info.json'
                    ])
                }
                cleanWs()
            }
        }
    }
}
