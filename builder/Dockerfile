# https://github.com/docker-library/ruby/issues/228 / https://bugs.ruby-lang.org/issues/14754 3.8 not work for compiling ruby currently.
FROM debian:buster-slim AS gitlab-base-packages-builder
# docker build --rm -t gitlab-builder  .
# add denpendency libs and c/c++ compilers, git, ruby, go, node here.
LABEL maintainer="genshenchu@gmail.com" \
      description="base image for build gitlab images."

ARG RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.6/ruby-2.6.3.tar.gz"
ARG GOLANG_DOWNLOAD_URL="https://dl.google.com/go/go1.12.9.linux-amd64.tar.gz"
ARG NODEJS_DOWNLOAD_URL="https://nodejs.org/dist/v10.16.3/node-v10.16.3-linux-x64.tar.xz"
ARG LIBPCRE_DOWNLOAD_URL="https://ftp.pcre.org/pub/pcre/pcre2-10.33.tar.gz"
ARG GIT_DOWNLOAD_URL="https://www.kernel.org/pub/software/scm/git/git-2.23.0.tar.gz"

# https://docs.gitlab.com/ee/install/installation.html#1-packages-dependencies
# note: libre2-dev comes from community; openssl is replace by libressl-dev.
# libexpat1-dev gettext libz-dev is used for git building.
# install ca-certificates apt-transport-https packages for downloading from https website(e.g. golang, nodejs).
RUN apt-get clean && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ca-certificates apt-transport-https \
#    && sed -i 's#http://deb.debian.org#https://mirrors.ustc.edu.cn#g' /etc/apt/sources.list \ # use mirror
    && apt-get clean && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo wget curl build-essential cmake \
    libexpat1-dev gettext libz-dev \
    zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libre2-dev libreadline-dev \
    libncurses5-dev libffi-dev libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev \
    openssh-server logrotate rsync python-docutils pkg-config

# fixme: checkinstall is not installed, due to error "Unable to locate package checkinstall".

RUN echo "installing ruby." \
    && wget ${RUBY_DOWNLOAD_RUL} -O /tmp/ruby.tar.gz \
    && mkdir /tmp/ruby-src \
    && tar -xzf /tmp/ruby.tar.gz -C /tmp/ruby-src --strip-components=1 \
    && cd /tmp/ruby-src \
    && ./configure --disable-install-rdoc --prefix=/usr/local/ruby \
    && make -j $(nproc) \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/ruby-src /tmp/ruby.tar.gz \
    && ln -s /usr/local/ruby/bin/* /usr/local/bin/ \
    && ln -s /usr/local/ruby/include/* /usr/local/include/ \
    && ln -s /usr/local/ruby/lib/* /usr/local/lib/ \
    && gem install bundler --version 1.17.3 --no-document

# fixme: we use bundler version 1.17.3, not bundler 2, until "BUNDLED WITH" section in
# https://gitlab.com/gitlab-org/gitaly/blob/master/ruby/Gemfile.lock is updated.


RUN echo "installing go." \
    && wget ${GOLANG_DOWNLOAD_URL} -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

RUN echo "installing node." \
    && wget ${NODEJS_DOWNLOAD_URL} -O /tmp/node.tar.xz \
    && mkdir -p /usr/local/node \
    && tar -xf /tmp/node.tar.xz -C /usr/local/node --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && export PATH=/usr/local/node/bin:$PATH \
    && npm install --global yarn

RUN echo "installing libpcre dependency for git." \
    && cd /tmp \
    && wget ${LIBPCRE_DOWNLOAD_URL} -O pcre2.tar.gz \
    && mkdir -p /tmp/pcre2-src  \
    && tar -zxf pcre2.tar.gz -C /tmp/pcre2-src --strip-components=1 \
    && cd pcre2-src \
    && chmod +x configure \
    && ./configure --prefix=/usr/local/ --enable-jit --enable-shared=no --enable-static=yes \
    && make -j $(nproc) && make install \
    && rm -rf /tmp/pcre2.tar.gz /tmp/pcre2-src

RUN echo "installing git." \
    && cd /tmp \ 
    && wget ${GIT_DOWNLOAD_URL} -O git.tar.gz  \
    && mkdir -p /tmp/git-src  \
    && tar -zxf git.tar.gz -C /tmp/git-src --strip-components=1 \
    && cd git-src \
    && chmod +x configure \
    && ./configure --with-libpcre --prefix=/usr/local/git \
    && make all -j $(nproc) && make install \
    && ln -s /usr/local/git/bin/* /usr/bin/  \
    && rm -rf /tmp/git.tar.gz /tmp/git-src


## ac_cv_func_isnan=yes ac_cv_func_isinf=yes
# install charlock_holmes
## error: 'int isinf(double)' conflicts with a previous declaration RUBY_EXTERN int isinf(double);
## see: https://github.com/gliderlabs/docker-alpine/issues/261#issuecomment-285307909 and
## https://github.com/knu/ruby-unf_ext/issues/18.

FROM gitlab-base-packages-builder AS gitlab-base-builder

## todo move some env to ARG
ENV GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    RAILS_ENV=production

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
