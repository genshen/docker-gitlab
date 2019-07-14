###################################################
## Docker image of built ruby binary.
###################################################
FROM debian:buster-slim AS ruby-env

## the ruby is installed from source code.
# note: make sure the version of ruby is the same as in images gitlab-base-builder(Dockerfile in builder dir).
ARG RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.5.tar.gz"

RUN apt-get clean \
    && apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates apt-transport-https wget build-essential libssl-dev zlib1g-dev

RUN wget ${RUBY_DOWNLOAD_RUL} -O /tmp/ruby.tar.gz \
    && mkdir /tmp/ruby-src \
    && tar -xzf /tmp/ruby.tar.gz -C /tmp/ruby-src --strip-components=1 \
    && cd /tmp/ruby-src \
    && ./configure --disable-install-rdoc --prefix=/usr/local/ruby \
    && make -j $(nproc) && make install \
    && cd /tmp \
    && rm -rf /tmp/ruby-src /tmp/ruby.tar.gz

###################################################
## the final Docker image genshen/gitlab-ce:latest
###################################################
FROM debian:buster-slim AS gitlab

LABEL maintainer="genshenchu@gmail.com" \
      description="gitlab images, which includes necessary gitlab components: gitlab-server, gitaly, gitlab-shell, gitlab-workhorse."

ENV GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_CONFIG_DIR="/etc/gitlab" \
    GITLAB_DATA_DIR="/gitlab/data" \
    GITLAB_PAGES_DATA_DIR="/gitlab/gitlab-pages" \
    GITLAB_CACHE_DIR="/tmp/gitlab" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    RAILS_ENV=production

COPY --chown=root:root --from=ruby-env /usr/local/ruby /usr/local/ruby/
COPY --chown=root:root --from=gitlab-base-builder /usr/local/git /usr/local/git/

## create a user ans setup env.
# package postgresql-client is not installed.
# libxml2 is needed for db:migrate todo
# zip unzip is used for artifacts extract.
# "sid main" is used for installing postgresql-client-11
RUN adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && echo -e "\ndeb http://deb.debian.org/debian sid main" >> /etc/apt/sources.list \
    && apt-get clean \
    && apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo nodejs yarn ca-certificates curl openssh-server git-core logrotate zip unzip \
    libxml2 libpq5 libicu57 libre2-3  \
    postgresql-client-11  \
    && export PATH=/usr/local/ruby/bin:$PATH \
    && gem install bundler --version 1.17.3 --no-ri --no-rdoc \
    && mkdir -p /usr/local/bin /usr/local/include /usr/local/lib /usr/local/libexec /usr/local/share  \
    && ln -s /usr/local/ruby/bin/* /usr/local/bin/ \
    && ln -s /usr/local/ruby/include/* /usr/local/include/ \
    && ln -s /usr/local/ruby/lib/* /usr/local/lib/ \
    && ln -s /usr/local/git/bin/* /usr/local/bin/  \
    && ln -s /usr/local/git/libexec/* /usr/local/libexec/ \
    && ln -s /usr/local/git/share/* /usr/local/share/ 

# fixme: we use bundler version 1.17.3, not bundler 2, until "BUNDLED WITH" section in
# https://gitlab.com/gitlab-org/gitaly/blob/master/ruby/Gemfile.lock is updated.

## define gitlab components install directories.
ENV GIT_REPOSITORIES_DIR="${GITLAB_HOME}/repositories" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_DIR="${GITLAB_HOME}/gitlab" \
    GITALY_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_SHELL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_DIR="${GITLAB_HOME}/gitlab-workhorse" \
    WORKHORSE_LISTEN_NETWORK="tcp"

# note: replace ${GITLAB_USER} as git.
COPY --chown=git:git --from=gitlab-shell-builder ${GITLAB_SHELL_DIR} ${GITLAB_SHELL_DIR}/
COPY --chown=git:git --from=gitlab-workhorse-builder ${GITLAB_WORKHORSE_DIR} ${GITLAB_WORKHORSE_DIR}/
COPY --chown=git:git --from=gitlab-gitaly-builder ${GITALY_DIR} ${GITALY_DIR}/
COPY --chown=git:git --from=gitlab-builder ${GITLAB_DIR} ${GITLAB_DIR}/

# https://github.com/ochinchina/supervisord
# COPY --from=ochinchina/supervisord:latest /usr/local/bin/supervisord

COPY create.sh entrypoint.sh /usr/local/sbin/
RUN chmod +x /usr/local/sbin/create.sh /usr/local/sbin/entrypoint.sh \
    && bash /usr/local/sbin/create.sh \
    && rm /usr/local/sbin/create.sh

EXPOSE 22/tcp 8181/tcp
VOLUME ["${GITLAB_DATA_DIR}", "${GITLAB_CONFIG_DIR}", "${GITLAB_LOG_DIR}"]

ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]

CMD ["start"]

## todo: backup schedule