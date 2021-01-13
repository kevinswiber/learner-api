/* groovylint-disable CompileStatic */

pipeline {
    agent {
        docker {
            image 'node:lts-buster-slim'
        }
    }

    environment {
        GIT_REF_TYPE = sh(returnStdout: true, script: './ci/git-ref-type.sh').trim()
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
