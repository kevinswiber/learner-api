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
        copyArtifactPermission('/galaxy-pipelines/learner-api/deploy-staging')
    }

    stages {
        stage('build & test') {
            steps {
                container('node-curl-jq') {
                    sh 'npm install'

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
                    sh """/kaniko/executor \
                            -c `pwd` \
                            --cache=true \
                            --destination=${imageTag} \
                            --image-name-with-digest-file=image-name-with-digest"""
                    archiveArtifacts 'image-name-with-digest'
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: '#ci', blocks: [
                [
                    'type': 'section',
                    'text': [
                        'type': 'mrkdwn',
                        'text': """🎉 *Success!* 🎉
*Job:* ${JOB_NAME}
*Build:* <${currentBuild.absoluteUrl}|${BUILD_NUMBER}>
*Build duration:* ${currentBuild.durationString}
*Commit:* <${githubUrl}/commit/${GIT_COMMIT}|${env.GIT_COMMIT[0..6]}>
*Image:* ${repository}:${env.GIT_COMMIT[0..6]}
"""
                    ]
                ]
            ])
        }
        failure {
            slackSend(channel: '#ci', blocks: [
                [
                    'type': 'section',
                    'text': [
                        'type': 'mrkdwn',
                        'text': """😵 *Failure* 😵
*Job:* ${JOB_NAME}
*Build:* <${currentBuild.absoluteUrl}|${BUILD_NUMBER}>
*Build duration:* ${currentBuild.durationString}
*Commit:* <${githubUrl}/commit/${GIT_COMMIT}|${env.GIT_COMMIT[0..6]}>
"""
                    ]
                ]
            ])
        }
    }
}
