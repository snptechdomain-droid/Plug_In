# Use official OpenJDK 17 image as the base
FROM eclipse-temurin:17-jdk-alpine

# Set the working directory
WORKDIR /app

# Install Maven
RUN apk add --no-cache maven

# Copy the build files
COPY pom.xml .
COPY src src

# Build the application
RUN mvn clean package -DskipTests

# Expose port (HF Spaces expects 7860)
EXPOSE 7860

# Run the jar file
CMD ["java", "-jar", "target/backend-0.0.1-SNAPSHOT.jar", "--server.port=7860"]
