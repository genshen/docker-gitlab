FROM debian:9.5-slim AS gitlab

LABEL maintainer="genshenchu@gmail.com" \
      description="gitlab images, which includes necessary gitlab components: gitlab-server, gitaly, gitlab-shell, gitlab-workhorse, gitlab-pages."

ENV GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_DATA_DIR="/gitlab/data" \
    GITLAB_CACHE_DIR="/tmp/gitlab" \
    GITLAB_LOG_DIR="/var/log/gitlab"

ENV GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_DIR="${GITLAB_HOME}/gitlab" \
    GITALY_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_PAGES_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_SHELL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_DIR="${GITLAB_HOME}/gitlab-workhorse"

## create a user.
RUN adduser --disabled-login --gecos 'GitLab' ${GITLAB_USER} \
    && passwd -d ${GITLAB_USER}

COPY --chown=${GITLAB_USER}: --from=genshen/gitlab-shell-builder ${GITLAB_SHELL_DIR}/* ${GITLAB_SHELL_DIR}/
COPY --chown=${GITLAB_USER}: --from=genshen/gitlab-workhorse-builder ${GITLAB_WORKHORSE_DIR}/* ${GITLAB_WORKHORSE_DIR}/
COPY --chown=${GITLAB_USER}: --from=genshen/gitlab-pages-builder ${GITLAB_PAGES_DIR}/* ${GITLAB_PAGES_DIR}/
COPY --chown=${GITLAB_USER}: --from=genshen/gitlab-gitaly-builder ${GITALY_DIR}/* ${GITALY_DIR}
COPY --chown=${GITLAB_USER}: --from=genshen/gitlab-builder ${GITLAB_DIR}/* ${GITLAB_DIR}/

COPY create.sh /tmp/create.sh
RUN chmod +x /tmp/create.sh && bash /tmp/create.sh

EXPOSE 22/tcp 80/tcp
VOLUME ["${GITLAB_DATA_DIR}", "${GITLAB_LOG_DIR}"]
