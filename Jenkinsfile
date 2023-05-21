pipeline {
  agent {
    label 'docker-build-agent'
  }
  environment {
    APP_NAME = "data-streams-rpi-input-raw"
    CREDENTIALS_ID = "Portainer"
    NETWORK_NAME = "kafka_flappysnetwork"
    CONTAINER_PORT = "8080"
    registry = "192.168.1.59:5000/${APP_NAME}"
    imageName = "192.168.1.59:5000/${APP_NAME}:${BUILD_NUMBER}"
    dockerImage = ""
    container_id = ""
  }

  stages {
    stage('Build Image') {
      steps {
        script {
          dockerImage = docker.build registry + ":${BUILD_NUMBER}"
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
    stage('Retrieve Container ID and Delete Old Container') {
      steps {
        script {
          withCredentials([string(credentialsId: CREDENTIALS_ID, variable: 'BEARER_TOKEN')]) {
            def containersJson = sh(script: """
              curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/json?all=true \
                -H 'accept: application/json' \
                -H 'X-API-Key: ${BEARER_TOKEN}'
            """, returnStdout: true).trim()
            def containers = new groovy.json.JsonSlurperClassic().parseText(containersJson)
            def container = containers.find { it.Labels.AppName == APP_NAME }
            container_id = container?.Id

            if (container_id) {
              sh """
                curl -X DELETE http://portainer:9000/api/endpoints/2/docker/containers/${container_id} \
                  -H 'accept: application/json' \
                  -H 'X-API-Key: ${BEARER_TOKEN}'
              """
            }
          }
        }
      }
    }
    stage('Create and Start New Container') {
      steps {
        script {
          withCredentials([string(credentialsId: CREDENTIALS_ID, variable: 'BEARER_TOKEN')]) {
            def createContainerJson = sh(script: """
              curl -X POST http://portainer:9000/api/endpoints/2/docker/containers/create \
                -H 'accept: application/json' \
                -H 'X-API-Key: ${BEARER_TOKEN}' \
                -H 'Content-Type: application/json' \
                -d '{
                      "Name": "${APP_NAME}",
                      "Image": "${imageName}",
                      "Labels": {"AppName": "${APP_NAME}"},
                      "HostConfig": {
                        "Mounts": [
                          {
                            "Source": "web-data",
                            "Target": "/usr/src/app/data",
                            "ReadOnly": false,
                            "Type": "volume"
                          }
                        ],
                        "RestartPolicy": {
                          "Name": "on-failure",
                          "MaximumRetryCount": 10
                        }
                      },
                      "NetworkingConfig": {
                        "EndpointsConfig": {
                          "${NETWORK_NAME}": {}
                        }
                      }
                    }'
            """
            , returnStdout: true).trim()

            def createContainer = new groovy.json.JsonSlurperClassic().parseText(createContainerJson) 
            println createContainer
            container_id = createContainer.Id

            sh """
              curl -X POST http://portainer:9000/api/endpoints/2/docker/containers/${container_id}/start \
                -H 'accept: application/json' \
                -H 'X-API-Key: ${BEARER_TOKEN}'
            """
          }
        }
      }
    }
    stage('Check Service Health') {
      steps {
        script {
          withCredentials([string(credentialsId: CREDENTIALS_ID, variable: 'BEARER_TOKEN')]) {
          // Wait for a while before checking the service
          sleep 60

          def serviceInfo = sh(script: """
            curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/${container_id}/json \
              -H 'accept: application/json' \
              -H 'X-API-Key: ${BEARER_TOKEN}'
          """, returnStdout: true).trim()

          def jsonServiceInfo = new groovy.json.JsonSlurperClassic().parseText(serviceInfo) 

          // Check the service state
          if (jsonServiceInfo.State.Status != "running") {
            error("Service is not healthy")
          }
          }
        }
      }
    }
  }
}


