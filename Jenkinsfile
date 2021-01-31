/* groovylint-disable CompileStatic,NestedBlockDepth */

String buildType = 'Build deployment'
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
    - name: aws-cli
      image: amazon/aws-cli:2.1.22
      command:
        - cat
      tty: true
    - name: newman
      image: postman/newman
      command:
        - cat
      tty: true
'''
        }
    }

    parameters {
        RESTList(
            name: 'project',
            description: '/galaxy-pipelines/learner-api/${project}',
            restEndpoint: 'http://localhost:8080/job/galaxy-pipelines/job/learner-api/api/json',
            credentialId: 'jenkins-api-key',
            mimeType: 'APPLICATION_JSON',
            valueExpression: '$.jobs..name',
        )
        buildSelector(name: 'build')
    }

    options {
        preserveStashes()
    }

    stages {
        stage('verify build trigger') {
            when {
                anyOf {
                    triggeredBy cause: 'BranchEventCause'
                    triggeredBy 'SCMTrigger'
                }
            }

            steps {
                script {
                    buildType = 'Pipeline build'
                }
                echo 'Succeeding early.  Possibly just updating the Jenkinsfile?'
            }
        }

        stage('copy artifacts') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                script {
                    jobName = "/galaxy-pipelines/learner-api/${params.project}"
                    jobNumber = buildParameter('build')
                    echo "${jobNumber}"
                    echo "${params.build}"
                }

                copyArtifacts(
                    projectName: "${jobName}",
                    selector: buildParameter('build')
                )

                stash name: 'image-data', includes: 'image-name-with-digest'
            }
        }

        stage('load, tag, and push docker image') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                container('aws-cli') {
                    unstash 'image-data'
                    sh './scripts/tag-and-push-image.sh learner-api staging'
                }
            }
        }

        stage('deploy to staging') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                echo 'deployed to staging'
            }
        }

        stage('generate files for smoke tests') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                container('node-curl-jq') {
                    withCredentials([string(credentialsId: 'postman-api-key', variable: 'POSTMAN_API_KEY')]) {
                        withEnv(["GIT_REF_NAME=${BRANCH_NAME}", 'TEST_TYPE=testsuite', 'GROUP=smoke']) {
                            sh './scripts/fetch-postman-assets.sh'
                        }
                    }

                    stash name: 'postman-assets', includes: 'postman_*.json'
                }
            }
        }

        stage('run smoke tests') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                container('newman') {
                    unstash 'postman-assets'
                    sh '''newman run \\
                        --reporters cli,junit \\
                        --env-var url=https://learner-api-staging.zoinks.dev \\
                        -e ./postman_environment.json \
                        ./postman_collection.json'''
                }
            }

            post {
                always {
                    junit 'newman/*.xml'
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: '#staging', color: 'good', message: "${buildType} successful ${currentBuild.absoluteUrl}")
        }
        failure {
            slackSend(channel: '#staging', color: 'danger', message: "${buildType} failure ${currentBuild.absoluteUrl}")
        }
    }
}
