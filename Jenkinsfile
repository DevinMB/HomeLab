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
//       imageName = '192.168.1.59:5000/${params.appname}:${BUILD_NUMBER}'
      SERVICE_NAME = 'MyService'
      CONTAINER_PORT = '8080'
      HOST_PORT = '8080'
      CREDENTIALS_ID = 'portainer-creds' // You have to add Portainer credentials to Jenkins
  }

  stages {
    stage('Build Image') {
      steps {
        script {
          dockerImage = docker.build registry + ":$BUILD_NUMBER"
          imageName = '192.168.1.59:5000/${params.appname}:${BUILD_NUMBER}'
        }
      }
    }

    stage('Push Image') {
      steps {
        script {
          dockerImage.push()
        }
      }
    }

    stage('Deploy Image') {
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: CREDENTIALS_ID, usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            def token = sh(script: "curl -s -X POST http://portainer:9000/api/auth -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"username\": \"${USERNAME}\", \"password\": \"${PASSWORD}\"}'", returnStdout: true).trim()
            def jsonToken = readJSON text: token
            def bearerToken = jsonToken.jwt

            def payload = """
            {
              "Name": "${SERVICE_NAME}",
              "TaskTemplate": {
                "ContainerSpec": {
                  "Image": "${imageName}"
                },
                "RestartPolicy": {
                  "Condition": "on-failure",
                  "MaxAttempts": 3
                },
                "Placement": {},
                "Resources": {}
              },
              "Mode": {
                "Replicated": {
                  "Replicas": 1
                }
              },
              "EndpointSpec": {
                "Ports": [
                  {
                    "Protocol": "tcp",
                    "TargetPort": ${CONTAINER_PORT},
                    "PublishedPort": ${HOST_PORT}
                  }
                ]
              }
            }
            """

            sh """
              curl -X POST http://portainer:9000/api/endpoints/1/docker/services/create \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}' \
                -d '${payload}'
            """
          }
        }
      }
    }
  }
}
