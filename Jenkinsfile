/* groovylint-disable CompileStatic, DuplicateStringLiteral, NestedBlockDepth */

String githubUrl = 'https://github.com/kevinswiber/learner-api'

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: node-curl-jq
      image: kevinswiber/node-curl-jq
      command:
        - cat
      tty: true
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command:
        - sleep
      args:
        - "999999"
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker/
      restartPolicy: Never
  volumes:
    - name: docker-config
      configMap:
        name: docker-config
'''
        }
    }

    options {
        buildDiscarder logRotator(
            artifactDaysToKeepStr: '10',
            artifactNumToKeepStr: '2',
            daysToKeepStr: '5',
            numToKeepStr: '5'
        )
    }

    stages {
        stage('setup') {
            steps {
                script {
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

        stage('build') {
            steps {
                container('node-curl-jq') {
                    sh 'npm install'
                }
            }
        }

        stage('postman tests') {
            steps {
                container('node-curl-jq') {
                    withCredentials(
                        [string(credentialsId: 'learner-api-postman-api-key', variable: 'POSTMAN_API_KEY')]
                    ) {
                        sh 'npm run postman-tests'
                    }
                }
            }

            post {
                always {
                    junit 'newman/*.xml'
                }
            }
        }

        stage('docker build and push') {
            steps {
                script {
                    hash = GIT_COMMIT.substring(0, 7)
                    imageTag = "780401591112.dkr.ecr.us-east-1.amazonaws.com/learner-api:${hash}"
                }

                container('kaniko') {
                    sh "/kaniko/executor -c `pwd` --cache=true --destination=${imageTag}"
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
                            'text': "*Commit:* <${githubUrl}/commit/${GIT_COMMIT}|${env.GIT_COMMIT[0..7]}>"
                        ]
                    ]
                ]
            ])
        }
        failure {
            slackSend(channel: '#ci', color: 'danger', message: "Build failure ${currentBuild.absoluteUrl}")
        }
    }
}
