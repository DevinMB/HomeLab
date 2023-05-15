pipeline {
    agent {
        label 'docker-build-agent'
    }
    parameters {
        string(name: 'appname', defaultValue: 'rpi-raw-input', description: 'rasberry pi input to raw topic')
    }
    environment {
        registry = "registry:5000/${params.appname}"
        dockerImage = ''
    }
    stages {
        stage('Building image') {
            steps{
                script {
                    dockerImage = docker.build registry + ":$BUILD_NUMBER"
                }
            }
        }
        stage('Pushing image') {
            steps{
                script {
                    dockerImage.push()
                }
            }
        }
        stage('Deploying image') {
            steps{
                script {
                    sh "docker service update --image ${registry}:${BUILD_NUMBER} ${params.appname}"
                }
            }
        }
    }
}
