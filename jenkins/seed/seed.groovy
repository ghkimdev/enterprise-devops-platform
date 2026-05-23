println "Starting Seed Job..."

folder('applications') {
    displayName('Applications')
    description('Application Pipelines')
}

def createPipelineJob(
    name,
    repo,
    script
) {
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

createPipelineJob(
    'applications/sample-spring-build',
    'http://svn/svn/sample-spring/trunk',
    'Jenkinsfile.build-spring'
)

createPipelineJob(
    'applications/sample-spring-checkitem',
    'http://svn/svn/sample-spring/trunk',
    'Jenkinsfile.checkitem-spring'
)

createPipelineJob(
    'applications/sample-spring-release',
    'http://svn/svn/sample-spring/trunk',
    'Jenkinsfile.release-spring'
)

createPipelineJob(
    'applications/sample-spring-deploy',
    'http://svn/svn/sample-spring/trunk',
    'Jenkinsfile.deploy-spring'
)

createPipelineJob(
    'applications/sample-react-build',
    'http://svn/svn/sample-react/trunk',
    'Jenkinsfile.build-react'
)

createPipelineJob(
    'applications/sample-react-checkitem',
    'http://svn/svn/sample-react/trunk',
    'Jenkinsfile.checkitem-react'
)

createPipelineJob(
    'applications/sample-react-release',
    'http://svn/svn/sample-react/trunk',
    'Jenkinsfile.release-react'
)

createPipelineJob(
    'applications/sample-react-deploy',
    'http://svn/svn/sample-react/trunk',
    'Jenkinsfile.deploy-react'
)

createPipelineJob(
    'applications/sample-fastapi-build',
    'http://svn/svn/sample-fastapi/trunk',
    'Jenkinsfile.build-fastapi'
)

createPipelineJob(
    'applications/sample-fastapi-checkitem',
    'http://svn/svn/sample-fastapi/trunk',
    'Jenkinsfile.checkitem-fastapi'
)

createPipelineJob(
    'applications/sample-fastapi-release',
    'http://svn/svn/sample-fastapi/trunk',
    'Jenkinsfile.release-fastapi'
)

createPipelineJob(
    'applications/sample-fastapi-deploy',
    'http://svn/svn/sample-fastapi/trunk',
    'Jenkinsfile.deploy-fastapi'
)

println "Seed Job Complete"
