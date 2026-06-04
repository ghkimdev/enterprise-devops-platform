// vars/buildPipeline.groovy
//
// checkitem 결과를 참조해 불변 SVN tag 를 만들고, 스택별로 빌드/테스트/패키징한 뒤
// Nexus 업로드 + Docker push + dev deploy 트리거까지 수행한다.
//
// 스택별 install/test/package 동작은 stackPython / stackNode / stackMaven 으로 위임.
//
// 필요한 config (Map):
//   stack                 'fastapi' | 'react' | 'spring'
//   appName               예: 'sample-spring'
//   agentImage            예: 'jenkins-agent-java21:1.0.0'
//   svnTrunk / svnTags / svnCreds
//   nexusBase / nexusCreds
//   dockerRegistry / dockerImage
//   checkitemJob          copyArtifacts 대상 (예: 'payment/sample-spring-checkitem')
//   devDeployJob          트리거할 deploy 잡 (예: 'payment/sample-spring-deploy')
//   autoDeployEnv         예: 'dev'
//   --- raw(fastapi/react) 전용 ---
//   rawRepo               예: 'fastapi-releases'
//   pipIndexUrl / pipTrustedHost   (python)
//   npmRegistry                    (node)
//   --- maven(spring) 전용 ---
//   mavenReleasesRepo / mavenGroupId / mavenArtifactId

// config.stack -> 스택 헬퍼 글로벌 변수
def stackImpl(String stack) {
    switch (stack) {
        case 'fastapi': return stackPython
        case 'react':   return stackNode
        case 'spring':  return stackMaven
        default:        error "Unknown stack: ${stack}"
    }
}

def call(Map config) {
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
        }

        parameters {
            string(
                name: 'CHECKITEM_BUILD_NUMBER',
                defaultValue: '',
                description: '참조할 checkitem 잡의 빌드 번호 (필수)'
            )
        }

        environment {
            APP_NAME = "${config.appName}"
            TEAM     = "${config.team}"
        }

        stages {
            stage('Validate Parameters') {
                steps {
                    script {
                        if (!params.CHECKITEM_BUILD_NUMBER?.trim()) {
                            error 'CHECKITEM_BUILD_NUMBER is required.'
                        }
                    }
                }
            }

            stage('Fetch Checkitem Artifact') {
                steps {
                    cleanWs()
                    copyArtifacts(
                        projectName: config.checkitemJob,
                        selector: specific(params.CHECKITEM_BUILD_NUMBER),
                        filter: 'checkitem.json',
                        target: '.'
                    )
                    script {
                        def checkitem = readJSON file: 'checkitem.json'
                        env.SVN_REVISION = checkitem.svn_revision as String
                        env.BASE_TAG     = checkitem.latest_tag as String
                        if (!env.SVN_REVISION || env.SVN_REVISION == '0') {
                            error 'Invalid checkitem.json: svn_revision missing'
                        }
                        echo "SVN_REVISION = ${env.SVN_REVISION}"
                    }
                }
            }

            stage('Prepare Release Name') {
                steps {
                    script {
                        env.TIMESTAMP = sh(
                            returnStdout: true,
                            script: 'TZ=Asia/Seoul date +%Y%m%d_%H%M%S'
                        ).trim()
                        env.RELEASE_NAME  = "r-${config.appName}-${env.TIMESTAMP}"
                        env.RELEASE_TAG   = "${config.svnTags}/${env.RELEASE_NAME}"
                        env.TAR_NAME      = "${env.RELEASE_NAME}.tar.gz"
                        env.MAVEN_VERSION = env.TIMESTAMP   // spring 에서 사용

                        currentBuild.displayName =
                            "#${env.BUILD_NUMBER} ${env.RELEASE_NAME} (r${env.SVN_REVISION})"
                        echo """
RELEASE_NAME    : ${env.RELEASE_NAME}
SVN_REVISION    : ${env.SVN_REVISION}"""
                    }
                }
            }

            stage('Create Immutable SVN Tag') {
                steps {
                    script {
                        svnHelper.createReleaseTag([
                            svnCreds:    config.svnCreds,
                            svnTrunk:    config.svnTrunk,
                            releaseTag:  env.RELEASE_TAG,
                            releaseName: env.RELEASE_NAME,
                            svnRevision: env.SVN_REVISION
                        ])
                    }
                }
            }

            stage('Checkout Release Tag') {
                steps {
                    cleanWs()
                    script {
                        svnHelper.checkout(env.RELEASE_TAG, config.svnCreds)
                    }
                }
            }

            stage('Validate Source') {
                steps {
                    script {
                        stackImpl(config.stack).validateSource()
                    }
                }
            }

            stage('Install, Test & Build') {
                steps {
                    script {
                        stackImpl(config.stack).installAndTest(stackCfg(config))
                    }
                }
            }

            stage('Package & Upload to Nexus') {
                steps {
                    script {
                        env.ARTIFACT_URL =
                            stackImpl(config.stack).packageAndUpload(stackCfg(config))
                        echo "Artifact: ${env.ARTIFACT_URL}"
                    }
                }
            }

            stage('Docker Build & Push') {
                steps {
                    script {
                        def buildArgs = [APP_VERSION: env.RELEASE_NAME]
                        if (config.stack == 'spring') {
                            buildArgs.BUILD_TIMESTAMP = env.TIMESTAMP
                        }
                        dockerHelper.buildAndPush([
                            registry:   config.dockerRegistry,
                            image:      config.dockerImage,
                            nexusCreds: config.nexusCreds,
                            releaseTag: env.RELEASE_NAME,
                            buildArgs:  buildArgs
                        ])
                    }
                }
            }

            stage('Archive Build Metadata') {
                steps {
                    script {
                        writeJSON file: 'build-info.json', json: [
                            app: config.appName,
                            team: config.team,
                            release_name: env.RELEASE_NAME,
                            maven_version: env.MAVEN_VERSION,
                            svn_revision: env.SVN_REVISION,
                            release_tag_url: env.RELEASE_TAG,
                            checkitem_build_number: params.CHECKITEM_BUILD_NUMBER,
                            timestamp: env.TIMESTAMP,
                            artifact_url: env.ARTIFACT_URL,
                            docker_image: "${config.dockerImage}:${env.RELEASE_NAME}",
                            build_number: env.BUILD_NUMBER,
                            build_url: env.BUILD_URL
                        ], pretty: 2
                    }
                    archiveArtifacts artifacts: 'build-info.json', fingerprint: true
                }
            }

            stage('Summary') {
                steps {
                    script {
                        def info = readJSON file: 'build-info.json'
                        def rows = info.collect { k, v -> "  ${k.padRight(24)}: ${v}" }.join('\n')
                        echo """
==================================================
BUILD SUMMARY — ${config.appName}
==================================================
${rows}

다음 단계: ${config.devDeployJob} (${config.autoDeployEnv}) 자동 트리거
=================================================="""
                    }
                }
            }

            stage('Trigger Dev Deploy') {
                steps {
                    build(
                        job: config.devDeployJob,
                        parameters: [
                            string(name: 'ARTIFACT_URL', value: env.ARTIFACT_URL),
                            string(name: 'TARGET_ENV',  value: config.autoDeployEnv)
                        ],
                        wait: false
                    )
                }
            }
        }

        post {
            success {
                echo """
==================================================
BUILD SUCCESS — ${config.appName}
==================================================
RELEASE         : ${env.RELEASE_NAME}
ARTIFACT_URL    : ${env.ARTIFACT_URL}
DOCKER          : ${config.dockerImage}:${env.RELEASE_NAME}
=================================================="""
            }
            always {
                script {
                    metricsHelper.record([
                        kind       : 'build',
                        app        : config.appName,
                        team       : config.team,
                        env        : config.autoDeployEnv,
                        result     : currentBuild.currentResult,
                        durationSec: ((currentBuild.duration ?:
                                      (System.currentTimeMillis() - currentBuild.startTimeInMillis)).intdiv(1000)),
                        infoFile   : 'build-info.json'
                    ])
                }
                sh "docker logout ${config.dockerRegistry}"
                cleanWs()
            }
                sh "docker logout ${config.dockerRegistry}"
                cleanWs()
            }
        }
    }
}

// 스택 헬퍼에 넘길 런타임 값(env)들을 config 에 합쳐서 전달
def stackCfg(Map config) {
    return config + [
        releaseName:  env.RELEASE_NAME,
        timestamp:    env.TIMESTAMP,
        svnRevision:  env.SVN_REVISION,
        tarName:      env.TAR_NAME,
        mavenVersion: env.MAVEN_VERSION
    ]
}
