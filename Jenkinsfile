/* groovylint-disable CompileStatic,NestedBlockDepth */

pipeline {
    agent any

    parameters {
        RESTList(
            name: 'project',
            description: 'postman/learner-api/',
            restEndpoint: 'https://jenkins.zoinks.dev/job/postman/job/learner-api/api/json',
            credentialId: 'jenkins-api-key',
            mimeType: 'APPLICATION_JSON',
            valueExpression: '$.jobs..name',
        // filter: 'v[0-9]+\\..+'
        )
        buildSelector(name: 'build')
    }

    options {
        preserveStashes()
    }

    stages {
        stage('verify build parameters') {
            when {
                triggeredBy 'SCMTrigger'
            }

            steps {
                script {
                    currentBuild.result = 'ABORTED'
                }
                error 'Aborting early.  Possibly just updating the Jenkinsfile?'
            }
        }
        stage('copy artifacts') {
            steps {
                copyArtifacts(
                    projectName: "postman/learner-api/${params.project}",
                    selector: buildParameter('build')
                )
            }
        }

        stage('load, tag, and push docker image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-container-registry',
                    usernameVariable: 'GH_USER',
                    passwordVariable: 'GH_TOKEN')]
                ) {
                    sh 'echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin'
                }

                script {
                    loadResult = sh(
                        returnStdout: true,
                        script: 'gunzip -c learner-api-*.tar.gz | docker load'
                    ).trim().tokenize('\n')[0]
                    echo loadResult
                    imageName = loadResult[14..loadResult.size() - 1]
                    echo imageName
                    taggedImageName = imageName[0..imageName.lastIndexOf(':')] + 'staging'
                    echo taggedImageName
                }

                sh "docker rmi ${taggedImageName} || true"
                sh "docker tag ${imageName} ${taggedImageName}"
                sh "docker push ${taggedImageName}"
            }
        }

        stage('deploy to staging') {
            steps {
                echo 'deployed to staging'
            }
        }

        stage('generate files for smoke tests') {
            agent {
                docker {
                    image 'kevinswiber/curl-jq'
                }
            }

            steps {
                withCredentials([string(credentialsId: 'postman-api-key', variable: 'POSTMAN_API_KEY')]) {
                    withEnv(["GIT_REF_NAME=${BRANCH_NAME}", 'TEST_TYPE=testsuite', 'GROUP=smoke']) {
                        sh './ci/fetch-postman-assets.sh'
                    }
                }

                stash name: 'postman-assets', includes: 'postman_*.json'
            }
        }

        stage('run smoke tests') {
            agent {
                docker {
                    image 'postman/newman'
                    args '--entrypoint=""'
                }
            }

            steps {
                unstash 'postman-assets'
                sh '''newman run \\
                        --env-url=https://learner-api-staging.zoinks.dev \\
                        -e ./postman_environment.json \
                        ./postman_collection.json'''
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
            slackSend(channel: '#staging', color: 'good', message: "Build successful ${currentBuild.absoluteUrl}")
        }
        failure {
            slackSend(channel: '#staging', color: 'danger', message: "Build failure ${currentBuild.absoluteUrl}")
        }
    }
}
