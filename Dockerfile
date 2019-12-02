ARG JENKINS_VER=lts
ARG JENKINS_REGISTRY=jenkins/jenkins


FROM ${JENKINS_REGISTRY}:${JENKINS_VER}

# switch to root, let the entrypoint drop back to jenkins
USER root

# install prerequisite debian packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common \
     vim \
     wget \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# install gosu for a better su+exec command
ARG GOSU_VERSION=1.10
RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true 

# install docker
RUN curl -fsSL get.docker.com -o get-docker.sh \
 && sudo sh get-docker.sh \
 && sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
 && sudo chmod +x /usr/local/bin/docker-compose \
 && groupadd -r docker \
 && usermod -aG docker jenkins

# setup jenkins admin user and plugins
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
COPY admin.groovy /usr/share/jenkins/ref/init.groovy.d/security.groovy
COPY plugin.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

# entrypoint is used to update docker gid and revert back to jenkins user
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
HEALTHCHECK CMD curl -sSLf http://localhost:8080/login >/dev/null || exit 1

LABEL \
    org.label-schema.docker.cmd="docker run -d -p 8080:8080 -v \"/opt/jenkins_home:/var/jenkins_home\" -v /var/run/docker.sock:/var/run/docker.sock dhileepbalaji/jenkins-docker" \
    org.label-schema.description="Jenkins with docker support, Jenkins ${JENKINS_VER}, Docker ${DOCKER_VER}" \
    org.label-schema.name="dhileepbalaji/jenkins-docker" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="https://github.com/dhileepbalaji/jenkins-docker" \

