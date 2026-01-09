#/bin/bash
docker build -t jenkins-controller:1.0 .
docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -e JENKINS_ADMIN_PASSWORD='Jenkins@123456' \
  -v jenkins_home:/var/jenkins_home \
  jenkins-controller:1.0
