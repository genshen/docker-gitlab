###################################################
## the final Docker image genshen/gitlab-ce:latest
###################################################
FROM debian:buster-20200908-slim AS gitlab

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

# copy ruby with bundle
COPY --chown=root:root --from=gitlab-base-packages-builder /usr/local/ruby /usr/local/ruby/
COPY --chown=root:root --from=gitlab-base-packages-builder /usr/local/git /usr/local/git/

## create a user ans setup env.
# package postgresql-client is not installed.
# libxml2 is needed for db:migrate todo
# zip unzip is used for artifacts extract.
# "sid main" is used for installing postgresql-client-11
RUN adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && printf "\ndeb http://deb.debian.org/debian sid main" >> /etc/apt/sources.list \
    && apt-get clean \
    && apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo nodejs gnupg2 yarn ca-certificates curl openssh-server logrotate zip unzip \
    libxml2 libpq5 libicu63 libre2-5  \
    postgresql-client-12  \
    && export PATH=/usr/local/ruby/bin:$PATH \
    && mkdir -p /usr/local/bin /usr/local/include /usr/local/lib /usr/local/libexec /usr/local/share  \
    && ln -s /usr/local/ruby/bin/* /usr/local/bin/ \
    && ln -s /usr/local/ruby/include/* /usr/local/include/ \
    && ln -s /usr/local/ruby/lib/* /usr/local/lib/ \
    && ln -s /usr/local/git/bin/* /usr/bin/  \
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