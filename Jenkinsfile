pipeline {
    agent any

    triggers { pollSCM('*/5 * * * *') }

    environment {
        postman_api_key = credentials('postman-api-key')
        collection_id = '10825352-5fcf2dac-164c-4891-b738-126babc795ad'
    }
    
    stages {
        stage('Build') {
            steps {
                nodejs('default-lts') {
                    sh 'npm install'
                }
            }
        }
        
        stage('Test') {
            options {
                timeout(time: 10, unit: 'MINUTES')
            }

            steps {
                nodejs('default-lts') {
                    sh 'npm start &'
                }
                
                sh '''curl \\
                    -H "X-API-Key: ${postman_api_key}" \\
                    https://api.getpostman.com/collections/${collection_id} \\
                    > collection.json'''
                    
                sh '''docker run \\
                    --network host \\
                    -v $WORKSPACE:/etc/newman \\
                    postman/newman run \\
                    collection.json \\
                    --env-var "url=http://172.17.0.1:3000"
                    --reporters cli,junit \\
                    --reporter-junit-export newman/report.xml'''
            }
        }
    }
    
    post {
        always {
            junit 'newman/report.xml'
        }
    }
}