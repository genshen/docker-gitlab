# https://github.com/docker-library/ruby/issues/228 / https://bugs.ruby-lang.org/issues/14754 3.8 not work for compiling ruby currently.
FROM golang:1.10-alpine3.7 AS gitlab_builder
# docker build --rm -t genshen/gitlab-builder  .
# add denpendency libs and c/c++ compilers, git, ruby, go, node here.
LABEL maintainer="genshenchu@gmail.com" \
    description="base image for build gitlab images."

ARG RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz"
# ARG GOLANG_DOWNLOAD_URL="https://dl.google.com/go/go1.11.linux-amd64.tar.gz"
ARG NODEJS_DOWNLOAD_URL="https://nodejs.org/dist/v8.12.0/node-v8.12.0.tar.gz"

## todo move some env to ARG
ENV BUILD_PROS=16 \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    GITLAB_CACHE_DIR="/tmp/docker-gitlab" \
    RAILS_ENV=production

# https://docs.gitlab.com/ee/install/installation.html#1-packages-dependencies
# note: libre2-dev comes from community; checkinstall and pkg-config not installed, openssl is replace by libressl-dev.
# note: linux-headers is used for compiling ruby and nodejs (fix error of "linux/random.h: No such file or directory" in ruby.)
# note: python is used for compiling nodejs, which will be deleted after nodejs is compiled.
# install ca-certificates apt-transport-https packages for downloading from https website(e.g. golang, nodejs).
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache sudo git nodejs ca-certificates wget curl build-base python linux-headers \
    zlib-dev yaml-dev libressl-dev gdbm-dev libre2-dev readline-dev ncurses-dev openssh-server libxml2-dev libxslt-dev curl-dev icu-dev logrotate rsync py-docutils cmake \
    && echo "installing ruby." \
    && wget ${RUBY_DOWNLOAD_RUL} -O /tmp/ruby.tar.gz \
    && mkdir /tmp/ruby-src \
    && tar -xzf /tmp/ruby.tar.gz -C /tmp/ruby-src --strip-components=1 \
    && cd /tmp/ruby-src \
    && ac_cv_func_isnan=yes ac_cv_func_isinf=yes ./configure --disable-install-rdoc --prefix=/usr/local \
    && make -j ${BUILD_PROS} \
    && make install \
    && gem install bundler --no-ri --no-rdoc \
    && cd /tmp \
    && rm -rf /tmp/ruby-src /tmp/ruby.tar.gz \
    && echo "installing node." \
    && wget ${NODEJS_DOWNLOAD_URL} -O /tmp/node.tar.gz \
    && mkdir /tmp/node-src \
    && tar -xzf /tmp/node.tar.gz -C /tmp/node-src --strip-components=1 \
    && cd /tmp/node-src \
    && ./configure --prefix=/usr/local \
    && make -j ${BUILD_PROS} \
    && make install \
    && npm install --global yarn \
    && cd /tmp \
    && rm -rf /tmp/node-src /tmp/node.tar.gz \
    && apk del python

## ac_cv_func_isnan=yes ac_cv_func_isinf=yes
# install charlock_holmes
## error: 'int isinf(double)' conflicts with a previous declaration RUBY_EXTERN int isinf(double);
## see: https://github.com/gliderlabs/docker-alpine/issues/261#issuecomment-285307909 and
## https://github.com/knu/ruby-unf_ext/issues/18.

## nodejs and ruby are installed in /usr/local

ENV GOROOT="/usr/local/go" \
    YARN_BIN_GITLAB_USER="${GITLAB_HOME}/.yarn/bin" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime"

# Sudo resets PATH, along with many other environment variables, for security reasons.
# It doesn't matter what is set in /etc/profile, unless you run sudo -i.
# see https://serverfault.com/questions/11899/how-to-override-a-path-environment-variable-in-sudo
# so, we add PATH to file /etc/profile.
RUN echo "configure git user." \
    && rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && adduser -D ${GITLAB_USER} \
    && sudo -HEu ${GITLAB_USER} git config --global core.autocrlf input \
    && sudo -HEu ${GITLAB_USER} git config --global gc.auto 0 \
    && sudo -HEu ${GITLAB_USER} git config --global repack.writeBitmaps true
    # deprecated: echo "\nexport PATH=/usr/local/go/bin:/usr/local/node/bin:~/.yarn/bin:\$PATH" >> /etc/profile \
