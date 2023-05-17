pipeline {
    agent {
        label 'docker-build-agent'
    }
    parameters {
        string(name: 'appname', defaultValue: 'rpi-raw-input', description: 'rasberry pi input to raw topic')
    }
    environment {
        registry = "192.168.1.59:5000/${params.appname}"
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
                    withCredentials([usernamePassword(credentialsId: 'portainer-creds', passwordVariable: 'password', usernameVariable: 'username')]) {
                        def response = sh(script: "curl -s -X POST 'http://portainer:9000/api/auth' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"username\":\"$username\",\"password\":\"$password\"}'", returnStdout: true).trim()
                        def token = readJSON text: response
                        def jwt = token.jwt
                        // Now you can use the jwt token in subsequent curl command
                        sh "curl -X POST 'http://portainer:9000/api/endpoints/1/docker/services/create' -H 'accept: application/json' -H 'Authorization: Bearer $jwt' -d '{...}'"
                    }
                }
            }
        }
    }
}
