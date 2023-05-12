# Use the official maven/Java 17 image to create a build artifact.
# This is based on Debian and sets the Maven version and the Java version.
FROM maven:3.8.3-openjdk-17 as builder

# Copy the pom.xml file to download dependencies
COPY pom.xml /usr/src/app/

# Download the dependencies in a separate layer will prevent unnecessary re-downloads when changing the code
RUN mvn -f /usr/src/app/pom.xml dependency:go-offline

# Copy your other files
COPY src /usr/src/app/src

# Build a release artifact.
RUN mvn -f /usr/src/app/pom.xml package

# Use the official openjdk image for a lean production stage of our multi-stage build.
# This is based on Debian and sets the Java version.
FROM openjdk:17-jdk-slim

# Copy the jar file from the builder stage
COPY --from=builder /usr/src/app/target/inputpoint-0.0.1-SNAPSHOT.jar /inputpoint.jar

# Expose the application's port
EXPOSE 8080

# Run the web service on container startup
CMD ["java", "-jar", "/inputpoint.jar"]
