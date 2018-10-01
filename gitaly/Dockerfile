FROM genshen/gitlab-builder AS gitlab-gitaly-builder
### docker build --rm -t genshen/gitlab-gitaly-builder .

ENV  GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
     GITLAB_GITALY_VERSION_TAG="v0.81.0"
ARG  GITLAB_GITALY_BUILD_DIR="${GITLAB_HOME}/gitlab-gitaly-builder"
ARG  GITLAB_GITALY_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitaly.git"

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## node and ruby are in /usr/local, and go is in /usr/local/go.
RUN export PATH=${GOROOT}/bin:${YARN_BIN_GITLAB_USER}:$PATH \
    && git clone -q -b ${GITLAB_GITALY_VERSION_TAG} --depth 1 ${GITLAB_GITALY_DOWNLOAD_URL} ${GITLAB_GITALY_BUILD_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_GITALY_BUILD_DIR} \
    && cd ${GITLAB_GITALY_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H make install PREFIX=${GITLAB_GITALY_INSTALL_DIR} \
    && mkdir -p ${GITLAB_GITALY_INSTALL_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_GITALY_INSTALL_DIR} \
    && rm -rf ${GITLAB_GITALY_BUILD_DIR}

## the binary is located in ${GITLAB_GITALY_INSTALL_DIR}

# && cp -a ${GITLAB_GITALY_BUILD_DIR}/ruby ${GITLAB_GITALY_INSTALL_DIR} \
# && cp -a ${GITLAB_GITALY_BUILD_DIR}/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml \
# && rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/**/cache \
# && cp -r ${GITLAB_GITALY_BUILD_DIR}/bin ${GITLAB_GITALY_INSTALL_DIR} \