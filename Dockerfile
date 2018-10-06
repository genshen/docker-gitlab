FROM debian:9.5-slim AS gitlab

LABEL maintainer="genshenchu@gmail.com" \
      description="gitlab images, which includes necessary gitlab components: gitlab-server, gitaly, gitlab-shell, gitlab-workhorse, gitlab-pages."

ENV GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_CONFIG_DIR="/etc/gitlab/" \
    GITLAB_DATA_DIR="/gitlab/data" \
    GITLAB_CACHE_DIR="/tmp/gitlab" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    RAILS_ENV=production

## define gitlab components install directories.
ENV GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_DIR="${GITLAB_HOME}/gitlab" \
    GITALY_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_PAGES_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_SHELL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_DIR="${GITLAB_HOME}/gitlab-workhorse"

## create a user ans setup env.
RUN adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER} \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo ca-certificates curl openssh-server git-core ruby logrotate \
    && gem install bundler --no-ri --no-rdoc

# note: replace ${GITLAB_USER} as git.
COPY --chown=git:git --from=genshen/gitlab-shell-builder ${GITLAB_SHELL_DIR} ${GITLAB_SHELL_DIR}/
COPY --chown=git:git --from=genshen/gitlab-workhorse-builder ${GITLAB_WORKHORSE_DIR} ${GITLAB_WORKHORSE_DIR}/
COPY --chown=git:git --from=genshen/gitlab-pages-builder ${GITLAB_PAGES_DIR} ${GITLAB_PAGES_DIR}/
COPY --chown=git:git --from=genshen/gitlab-gitaly-builder ${GITALY_DIR} ${GITALY_DIR}/
COPY --chown=git:git --from=genshen/gitlab-builder ${GITLAB_DIR} ${GITLAB_DIR}/

COPY create.sh /tmp/create.sh
RUN chmod +x /tmp/create.sh && bash /tmp/create.sh && rm /tmp/create.sh

EXPOSE 22/tcp 80/tcp
VOLUME ["${GITLAB_DATA_DIR}", "${GITLAB_CONFIG_DIR}", "${GITLAB_LOG_DIR}"]
