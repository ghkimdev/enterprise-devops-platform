// vars/deployPipeline.groovy
//
// 지정한 아티팩트를 대상 환경(dev/stg/prod)에 배포한다. 실제 배포는 Rundeck 잡이 수행.
// prod 는 input approval 을 거친다.
//
// 필요한 config (Map):
//   artifactType   'raw' (fastapi/react) | 'maven' (spring)
//   appName / team
//   nexusBase / nexusCreds
//   rundeckInstance / rundeckDeployJob
//   --- raw 전용 ---
//   rawRepo
//   --- maven 전용 ---
//   mavenReleasesRepo / mavenGroupId / mavenArtifactId

def call(Map config) {
    def isMaven = (config.artifactType == 'maven')

    // 아티팩트 선택 파라미터는 타입에 따라 달라서 properties() 로 동적 선언
    def artifactParam = isMaven
        ? nexus3Maven(
            name: 'ARTIFACT_URL', url: config.nexusBase,
            repository: config.mavenReleasesRepo,
            groupId: config.mavenGroupId, artifactId: config.mavenArtifactId,
            packaging: 'jar', credentialsId: config.nexusCreds)
        : nexus3Generic(
            name: 'ARTIFACT_URL', url: config.nexusBase,
            repository: config.rawRepo, assetName: '',
            credentialsId: config.nexusCreds)

    properties([
        parameters([
            artifactParam,
            choice(name: 'TARGET_ENV', choices: ['dev', 'stg', 'prod'],
                   description: '배포 대상 환경')
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
            buildDiscarder(logRotator(numToKeepStr: '50'))
            disableConcurrentBuilds()
            timestamps()
        }

        environment {
            APP_NAME = "${config.appName}"
            TEAM     = "${config.team}"
        }

        stages {
            stage('Validate Parameters') {
                steps {
                    script {
                        if (isMaven) {
                            // .../{version}/{artifact}-{version}.jar → version 추출
                            env.APP_VERSION  = params.ARTIFACT_URL.tokenize('/')[-2]
                            env.RELEASE_NAME = "r-${config.appName}-${env.APP_VERSION}"
                        } else {
                            // .../{release}.tar.gz → 파일명
                            env.APP_VERSION = params.ARTIFACT_URL.tokenize('/')[-1]
                            if (!env.APP_VERSION?.endsWith('.tar.gz')) {
                                error 'ARTIFACT_URL must point to a .tar.gz'
                            }
                            env.RELEASE_NAME = env.APP_VERSION.replaceAll(/\.tar\.gz$/, '')
                        }
                        if (!env.APP_VERSION?.trim()) {
                            error 'APP_VERSION could not be resolved from ARTIFACT_URL.'
                        }
                        currentBuild.displayName =
                            "#${env.BUILD_NUMBER} ${params.TARGET_ENV} ← ${env.RELEASE_NAME}"
                        echo """
APP             : ${config.appName}
RELEASE         : ${env.RELEASE_NAME}
TARGET ENV      : ${params.TARGET_ENV}"""
                    }
                }
            }

            stage('Approval (prod only)') {
                when {
                    expression { params.TARGET_ENV == 'prod' }
                }
                steps {
                    timeout(time: 30, unit: 'MINUTES') {
                        input(message: "Deploy ${env.RELEASE_NAME} to PROD?", ok: 'Deploy')
                    }
                }
            }

            stage('Verify Artifact Exists') {
                steps {
                    script {
                        def url
                        if (isMaven) {
                            def groupPath = config.mavenGroupId.replace('.', '/')
                            url = "${config.nexusBase}/repository/${config.mavenReleasesRepo}/" +
                                  "${groupPath}/${config.mavenArtifactId}/" +
                                  "${env.APP_VERSION}/${config.mavenArtifactId}-${env.APP_VERSION}.jar"
                        } else {
                            url = "${config.nexusBase}/repository/${config.rawRepo}/" +
                                  "${config.appName}/${env.APP_VERSION}"
                        }
                        nexusHelper.verifyExists(url, config.nexusCreds)
                    }
                }
            }

            stage('Deploy via Rundeck') {
                steps {
                    echo "Rundeck 잡 호출: ${config.rundeckDeployJob} (env=${params.TARGET_ENV}, release=${env.RELEASE_NAME})"
                    step([
                        $class                  : 'RundeckNotifier',
                        rundeckInstance         : config.rundeckInstance,
                        jobId                   : config.rundeckDeployJob,
                        options                 : """
app=${config.appName}
version=${env.APP_VERSION}
release_name=${env.RELEASE_NAME}
env=${params.TARGET_ENV}
team=${config.team}
""".trim(),
                        shouldWaitForRundeckJob : true,
                        shouldFailTheBuild      : true,
                        includeRundeckLogs      : true,
                        tailLog                 : true
                    ])
                }
            }

            stage('Archive Deploy Metadata') {
                steps {
                    script {
                        writeJSON file: 'deploy-info.json', json: [
                            app: config.appName,
                            team: config.team,
                            release_name: env.RELEASE_NAME,
                            app_version: env.APP_VERSION,
                            target_env: params.TARGET_ENV,
                            build_number: env.BUILD_NUMBER,
                            build_url: env.BUILD_URL
                        ], pretty: 2
                    }
                    archiveArtifacts artifacts: 'deploy-info.json', fingerprint: true
                }
            }

            stage('Summary') {
                steps {
                    script {
                        def info = readJSON file: 'deploy-info.json'
                        def rows = info.collect { k, v -> "  ${k.padRight(20)}: ${v}" }.join('\n')
                        echo """
==================================================
DEPLOY SUMMARY — ${config.appName}
==================================================
${rows}

배포 방식: Rundeck (${config.rundeckDeployJob})
=================================================="""
                    }
                }
            }
        }

        post {
            success {
                echo """
==================================================
DEPLOY SUCCESS
==================================================
APP         : ${config.appName}
RELEASE     : ${env.RELEASE_NAME}
ENV         : ${params.TARGET_ENV}
=================================================="""
            }
            always {
                script {
                    metricsHelper.record([
                        kind       : 'deploy',
                        app        : config.appName,
                        team       : config.team,
                        env        : params.TARGET_ENV,
                        result     : currentBuild.currentResult,
                        durationSec: ((currentBuild.duration ?:
                                      (System.currentTimeMillis() - currentBuild.startTimeInMillis)).intdiv(1000)),
                        infoFile   : 'deploy-info.json'
                    ])
                }
                cleanWs()
            }
        }
    }
}
