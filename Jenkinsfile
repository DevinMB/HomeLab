pipeline {
  agent {
    label 'docker-build-agent'
  }
  parameters {
    string(name: 'appname', defaultValue: 'rpi-raw-input', description: 'raspberry pi input to raw topic')
  }
  environment {
    registry = "192.168.1.59:5000/${params.appname}"
    dockerImage = ''
    imageName = "192.168.1.59:5000/${params.appname}:${BUILD_NUMBER}"
    SERVICE_NAME = "${params.appname}"
    CONTAINER_PORT = '8080'
    CREDENTIALS_ID = 'portainer-creds' // You have to add Portainer credentials to Jenkins
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

            // Create POST request for auth token
            def postUrl = new URL("http://portainer:9000/api/auth")
            def connection = postUrl.openConnection()
            connection.requestMethod = 'POST'
            connection.setRequestProperty('accept', 'application/json')
            connection.setRequestProperty('Content-Type', 'application/json')
            connection.doOutput = true

            // Send the POST data
            def postData = [username: USERNAME, password: PASSWORD]
            def writer = new OutputStreamWriter(connection.outputStream)
            writer.write(JsonOutput.toJson(postData))
            writer.flush()
            writer.close()

            // Read the response
            def authResponse = new groovy.json.JsonSlurperClassic().parseText(connection.content.text)
            def bearerToken = authResponse.jwt

            // Create the service spec JSON
            def payload = [
              Name: SERVICE_NAME,
              TaskTemplate: [
                ContainerSpec: [
                  Image: imageName
                ],
                RestartPolicy: [
                  Condition: "on-failure",
                  MaxAttempts: 3
                ],
                Placement: [:],
                Resources: [:]
              ],
              Mode: [
                Replicated: [
                  Replicas: 1
                ]
              ],
              EndpointSpec: [
                Ports: [
                  [
                    Protocol: "tcp",
                    TargetPort: CONTAINER_PORT
                  ]
                ]
              ]
            ]

            // Get the old service if it exists
            def getUrl = new URL("http://portainer:9000/api/endpoints/2/docker/services")
            connection = getUrl.openConnection()
            connection.setRequestMethod = 'GET'
            connection.setRequestProperty('accept', 'application/json')
            connection.setRequestProperty('Content-Type', 'application/json')
            connection.setRequestProperty('Authorization', "Bearer ${bearerToken}")

            // Parse the response JSON
            def services = new groovy.json.JsonSlurperClassic().parseText(connection.content.text)
            def oldService = services.find { it.Spec.Name == SERVICE_NAME }

            if (oldService) {
              // Delete the old service
              def deleteUrl = new URL("http://portainer:9000/api/endpoints/2/docker/services/${oldService.ID}")
              connection = deleteUrl.openConnection()
              connection.setRequestMethod = 'DELETE'
              connection.setRequestProperty('accept', 'application/json')
              connection.setRequestProperty('Content-Type', 'application/json')
              connection.setRequestProperty('Authorization', "Bearer ${bearerToken}")

              // Check the response code
              if (connection.responseCode != 200) {
                error("Failed to delete service: ${connection.responseMessage}")
              }

              // Wait for the service to be deleted
              sleep 60
            }

            // Deploy the new service
            postUrl = new URL("http://portainer:9000/api/endpoints/2/docker/services/create")
            connection = postUrl.openConnection()
            connection.requestMethod = 'POST'
            connection.setRequestProperty('accept', 'application/json')
            connection.setRequestProperty('Content-Type', 'application/json')
            connection.setRequestProperty('Authorization', "Bearer ${bearerToken}")
            connection.doOutput = true

            // Send the POST data
            writer = new OutputStreamWriter(connection.outputStream)
            writer.write(JsonOutput.toJson(payload))
            writer.flush()
            writer.close()

            // Check the response code
            if (connection.responseCode != 201) {
              error("Failed to create service: ${connection.responseMessage}")
            }
          }
        }
      }
    }

    stage('Check Service Health') {
      steps {
        script {
          // Wait for a while before checking the service
          sleep 60  // adjust this to match your startup time

          // Get the service info
          def getUrl = new URL("http://portainer:9000/api/endpoints/2/docker/services/${SERVICE_NAME}")
          connection = getUrl.openConnection()
          connection.setRequestMethod = 'GET'
          connection.setRequestProperty('accept', 'application/json')
          connection.setRequestProperty('Content-Type', 'application/json')
          connection.setRequestProperty('Authorization', "Bearer ${bearerToken}")

          // Parse the response JSON
          def serviceInfo = new groovy.json.JsonSlurperClassic().parseText(connection.content.text)

          // Check the service state
          if (serviceInfo.UpdateStatus.State != "completed") {
            error("Service is not healthy")
          }
        }
      }
    }
  }
}
