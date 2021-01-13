/* groovylint-disable CompileStatic, NestedBlockDepth */

pipeline {
    agent none

    environment {
        GIT_REF_TYPE = sh(returnStdout: true, script: './ci/git-ref-type.sh').trim()
    }

    stages {
        stage('build and test') {
            agent {
                docker {
                    image 'node:lts-buster-slim'
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
                        sh 'npm run postman-tests'
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
