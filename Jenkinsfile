pipeline {
  agent {
    label 'docker-build-agent'
  }
  // parameters {
  //   string(name: 'appname', defaultValue: 'rpi-raw-input', description: 'rasberry pi input to raw topic')
  // }
  environment {
    APP_NAME = "data-streams-rpi-input-raw"
    CREDENTIALS_ID = "portainer-creds"
    NETWORK_NAME = "kafka_flappysnetwork"
    CONTAINER_PORT = "8080"
    registry = "192.168.1.59:5000/" + APP_NAME
    imageName = "192.168.1.59:5000/" + APP_NAME + ":${BUILD_NUMBER}"
    dockerImage = ""   
    bearerToken = ""
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
          withCredentials([usernamePassword(credentialsId: CREDENTIALS_ID, usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            def token = sh(script: "curl -s -X POST http://portainer:9000/api/auth -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"username\": \"${USERNAME}\", \"password\": \"${PASSWORD}\"}'", returnStdout: true).trim()
            def jsonToken = readJSON text: token 
            bearerToken = jsonToken.jwt
            
            def containersJson = sh(script: """
              curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/json?all=true \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}'
            """, returnStdout: true).trim()
            def containers = new groovy.json.JsonSlurperClassic().parseText(containersJson) 
//             echo containers.toString() // add this line to inspect the structure of containers
//             println containers
            def container = containers.find { it.Labels.AppName == APP_NAME }
            container_id = container?.Id

            if (container_id) {
              sh """
                curl -X DELETE http://portainer:9000/api/endpoints/2/docker/containers/${container_id} \
                  -H 'accept: application/json' \
                  -H 'Authorization: Bearer ${bearerToken}'
              """
            }
          }
        }
      }
    }

    stage('Create and Start New Container') {
      steps {
        script {
          
            def createContainerJson = sh(script: """
              curl -X POST http://portainer:9000/api/endpoints/2/docker/containers/create \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}' \
                -H 'Content-Type: application/json' \
                -d '{
                      "Name": "${params.appname}",
                      "Image": "${imageName}",
                      "Labels": {"AppName": "${params.appname}"},
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
                -H 'Authorization: Bearer ${bearerToken}'
            """
          
        }
      }
    }

    stage('Check Service Health') {
      steps {
        script {
          // Wait for a while before checking the service
          sleep 60  // adjust this to match your startup time

          // Call Docker API to get the service info
          def serviceInfo = sh(script: """
            curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/${container_id}/json \
              -H 'accept: application/json' \
              -H 'Authorization: Bearer ${bearerToken}'
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


