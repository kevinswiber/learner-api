pipeline {
    agent any

    environment {
        postman_api_key = credentials('postman-api-key')
        collection_id = '10825352-5fcf2dac-164c-4891-b738-126babc795ad'
    }
    
    stages {
        stage('Setup test environment') {
            steps {
                sh 'docker network create learner-api-${BUILD_ID} || true'
                sh '''curl \\
                    -H "X-API-Key: ${postman_api_key}" \\
                    https://api.getpostman.com/collections/${collection_id} \\
                    > collection.json'''
            }
        }

        stage('Test') {
            stages {
                stage('Start API server') {
                    agent {
                        docker {
                            image 'node:lts-buster-slim'
                            args '-v ${WORKSPACE}:/usr/src/app --network learner-api-${BUILD_ID}'
                        }
                    }

                    steps {
                        sh 'npm install'
                        //sh 'npm test'
                        sh 'npm start'
                    }
                }

                stage('Test API') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }

                    steps {
                        agent docker {
                            image 'postman/newman'
                            args '-v $WORKSPACE:/etc/newman --network learner-api-${BUILD_ID} --entrypoint=""'
                        }

                        steps {
                            sh '''newman run \\
                                --env-var url=http://learner-api-server:3000 \\
                                --reporters cli,junit \\
                                --reporter-junit-export newman/report.xml'''
                        }
                    }

                }
            }

            post {
                always {
                    sh 'docker network rm learner-api-${BUILD_ID} || true'
                }
            }
        }
    }

    
    post {
        always {
            junit 'newman/report.xml'
        }
    }
}