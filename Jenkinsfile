/* groovylint-disable CompileStatic, DuplicateStringLiteral, NestedBlockDepth */

String githubUrl = 'https://github.com/kevinswiber/learner-api'
String repository = '780401591112.dkr.ecr.us-east-1.amazonaws.com/learner-api'

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
                script {
                    if (env.CHANGE_ID != null) {
                        gitRefType = 'pr'
                        gitRefName = "${env.CHANGE_ID}"
                    } else if (env.TAG_NAME != null) {
                        gitRefType = 'tag'
                        gitRefName = "${env.TAG_NAME}"
                    } else {
                        gitRefType = 'branch'
                        gitRefName = "${env.BRANCH_NAME}"
                    }
                }

                container('node-curl-jq') {
                    withCredentials(
                        [string(credentialsId: 'learner-api-postman-api-key', variable: 'POSTMAN_API_KEY')]
                    ) {
                        withEnv(["GIT_REF_TYPE=${gitRefType}", "GIT_REF_NAME=${gitRefName}"]) {
                            sh 'npm run postman-tests'
                        }
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
                    imageTag = "${repository}:${env.GIT_COMMIT[0..6]}"
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
                            'text': "*Commit:* <${githubUrl}/commit/${GIT_COMMIT}|${env.GIT_COMMIT[0..6]}>"
                        ]
                    ]
                ],
                [
                    'type': 'section',
                    'fields': [
                        [
                            'type': 'mrkdwn',
                            'text': "*Image:* ${repository}:${env.GIT_COMMIT[0..6]}"
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
