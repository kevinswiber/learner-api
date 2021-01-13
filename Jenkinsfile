/* groovylint-disable CompileStatic, NestedBlockDepth */

pipeline {
    agent any

    environment {
        GIT_REF_TYPE = sh(returnStdout: true, script: './ci/git-ref-type.sh').trim()
    }

    stages {
        stage('build and test') {
            agent {
                docker {
                    image 'node:alpine'
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
