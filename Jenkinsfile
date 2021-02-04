/* groovylint-disable CompileStatic, DuplicateStringLiteral, NestedBlockDepth */

String buildType = 'Build deployment'
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-kubectl
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
    - name: kubectl
      image: bitnami/kubectl
      command:
        - cat
      tty: true
      securityContext:
        runAsUser: 1000
'''
        }
    }

    parameters {
        RESTList(
            name: 'project',
            /* groovylint-disable-next-line GStringExpressionWithinString */
            description: '/learner-api/${project}',
            restEndpoint: 'http://localhost:8080/job/learner-api/api/json',
            credentialId: 'jenkins-api-key',
            mimeType: 'APPLICATION_JSON',
            valueExpression: '$.jobs..name',
            filter: '^(?!deploy-).*'
        )
        buildSelector(name: 'build')
    }

    options {
        preserveStashes()
    }

    stages {
        stage('pipeline build or deployment?') {
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

        stage('tag and push docker image') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                copyArtifacts(
                    projectName: "/learner-api/${params.project}",
                    selector: buildParameter('build')
                )

                stash name: 'image-data', includes: 'image-name-with-digest'
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
                container('kubectl') {
                    sh "kubectl apply -n default -f ${WORKSPACE}/deploy"
                }
                echo 'deployed to staging'
            }
        }

        stage('run smoke tests') {
            when {
                triggeredBy 'UserIdCause'
            }

            steps {
                container('node-curl-jq') {
                    withCredentials(
                        [string(credentialsId: 'learner-api-postman-api-key', variable: 'POSTMAN_API_KEY')]
                    ) {
                        withEnv(["GIT_REF_NAME=${BRANCH_NAME}", 'TEST_TYPE=testsuite', 'GROUP=smoke']) {
                            sh './scripts/fetch-postman-assets.sh'
                        }
                    }

                    stash name: 'postman-assets', includes: 'postman_*.json'
                }

                container('newman') {
                    dir("${JENKINS_AGENT_WORKDIR}") {
                        unstash 'postman-assets'
                    }

                    sh '''newman run \\
                        --reporters cli,junit,json \\
                        --env-var url=http://learner-api-staging.default \\
                        -e ./postman_environment.json \
                        ./postman_collection.json'''
                }
            }

            post {
                always {
                    junit 'newman/*.xml'
                    archiveArtifacts 'newman/*.json'
                }
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#staging',
                color: 'good',
                message: "${buildType} successful ${currentBuild.absoluteUrl}"
            )
        }
        failure {
            slackSend(
                channel: '#staging',
                color: 'danger',
                message: "${buildType} failure ${currentBuild.absoluteUrl}"
            )
        }
    }
}
