# Jenkins LTS (khuyến nghị dùng LTS và pin version để ổn định)
FROM jenkins/jenkins:lts-jdk17

USER root

# Cài các package tối thiểu (tuỳ nhu cầu). Git + curl rất phổ biến.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Copy danh sách plugins và cài bằng jenkins-plugin-cli (có sẵn trong image Jenkins chính thức)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# Jenkins Configuration as Code (JCasC)
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc.yaml
COPY casc.yaml /usr/share/jenkins/ref/casc.yaml


# (Tuỳ chọn) Tắt setup wizard để bootstrap tự động
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Không chạy Jenkins dưới root
USER jenkins

# Expose port web + inbound agent (inbound port chỉ cần nếu bạn dùng inbound TCP; nếu dùng WebSocket thì có thể không cần)
EXPOSE 8080 50000
