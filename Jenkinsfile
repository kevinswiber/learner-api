/* groovylint-disable CompileStatic, NestedBlockDepth */

String dockerTag
String dockerSaveFile

pipeline {
    agent any

    options {
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
                withCredentials([usernamePassword(
                    credentialsId: 'github-container-registry',
                    usernameVariable: 'GH_USER',
                    passwordVariable: 'GH_TOKEN'
                )]) {
                    sh 'echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin'
                }

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
}
