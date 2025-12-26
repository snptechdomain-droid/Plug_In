# Use official OpenJDK 17 image as the base
FROM eclipse-temurin:17-jdk-alpine

# Set the working directory
WORKDIR /app

# Copy the Maven wrapper/build files
# Note: Paths are relative to the build context, which is the root of the 'backend' folder in HF Spaces
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY src src

# Make mvnw executable
RUN chmod +x mvnw

# Build the application
# We skip tests to speed up build on HF Spaces
RUN ./mvnw clean package -DskipTests

# Expose port (HF Spaces expects 7860)
EXPOSE 7860

# Run the jar file
# Adjust the jar name pattern if needed, typically it's target/backend-0.0.1-SNAPSHOT.jar
CMD ["java", "-jar", "target/backend-0.0.1-SNAPSHOT.jar", "--server.port=7860"]
