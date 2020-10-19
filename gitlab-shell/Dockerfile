FROM gitlab-base-builder AS gitlab-shell-builder
### docker build --rm -t gitlab-shell-builder .

## version number should better be the same in /home/git/gitlab/GITLAB_SHELL_VERSION
## see files in https://gitlab.com/gitlab-org/gitlab-foss for corresponding gitlab version.
ENV GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_SHELL_VERSION_TAG="v13.7.0"
ARG GITLAB_SHELL_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-shell/-/archive/${GITLAB_SHELL_VERSION_TAG}/gitlab-shell-${GITLAB_SHELL_VERSION_TAG}.tar.gz"

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## node is in /usr/local/node, and go is in /usr/local/go.
RUN mkdir -p ${GITLAB_SHELL_INSTALL_DIR} \
    && wget ${GITLAB_SHELL_DOWNLOAD_URL} -O /tmp/gitlab-shell.tar.gz \
    && tar -zxf /tmp/gitlab-shell.tar.gz -C ${GITLAB_SHELL_INSTALL_DIR} --strip-components=1 \
    && rm /tmp/gitlab-shell.tar.gz \
    && chown -R ${GITLAB_USER}: ${GITLAB_SHELL_INSTALL_DIR} \
    && cd ${GITLAB_SHELL_INSTALL_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " \
    export PATH=${GOROOT}/bin:$PATH; \
    cp config.yml.example config.yml; make setup" \
    && rm -rf ${GITLAB_HOME}/repositories go_build

# remove unused repositories directory created by gitlab-shell install
