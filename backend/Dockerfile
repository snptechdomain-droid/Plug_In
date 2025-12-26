# Build Stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ls -R /app/src && mvn clean package -DskipTests && ls -la /app/target

# Run Stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/backend.jar app.jar
EXPOSE 7860
ENTRYPOINT ["java", "-Xmx300m", "-Xss512k", "-jar", "app.jar"]
