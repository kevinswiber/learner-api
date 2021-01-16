/* groovylint-disable CompileStatic,NestedBlockDepth */

String buildType = 'Build deployment'
pipeline {
    agent any

    parameters {
        RESTList(
            name: 'project',
            description: 'postman/learner-api/',
            restEndpoint: 'http://localhost:8080/job/postman/job/learner-api/api/json',
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
                    jobName = "postman/learner-api/${params.project}"
                    jobNumber = buildParameter('build')
                    echo "${jobNumber}"
                    echo "${jobNumber.getInterpolatedStrings()}"
                }
                copyArtifacts(
                    projectName: "${jobName}",
                    selector: buildParameter('build')
                )
            }
        }

        stage('load, tag, and push docker image') {
            when {
                triggeredBy 'UserIdCause'
            }

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

            agent {
                docker {
                    image 'kevinswiber/curl-jq'
                }
            }

            steps {
                withCredentials([string(credentialsId: 'postman-api-key', variable: 'POSTMAN_API_KEY')]) {
                    withEnv(["GIT_REF_NAME=${BRANCH_NAME}", 'TEST_TYPE=testsuite', 'GROUP=smoke']) {
                        sh './scripts/fetch-postman-assets.sh'
                    }
                }

                stash name: 'postman-assets', includes: 'postman_*.json'
            }
        }

        stage('run smoke tests') {
            when {
                triggeredBy 'UserIdCause'
            }

            agent {
                docker {
                    image 'postman/newman'
                    args '--entrypoint=""'
                }
            }

            steps {
                unstash 'postman-assets'
                sh '''newman run \\
                        --reporters cli,junit \\
                        --env-var url=https://learner-api-staging.zoinks.dev \\
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
            slackSend(channel: '#staging', color: 'good', message: "${buildType} successful ${currentBuild.absoluteUrl}")
        }
        failure {
            slackSend(channel: '#staging', color: 'danger', message: "${buildType} failure ${currentBuild.absoluteUrl}")
        }
    }
}
