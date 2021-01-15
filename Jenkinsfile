/* groovylint-disable CompileStatic, DuplicateStringLiteral, NestedBlockDepth */

String dockerTag
String dockerSaveFile
String githubUrl = 'https://github.com/kevinswiber/learner-api'

pipeline {
    agent any

    options {
        buildDiscarder logRotator(
            artifactDaysToKeepStr: '10',
            artifactNumToKeepStr: '2',
            daysToKeepStr: '5',
            numToKeepStr: '5'
        )
        copyArtifactPermission('postman/learner-api-promote')
    }

    stages {
        stage('setup') {
            steps {
                script {
                    hash = GIT_COMMIT.substring(0, 7)
                    dockerTag = "ghcr.io/kevinswiber/learner-api:${hash}"
                    dockerSaveFile = "learner-api-${hash}.tar.gz"

                    if (env.CHANGE_ID != null) {
                        env.GIT_REF_TYPE = 'pr'
                        env.GIT_REF_NAME = "${env.CHANGE_ID}"
                    } else if (env.TAG_NAME != null) {
                        env.GIT_REF_TYPE = 'tag'
                        env.GIT_REF_NAME = "${env.TAG_NAME}"
                    } else {
                        env.GIT_REF_TYPE = 'branch'
                        env.GIT_REF_NAME = "${env.BRANCH_NAME}"
                    }
                }
            }
        }

        stage('npm install and test') {
            agent {
                docker {
                    image 'kevinswiber/node-curl-jq'
                }
            }

            stages {
                stage('build') {
                    steps {
                        sh 'npm install'
                    }
                }

                stage('postman tests') {
                    steps {
                        withCredentials([string(credentialsId: 'postman-api-key', variable: 'POSTMAN_API_KEY')]) {
                            sh 'npm run postman-tests'
                        }
                    }

                    post {
                        always {
                            junit 'newman/*.xml'
                        }
                    }
                }
            }
        }

        stage('docker build and save') {
            agent any

            steps {
                sh "docker build -t ${dockerTag} ."
                sh "docker save ${dockerTag} | gzip > ${dockerSaveFile}"
            }

            post {
                success {
                    archiveArtifacts artifacts: "${dockerSaveFile}", fingerprint: true
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: '#ci', blocks: [
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "🎉 *${currentBuild.currentResult}* 🎉",
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "*Job:* ${JOB_NAME}"
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "*Build:* <${currentBuild.absoluteUrl}|${BUILD_NUMBER}>"
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "*Build duration:* ${currentBuild.durationString}"
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "*Commit:* <${githubUrl}/commit/${GIT_COMMIT}|${hash}>"
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'text': [
                        'type': 'mrkdwn',
                        'text': "Docker image: ${dockerTag}"
                    ],
                    'accessory': [
                        'type': 'button',
                        'text': [
                            'type': 'plain_text',
                            'text': 'Download'
                        ],
                        'url': "${currentBuild.absoluteUrl}artifact/${dockerSaveFile}",
                    ]
                ]
            ])
        }
        failure {
            slackSend(channel: '#ci', color: 'danger', message: "Build failure ${currentBuild.absoluteUrl}")
        }
    }
}
