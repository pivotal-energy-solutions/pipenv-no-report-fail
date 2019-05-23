# Docker File for Axis
# docker-compose build --build-arg SSH_PRIVATE_KEY="$(cat ~/.ssh/github_bot_key)" app
# docker run -e DJANGO_SETTINGS_MODULE=settings.dev_docker -p 8000:8000 -ti axis_app

FROM centos:7

ARG SSH_PRIVATE_KEY

ARG LABEL="test"
ARG BUILD_VERSION="0.2.1"
ARG BUILD_DATE="2019-03-19"
ARG APP_PASSWORD="password"

ENV PIPENV_VENV_IN_PROJECT 1
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

MAINTAINER Pivotal Energy Solutions (steven@pivotal.energy)

LABEL com.pivotalenergy.${LABEL}.version=${BUILD_VERSION} \
      com.pivotalenergy.${LABEL}.release-date=${BUILD_DATE} \
      vendor="Pivotal Energy Solutions"

RUN curl -sL https://rpm.nodesource.com/setup_8.x | bash -

RUN yum -y update && \
    yum -y install epel-release && \
    yum -y install python-devel python-pip python-setuptools libxslt libxslt-devel libxml2 \
        libxml2-devel mariadb-libs mariadb-devel openssl-libs openssl-devel libtiff libtiff-devel \
        libjpeg-turbo libjpeg-turbo-devel freetype freetype-devel lcms2 lcms2-devel libwebp \
        libwebp-devel tcl tcl-devel tk tk-devel java-1.8.0-openjdk pdftk libffi libffi-devel \
        gcc sudo git nmap-ncat which nodejs && \
    yum clean all && rm -rf /var/cache/yum && \
    mkdir -p /data && \
    mkdir -p /var/run/uwsgi/ && \
    mkdir -p /var/log/uwsgi/ && \
    mkdir -p /var/log/django/ && \
    groupadd app && \
    useradd -rm -d /data/app -s /bin/bash -g app -u 1000 -p ${APP_PASSWORD} app && \
    chown app:app /var/run/uwsgi && \
    chown app:app /var/log/uwsgi  && \
    chown app:app /var/log/django  && \
    echo "app ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/91-app && \
    chmod 0440 /etc/sudoers.d/91-app && \
    echo -e "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    pip install -qq --upgrade pip && \
    pip install -qq pipenv

WORKDIR /data/app

USER app

# Authorize SSH Host and prep for gettting private repos
RUN mkdir -p /data/app/.ssh && \
    chmod 0700 /data/app/.ssh && \
    ssh-keyscan github.com > /data/app/.ssh/known_hosts && \
    echo "${SSH_PRIVATE_KEY}" > /data/app/.ssh/id_rsa && \
    git config --global user.name "${LABEL} Docker" && \
    git config --global url."git@github.com:".insteadOf "https://github.com/" && \
    chmod 600 /data/app/.ssh/id_rsa && \
    mkdir /data/app/${LABEL}

COPY --chown=app:app Pipfile* /data/app/${LABEL}/

RUN cd /data/app/${LABEL} && \
    rm -rf /data/app/${LABEL}/.venv && \
    pipenv sync --dev --sequential --verbose && \
    sudo yum -y remove mariadb-devel openssl-devel libxslt-devel \
        libxml2-devel libtiff-devel libjpeg-turbo-devel \
        freetype-devel tcl-devel tk-devel gcc  && \
    sudo yum clean all && \
    sudo rm -rf /var/cache/yum

WORKDIR /data/app/${LABEL}

RUN rm -rf /data/app/.ssh && \
    pipenv run freeze

ENTRYPOINT ["/data/app/axis/axis/aws/docker/app/docker-entrypoint.sh"]
