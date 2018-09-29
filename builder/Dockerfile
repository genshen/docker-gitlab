FROM ubuntu:18.10 AS gitlab_builder
LABEL maintainer="genshenchu@gmail.com"

ENV BUILD_PROS=32 \
    RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz" \
    GOLANG_DOWNLOAD_URL="https://dl.google.com/go/go1.11.linux-amd64.tar.gz" \
    NODEJS_DOWNLOAD_URL="https://nodejs.org/dist/v8.12.0/node-v8.12.0-linux-x64.tar.xz" \
    GITLAB_VERSION=11.3.0 \
    GITLAB_SHELL_VERSION=8.3.3 \
    GITLAB_WORKHORSE_VERSION=6.1.0 \
    GITLAB_PAGES_VERSION=1.1.0 \
    GITALY_SERVER_VERSION=0.120.0 \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    GITLAB_CACHE_DIR="/tmp/docker-gitlab" \
    RAILS_ENV=production

## https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
COPY ubuntu18.10.sources.list /etc/apt/sources.list
# COPY script/build/install-gitlab.sh ${GITLAB_BUILD_DIR}/

#RUN chmod +x ${GITLAB_BUILD_DIR}/install-gitlab.sh \
#    && bash ${GITLAB_BUILD_DIR}/install-gitlab.sh

# https://docs.gitlab.com/ee/install/installation.html#1-packages-dependencies
# install ca-certificates apt-transport-https packages for downloading from https website.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y sudo wget git-core postfix ca-certificates apt-transport-https \
    build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libre2-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate rsync python-docutils pkg-config cmake \
    && echo "installing golang."\
    && wget ${GOLANG_DOWNLOAD_URL} -O /tmp/golang.tar.gz \
    && tar -C /usr/local -xzvf /tmp/golang.tar.gz \
    && rm /tmp/golang.tar.gz \
    && echo "installing ruby."\
    && wget ${RUBY_DOWNLOAD_RUL} -O /tmp/ruby.tar.gz \
    && mkdir /tmp/ruby-src \
    && tar -xzf /tmp/ruby.tar.gz -C /tmp/ruby-src --strip-components=1 \
    && cd /tmp/ruby-src \
    && ./configure \
    && make -j ${BUILD_PROS} \
    && make install \
    && gem install bundler --no-ri --no-rdoc \
    && cd /tmp \
    && rm -rf /tmp/ruby-src /tmp/ruby.tar.gz \
    && echo "installing node."\
    && wget ${NODEJS_DOWNLOAD_URL} -O /tmp/node.tar.xz \
    && mkdir /usr/local/node \
    && tar -xf /tmp/node.tar.xz -C /usr/local/node --strip-components=1 \
    && export PATH=/usr/local/node/bin:~/.yarn/bin:$PATH \
    && npm install --global yarn \
    && rm /tmp/node.tar.xz

ENV GOROOT="/usr/local/go" \
    GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="${GITLAB_CACHE_DIR}/build" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime"

RUN echo "configure git user." \
    && rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && echo "\nexport PATH=/usr/local/go/bin:/usr/local/node/bin:~/.yarn/bin:\$PATH" >> ${GITLAB_HOME}/.profile \
    && sudo -HEu ${GITLAB_USER} git config --global core.autocrlf input \
    && sudo -HEu ${GITLAB_USER} git config --global gc.auto 0 \
    && sudo -HEu ${GITLAB_USER} git config --global repack.writeBitmaps true
