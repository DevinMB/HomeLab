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
      CREDENTIALS_ID = 'portainer-creds' // You have to add Portainer credentials to Jenkins
      bearerToken = ""
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

    stage('Deploy Image') {
      steps {
        script {

         withCredentials([usernamePassword(credentialsId: CREDENTIALS_ID, usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
        def token = sh(script: "curl -s -X POST http://portainer:9000/api/auth -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"username\": \"${USERNAME}\", \"password\": \"${PASSWORD}\"}'", returnStdout: true).trim()
        def jsonToken = readJSON text: token
        bearerToken = jsonToken.jwt

        // Checking if service already exists
        def serviceCheck = sh(script: """
          curl -s -X GET http://portainer:9000/api/endpoints/2/docker/services/${SERVICE_NAME} \
            -H 'accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer ${bearerToken}'
        """, returnStdout: true).trim()

        def jsonServiceCheck = readJSON text: serviceCheck

        if (jsonServiceCheck.message != 'rpc error: code = NotFound desc = service ${SERVICE_NAME} not found') {
          // Service exists, update it
          sh """
            curl -X POST http://portainer:9000/api/endpoints/2/docker/services/${SERVICE_NAME}/update \
              -H 'accept: application/json' \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer ${bearerToken}' \
              -d '${payload}'
          """
        } else {
          // Service does not exist, create it
          sh """
            curl -X POST http://portainer:9000/api/endpoints/2/docker/services/create \
              -H 'accept: application/json' \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer ${bearerToken}' \
              -d '${payload}'
          """
          }
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
            curl -s -X GET http://portainer:9000/api/endpoints/2/docker/services/${SERVICE_NAME} \
              -H 'accept: application/json' \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer ${bearerToken}'
          """, returnStdout: true).trim()

          def jsonServiceInfo = readJSON text: serviceInfo

          // Check the service state
          if (jsonServiceInfo.UpdateStatus.State != "completed") {
            error("Service is not healthy")
          }
        }
      }
    }

  }
}
