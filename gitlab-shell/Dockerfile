FROM genshen/gitlab-builder AS gitlab-shell-builder
### docker build --rm -t genshen/gitlab-shell-builder .

## version number should better be the same in /home/git/gitlab/GITLAB_SHELL_VERSION
## see files in https://gitlab.com/gitlab-org/gitlab-ce for corresponding gitlab version.
ENV GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_SHELL_VERSION_TAG="v5.9.4"
ARG GITLAB_SHELL_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-shell/-/archive/${GITLAB_SHELL_VERSION_TAG}/gitlab-shell-v${GITLAB_SHELL_VERSION_TAG}.tar.gz"

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## node ruby are in /usr/local, and go is in /usr/local/go.
RUN export PATH=${GOROOT}/bin:${YARN_BIN_GITLAB_USER}:$PATH \
    && mkdir -p ${GITLAB_SHELL_INSTALL_DIR} \
    && wget ${GITLAB_SHELL_DOWNLOAD_URL} -O /tmp/gitlab-shell.tar.gz \
    && tar -zxf /tmp/gitlab-shell.tar.gz -C ${GITLAB_SHELL_INSTALL_DIR} --strip-components=1 \
    && rm /tmp/gitlab-shell.tar.gz \
    && chown -R ${GITLAB_USER}: ${GITLAB_SHELL_INSTALL_DIR} \
    && cd ${GITLAB_SHELL_INSTALL_DIR} \
    && sudo -u ${GITLAB_USER} -H cp config.yml.example config.yml \
    && sudo -u ${GITLAB_USER} -H ./bin/install \
    && sudo -u ${GITLAB_USER} -H ./bin/compile \
    && rm -rf ${GITLAB_HOME}/repositories go_build

# remove unused repositories directory created by gitlab-shell install
