FROM debian:9.5-slim AS ruby-env

## the ruby is installed from source code.
# note: make sure the version of ruby is the same as in images gitlab-base-builder(Dockerfile in builder dir).
ARG RUBY_DOWNLOAD_RUL="https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz"

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

FROM debian:9.5-slim AS gitlab

LABEL maintainer="genshenchu@gmail.com" \
      description="gitlab images, which includes necessary gitlab components: gitlab-server, gitaly, gitlab-shell, gitlab-workhorse, gitlab-pages."

ENV GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_CONFIG_DIR="/etc/gitlab" \
    GITLAB_DATA_DIR="/gitlab/data" \
    GITLAB_CACHE_DIR="/tmp/gitlab" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    RAILS_ENV=production

## define gitlab components install directories.
ENV GIT_REPOSITORIES_DIR="${GITLAB_HOME}/repositories" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_DIR="${GITLAB_HOME}/gitlab" \
    GITALY_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_PAGES_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_SHELL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_DIR="${GITLAB_HOME}/gitlab-workhorse"

COPY --chown=root:root --from=ruby-env /usr/local/ruby /usr/local/ruby/

## create a user ans setup env.
RUN adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && apt-get clean && apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo nodejs yarn ca-certificates curl openssh-server git-core logrotate \
    libpq5 libicu57 libre2-3 \
    && export PATH=/usr/local/ruby/bin:$PATH \
    && gem install bundler --no-ri --no-rdoc \
    && ln -s /usr/local/ruby/bin/* /usr/local/bin/ \
    && ln -s /usr/local/ruby/include/* /usr/local/include/ \
    && ln -s /usr/local/ruby/lib/* /usr/local/lib/ 

# note: replace ${GITLAB_USER} as git.
COPY --chown=git:git --from=genshen/gitlab-shell-builder ${GITLAB_SHELL_DIR} ${GITLAB_SHELL_DIR}/
COPY --chown=git:git --from=genshen/gitlab-workhorse-builder ${GITLAB_WORKHORSE_DIR} ${GITLAB_WORKHORSE_DIR}/
COPY --chown=git:git --from=genshen/gitlab-pages-builder ${GITLAB_PAGES_DIR} ${GITLAB_PAGES_DIR}/
COPY --chown=git:git --from=genshen/gitlab-gitaly-builder ${GITALY_DIR} ${GITALY_DIR}/
COPY --chown=git:git --from=genshen/gitlab-builder ${GITLAB_DIR} ${GITLAB_DIR}/

COPY create.sh entrypoint.sh /usr/local/sbin/
RUN chmod +x /usr/local/sbin/create.sh /usr/local/sbin/entrypoint.sh \
    && bash /usr/local/sbin/create.sh \
    && rm /usr/local/sbin/create.sh

EXPOSE 22/tcp 80/tcp
VOLUME ["${GITLAB_DATA_DIR}", "${GITLAB_CONFIG_DIR}", "${GITLAB_LOG_DIR}"]

ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]

CMD ["start"]

## todo: backup schedule