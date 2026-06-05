FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Jenkins 가 빌드한 jar 를 그대로 복사
COPY target/*.jar app.jar

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -q -O - http://localhost:8080/actuator/health | grep -q UP || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
