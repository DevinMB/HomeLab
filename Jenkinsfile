def convertLazyMapToHashMap(lazyMap) {
  lazyMap.collectEntries { key, value ->
    value = (value instanceof Map) ? convertLazyMapToHashMap(value) : value
    [(key): value]
  }
}

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
    imageName = "192.168.1.59:5000/${params.appname}:${BUILD_NUMBER}"
    SERVICE_NAME = "${params.appname}"
    CONTAINER_PORT = '8080'
    CREDENTIALS_ID = 'portainer-creds'
    bearerToken = ""
    container_id = ""
  }

  stages {
    stage('Build Image') {
      steps {
        script {
          dockerImage = docker.build registry + ":$BUILD_NUMBER"
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
              curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/json \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}'
            """, returnStdout: true).trim()
            def containers = convertLazyMapToHashMap(new groovy.json.JsonSlurper().parseText(containersJson))

            def container = containers.find { it.Image == imageName }
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
          withCredentials([usernamePassword(credentialsId: CREDENTIALS_ID, usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            def createContainerJson = sh(script: """
              curl -X POST http://portainer:9000/api/endpoints/2/docker/containers/create \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}' \
                -d '{ "Image": "${imageName}", "name": "${SERVICE_NAME}", "ExposedPorts": { "${CONTAINER_PORT}/tcp": {} }, "HostConfig": { "PortBindings": { "${CONTAINER_PORT}/tcp": [ { "HostPort": "${CONTAINER_PORT}" } ] } } }'
            """, returnStdout: true).trim()
            def createContainer = convertLazyMapToHashMap(new groovy.json.JsonSlurper().parseText(createContainerJson))
            container_id = createContainer.Id

            sh """
              curl -X POST http://portainer:9000/api/endpoints/2/docker/containers/${container_id}/start \
                -H 'accept: application/json' \
                -H 'Authorization: Bearer ${bearerToken}'
            """
          }
        }
      }
    }

    stage('Check Service Health') {
      steps {
        script {
          sleep 60

          def serviceInfo = sh(script: """
            curl -s -X GET http://portainer:9000/api/endpoints/2/docker/containers/${container_id}/json \
              -H 'accept: application/json' \
              -H 'Authorization: Bearer ${bearerToken}'
          """, returnStdout: true).trim()

          def jsonServiceInfo = convertLazyMapToHashMap(new groovy.json.JsonSlurper().parseText(serviceInfo))

          if (jsonServiceInfo.State.Status != "running") {
            error("Service is not healthy")
          }
        }
      }
    }
  }
}
