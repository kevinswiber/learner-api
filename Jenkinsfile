/* groovylint-disable CompileStatic */

pipeline {
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
