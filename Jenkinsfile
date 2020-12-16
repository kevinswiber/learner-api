pipeline {
    agent any

    environment {
        postman_api_key = credentials('postman-api-key')
        collection_id = '10825352-5fcf2dac-164c-4891-b738-126babc795ad'
    }
    
    stages {
        stage('Test') {
            options {
                timeout(time: 10, unit: 'MINUTES')
            }

            steps {
                sh '''curl \\
                    -H "X-API-Key: ${postman_api_key}" \\
                    https://api.getpostman.com/collections/${collection_id} \\
                    > collection.json'''
                    
                sh 'docker-compose up -f docker-compose.test.yml --detach'
            }

            post {
                always {
                    sh 'docker-compose down -f docker-compose.test.yml'
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