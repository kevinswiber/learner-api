pipeline {
    agent any

    environment {
        postman_api_key = credentials('postman-api-key')
        postman_api_id = '0d28ef2e-2e71-4277-9084-dee6a015fbf7'
        postman_default_api_version = 'main'
        git_default_branch_name = 'main'
        api_server_port = '3000'
    }

    options {
        preserveStashes()
    }

    stages {
        stage('Setup test environment') {
            agent {
                docker {
                    image 'endeveit/docker-jq'
                    args '-v ${WORKSPACE}/ci:/etc/ci ' +
                        '-e POSTMAN_API_KEY=${postman_api_key} ' +
                        '-e BRANCH_NAME=${BRANCH_NAME} ' +
                        '-e DEFAULT_BRANCH=${git_default_branch_name} ' +
                        '-e DEFAULT_API_VERSION=${postman_default_api_version} ' +
                        '-e API_ID=${postman_api_id}'
                }
            }

            steps {
                sh '/etc/ci/fetch-postman-assets.sh'
                stash name: 'postman-assets', includes: 'postman_collection.json,postman_environment.json'
            }
        }

        stage('Launch API Server and Run Postman Tests') {
            agent any
            stages {
                stage('Launch API Server') {
                    steps {
                        sh 'docker network create learner-api-${BRANCH_NAME}-${BUILD_ID} || true'
                        sh '''docker run \\
                            --rm \\
                            -p :${api_server_port} \\
                            --name learner-api-server-${BRANCH_NAME}-${BUILD_ID} \\
                            --network learner-api-${BRANCH_NAME}-${BUILD_ID} \\
                            --detach \\
                            -v ${WORKSPACE}:/usr/src/app \\
                            --workdir /usr/src/app \\
                            node:lts-buster-slim \\
                            /bin/bash -c "npm install && npm start"'''
                    }
                }

                stage('Postman Tests') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }

                    agent {
                        docker {
                            image 'postman/newman'
                            args '-v ${WORKSPACE}:/etc/newman ' +
                                '--network learner-api-${BRANCH_NAME}-${BUILD_ID} ' +
                                '--entrypoint=""'
                        }
                    }

                    steps {
                        unstash 'postman-assets'
                        sh '/bin/sh -c "while ! wget -q --spider ' +
                            'http://learner-api-server-${BRANCH_NAME}-${BUILD_ID}:${api_server_port}; ' +
                            'do sleep 5; done"'
                        sh '''newman run \\
                            postman_collection.json \\
                            --environment postman_environment.json \\
                            --env-var url=http://learner-api-server-${BRANCH_NAME}-${BUILD_ID}:${api_server_port} \\
                            --reporters cli,junit \\
                            --reporter-junit-export newman/report.xml'''
                    }

                    post {
                        always {
                            junit 'newman/report.xml'
                        }
                    }
                }
            }

            post {
                always {
                    sh 'docker kill learner-api-server-${BRANCH_NAME}-${BUILD_ID} || true'
                    sh 'docker network rm learner-api-${BRANCH_NAME}-${BUILD_ID} || true'
                }
            }
        }
    }
}
