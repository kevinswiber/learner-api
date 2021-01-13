/* groovylint-disable CompileStatic, NestedBlockDepth */

pipeline {
    agent any

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

        stage('docker build and push') {
            steps {
                docker.withRegistry('https://ghcr.io', 'github-container-registry') {
                    image = docker.build("ghcr.io/kevinswiber/learner-api:${GIT_COMMIT.subString(0, 7)}")
                    image.push()
                }
            }
        }
    }
}
