/* groovylint-disable CompileStatic,NestedBlockDepth */

pipeline {
    agent any

    parameters {
        RESTList(
            name: 'project',
            description: 'postman/learner-api/',
            restEndpoint: 'https://jenkins.zoinks.dev/job/postman/job/learner-api/view/tags/api/json',
            credentialId: 'jenkins-api-key',
            mimeType: 'APPLICATION_JSON',
            valueExpression: '$.jobs..name',
            // filter: 'v[0-9]+\\..+'
        )
        buildSelector(name: 'build')
    }

    options {
        preserveStashes()
    }

    stages {
        stage('copy artifacts') {
            steps {
                copyArtifacts(
                    projectName: "postman/learner-api/${params.project}",
                    selector: buildParameter('build')
                )
            }
        }

        stage('load, tag, and push docker image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-container-registry',
                    usernameVariable: 'GH_USER',
                    passwordVariable: 'GH_TOKEN')]
                ) {
                    sh 'echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin'
                }

                script {
                    loadResult = sh(
                        returnStdout: true,
                        script: 'gunzip -c learner-api-*.tar.gz | docker load'
                    ).trim()
                    echo loadResult
                    imageName = loadResult[14..loadResult.size() - 1]
                    echo imageName
                    taggedImageName = imageName[0..imageName.lastIndexOf(':')] + 'staging'
                    echo taggedImageName
                }

                sh "docker rmi ${taggedImageName} || true"
                sh "docker tag ${imageName} ${taggedImageName}"
                sh "docker push ${taggedImageName}"
            }
        }
    }

    post {
        success {
            slackSend(channel: '#staging', color: 'good', message: "Build successful ${currentBuild.absoluteUrl}")
        }
        failure {
            slackSend(channel: '#staging', color: 'danger', message: "Build failure ${currentBuild.absoluteUrl}")
        }
    }
}
