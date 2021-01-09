/* groovylint-disable CompileStatic,NestedBlockDepth */

String dockerName = "${BUILD_TAG}".replaceAll('[^a-zA-Z0-9]', '-')
String postmanAssetsID = 'postman-assets'
String apiServerPort = '3000'

pipeline {
    agent any

    environment {
        GIT_REF_TYPE = sh(returnStdout: true, script: './ci/git-ref-type.sh'.trim())
    }

    options {
        preserveStashes()
    }

    stages {
        stage('Setup test environment') {
            agent {
                docker {
                    image 'kevinswiber/curl-jq'
                    args "-v ${WORKSPACE}/ci:/etc/ci"
                }
            }

            steps {
                withCredentials([string(credentialsId: 'postman-api-key', variable: 'POSTMAN_API_KEY')]) {
                    sh '/etc/ci/fetch-postman-assets.sh'
                }
                stash name: "${postmanAssetsID}", includes: 'postman_collection.json,postman_environment.json'
            }
        }

        stage('Launch API Server and Run Postman Tests') {
            agent any
            stages {
                stage('Launch API Server') {
                    steps {
                        sh "docker network create ${dockerName} || true"
                        sh """docker run \\
                            --rm \\
                            -p :${apiServerPort} \\
                            --name ${dockerName} \\
                            --network ${dockerName} \\
                            --network-alias api \\
                            --detach \\
                            -v ${WORKSPACE}:/usr/src/app \\
                            --workdir /usr/src/app \\
                            node:lts-buster-slim \\
                            /bin/bash -c \"npm install && npm start\""""
                    }
                }

                stage('Postman Tests') {
                    options {
                        timeout(time: 10, unit: 'MINUTES')
                    }

                    agent {
                        docker {
                            image 'postman/newman'
                            args "-v ${WORKSPACE}:/etc/newman --network ${dockerName} --entrypoint=''"
                            reuseNode true
                        }
                    }

                    steps {
                        unstash "${postmanAssetsID}"
                        sh "/bin/sh -c \"while ! wget -q --spider http://api:${apiServerPort}; do sleep 5; done\""
                        sh """newman run \\
                            postman_collection.json \\
                            --environment postman_environment.json \\
                            --env-var url=http://api:${apiServerPort} \\
                            --reporters cli,junit \\
                            --reporter-junit-export newman/report.xml"""
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
                    sh "docker kill ${dockerName} || true"
                    sh "docker network rm ${dockerName} || true"
                }
            }
        }
    }
}
