/* groovylint-disable CompileStatic, NestedBlockDepth */

pipeline {
    agent any

    environment {
        GIT_REF_TYPE = sh(returnStdout: true, script: './ci/git-ref-type.sh').trim()
    }

    stages {
        stage('setup') {
            steps {
                script {
                    try {
                        if ("${env.CHANGE_ID}" != '') {
                            env.BUILD_TRIGGER = 'pr'
                        }
                    } catch (MissingPropertyException _ex) {
                        try {
                            if ("${env.TAG_NAME}" != '') {
                                env.BUILD_TRIGGER = 'tag'
                            }
                        } catch (MissingPropertyException _ex2) {
                            env.BUILD_TRIGGER = 'branch'
                        }
                    }
                }
                echo "${env.BUILD_TRIGGER}"
            }
        }

        stage('build and test') {
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
    }
}
