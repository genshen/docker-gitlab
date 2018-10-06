# https://github.com/docker-library/ruby/issues/228 / https://bugs.ruby-lang.org/issues/14754 3.8 not work for compiling ruby currently.
FROM debian:9.5-slim AS gitlab-base-builder
# docker build --rm -t genshen/gitlab-builder  .
# add denpendency libs and c/c++ compilers, git, ruby, go, node here.
LABEL maintainer="genshenchu@gmail.com" \
      description="base image for build gitlab images."

ARG RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz"
ARG GOLANG_DOWNLOAD_URL="https://dl.google.com/go/go1.11.linux-amd64.tar.gz"
ARG NODEJS_DOWNLOAD_URL="https://nodejs.org/dist/v8.12.0/node-v8.12.0-linux-x64.tar.xz"

## todo move some env to ARG
ENV BUILD_PROS=16 \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    RAILS_ENV=production

# https://docs.gitlab.com/ee/install/installation.html#1-packages-dependencies
# note: libre2-dev comes from community; checkinstall and pkg-config not installed, openssl is replace by libressl-dev.
# install ca-certificates apt-transport-https packages for downloading from https website(e.g. golang, nodejs).
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ca-certificates apt-transport-https \
    && sed -i 's#http://deb.debian.org#https://mirrors.ustc.edu.cn#g' /etc/apt/sources.list \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo git-core wget curl build-essential cmake \
    build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libre2-dev libreadline-dev \
    libncurses5-dev libffi-dev libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev \
    openssh-server checkinstall logrotate rsync python-docutils pkg-config \
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
    && echo "installing go." \
    && wget ${GOLANG_DOWNLOAD_URL} -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && echo "installing node." \
    && wget ${NODEJS_DOWNLOAD_URL} -O /tmp/node.tar.xz \
    && mkdir -p /usr/local/node \
    && tar -xf /tmp/node.tar.xz -C /usr/local/node --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && export PATH=/usr/local/node/bin:$PATH \
    && npm install --global yarn

## ac_cv_func_isnan=yes ac_cv_func_isinf=yes
# install charlock_holmes
## error: 'int isinf(double)' conflicts with a previous declaration RUBY_EXTERN int isinf(double);
## see: https://github.com/gliderlabs/docker-alpine/issues/261#issuecomment-285307909 and
## https://github.com/knu/ruby-unf_ext/issues/18.

## nodejs and ruby are installed in /usr/local

ENV GOROOT="/usr/local/go" \
    NODE_HOME="/usr/local/node" \
    YARN_BIN_GITLAB_USER="${GITLAB_HOME}/.yarn/bin"

# sudo resets PATH, along with many other environment variables, for security reasons.
# It doesn't matter what is set in /etc/profile, unless you run sudo -i.
# see https://serverfault.com/questions/11899/how-to-override-a-path-environment-variable-in-sudo
# so, we add PATH to file /etc/profile.
RUN echo "configure git user." \
    && adduser --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && sudo -HEu ${GITLAB_USER} git config --global core.autocrlf input \
    && sudo -HEu ${GITLAB_USER} git config --global gc.auto 0 \
    && sudo -HEu ${GITLAB_USER} git config --global repack.writeBitmaps true
    # deprecated: echo "\nexport PATH=/usr/local/go/bin:/usr/local/node/bin:~/.yarn/bin:\$PATH" >> /etc/profile \
