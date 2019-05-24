# Docker File for Axis
# docker-compose build --build-arg SSH_PRIVATE_KEY="$(cat ~/.ssh/github_bot_key)" app
# docker run -e DJANGO_SETTINGS_MODULE=settings.dev_docker -p 8000:8000 -ti axis_app

FROM centos:7

ARG LABEL="test"
ARG BUILD_VERSION="0.2.12"
ARG BUILD_DATE="2019-03-19"
ARG APP_PASSWORD="password"
ARG BUG_FIX=0

ENV PIPENV_VENV_IN_PROJECT 1
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV FIX_BUG ${BUG_FIX}

MAINTAINER Pivotal Energy Solutions (steven@pivotal.energy)

LABEL com.pivotalenergy.${LABEL}.version=${BUILD_VERSION} \
      com.pivotalenergy.${LABEL}.release-date=${BUILD_DATE} \
      vendor="Pivotal Energy Solutions"

RUN curl -sL https://rpm.nodesource.com/setup_8.x | bash -

RUN yum -y -q update && \
    yum -y -q install epel-release && \
    yum -y -q install python-devel python-pip python-setuptools libxslt libxslt-devel \
        libxml2-devel mariadb-libs mariadb-devel openssl-devel libtiff libtiff-devel \
        libjpeg-turbo libjpeg-turbo-devel freetype freetype-devel lcms2 lcms2-devel libwebp \
        libwebp-devel tcl tcl-devel tk tk-devel java-1.8.0-openjdk pdftk libffi-devel \
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

RUN mkdir /data/app/${LABEL}

COPY stuff/core.py /usr/lib/python2.7/site-packages/pipenv/core.py

COPY --chown=app:app Pipfile* /data/app/${LABEL}/

RUN cd /data/app/${LABEL} && \
    rm -rf /data/app/.cache && \
    rm -rf /data/app/${LABEL}/.venv && \
    pipenv install --dev --sequential && \
#    pipenv install --dev --verbose && \
#    pipenv install --dev --sequential --verbose && \
#    pipenv sync --dev --sequential --verbose && \
    sudo yum -y -q remove mariadb-devel openssl-devel libxslt-devel \
        libxml2-devel libtiff-devel libjpeg-turbo-devel \
        freetype-devel tcl-devel tk-devel gcc  && \
    sudo yum -q clean all && \
    sudo rm -rf /var/cache/yum

WORKDIR /data/app/${LABEL}

RUN rm -rf /data/app/.ssh && \
    pipenv run freeze && \
    pipenv --support

RUN pipenv run python -c "import django_select2; print(dir(django_select2))"

CMD ["/bin/bash"]
