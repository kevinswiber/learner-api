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
                    if ("${env.CHANGE_ID}" != '') {
                        env.BUILD_TRIGGER = 'pr'
                        env.VAL = "${env.CHANGE_ID}"
                    } else if ("${env.TAG_NAME}" != '') {
                        env.BUILD_TRIGGER = 'tag'
                        env.VAL = "${env.TAG_NAME}"
                    } else {
                        env.BUILD_TRIGGER = 'branch'
                    }
                }
                echo "${env.BUILD_TRIGGER}"
                echo "change id: ${env.CHANGE_ID}"
                echo "tag name: ${env.TAG_NAME}"
                echo "branch name: ${env.BRANCH_NAME}"
                echo "${env.VAL}"
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
