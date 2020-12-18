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
                    https://api.getpostman.com/collections/${collection_id} > ${WORKSPACE}/collection.json'''
                stash name: 'collection', includes: 'collection.json'
            }
        }

        stage('Run API server') {
            steps {
                sh '''docker run \\
                    --rm \\
                    -p 3000:3000 \\
                    --name learner-api-server-${BUILD_ID} \\
                    --network learner-api-${BUILD_ID} \\
                    --detach \\
                    -v ${WORKSPACE}:/usr/src/app \\
                    --workdir /usr/src/app \\
                    node:lts-buster-slim \\
                    /bin/bash -c "npm install && npm start"'''          
            }
        }

        stage('Test API') {
            options {
                timeout(time: 10, unit: 'MINUTES')
            }

            agent {
                docker {
                    image 'postman/newman'
                    args '-v ${WORKSPACE}:/etc/newman --network learner-api-${BUILD_ID} --entrypoint=""'
                }
            }

            steps {
                unstash 'collection'
                //sh '''/bin/sh -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' learner-api-server-${BUILD_ID}:3000)" != "200" ]]; do sleep 5; done'; '''
                sh '''newman run \\
                    collection.json \\
                    --env-var url=http://learner-api-server-${BUILD_ID}:3000 \\
                    --reporters cli,junit \\
                    --reporter-junit-export newman/report.xml'''
                
                /*sh '''docker run \\
                    -v ${WORKSPACE}:/etc/newman \\
                    --rm \\
                    --network learner-api-${BUILD_ID} \\
                    -v ${WORKSPACE}:/etc/newman \\
                    postman/newman \\
                    run collection.json \\
                    --env-var url=http://learner-api-server:3000 \\
                    --reporters cli,junit \\
                    --reporter-junit-export newman/report.xml'''*/
            }

            post {
                always {
                    sh 'docker kill learner-api-server-${BUILD_ID} || true'
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