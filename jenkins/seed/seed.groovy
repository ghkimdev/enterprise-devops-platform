println "Starting Seed Job..."


// ─────────────────────────────────────────────
// Root Folder
// ─────────────────────────────────────────────
//folder('applications') {
//    displayName('Applications')
//    description('Application Pipelines')

//    authorization {

//        ['payment-team','web-team','ml-team'].each { g ->
//            groupPermissions(g, [
//                'hudson.model.Item.Read',
//                'hudson.model.Item.Discover'
//            ])
//        }

//        groupPermissions('admin', [
//            'hudson.model.Item.Read',
//            'hudson.model.Item.Discover',
//            'hudson.model.Item.Configure',
//            'hudson.model.Item.Delete'
//        ])
//    }
//}

// ─────────────────────────────────────────────
// Team Folder 생성
// ─────────────────────────────────────────────
def teams = [
    [
        folder: 'payment',
        group : 'payment-team'
    ],
    [
        folder: 'web',
        group : 'web-team'
    ],
    [
        folder: 'ml',
        group : 'ml-team'
    ]
]

teams.each { cfg ->

    folder(cfg.folder) {

        displayName(cfg.folder)

        authorization {

            groupPermissions(cfg.group, [
                'hudson.model.Item.Read',
                'hudson.model.Item.Discover',
                'hudson.model.Item.Build',
                'hudson.model.Item.Cancel',
                'hudson.model.Item.Workspace'
            ])

            groupPermissions('admin', [
                'hudson.model.Item.Read',
                'hudson.model.Item.Discover',
                'hudson.model.Item.Build',
                'hudson.model.Item.Cancel',
                'hudson.model.Item.Configure',
                'hudson.model.Item.Delete',
                'hudson.model.Item.Workspace'
            ])
        }
    }
}


// ─────────────────────────────────────────────
// Pipeline Job Helper
// ─────────────────────────────────────────────
def createPipelineJob(
        String name,
        String repo,
        String script) {

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


// ─────────────────────────────────────────────
// App 목록
// ─────────────────────────────────────────────
def apps = [
    [
        app   : 'sample-spring',
        team  : 'payment',
        script: 'spring'
    ],
    [
        app   : 'sample-react',
        team  : 'web',
        script: 'react'
    ],
    [
        app   : 'sample-fastapi',
        team  : 'ml',
        script: 'fastapi'
    ]
]


// ─────────────────────────────────────────────
// Job 생성
// ─────────────────────────────────────────────
apps.each { cfg ->

    def app = cfg.app
    def team = cfg.team

    def repo = "http://svn/svn/${app}/trunk"

    createPipelineJob(
        "${team}/${app}-checkitem",
        repo,
        "Jenkinsfile.checkitem-${cfg.script}"
    )

    createPipelineJob(
        "${team}/${app}-build",
        repo,
        "Jenkinsfile.build-${cfg.script}"
    )

    createPipelineJob(
        "${team}/${app}-deploy",
        repo,
        "Jenkinsfile.deploy-${cfg.script}"
    )
}

println "Seed Job Complete: ${apps.size()} apps × 3 jobs = ${apps.size() * 3} jobs"
