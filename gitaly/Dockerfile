FROM gitlab-base-builder AS gitlab-gitaly-builder
### docker build --rm -t gitlab-gitaly-builder .

ENV  GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
     GITLAB_GITALY_VERSION_TAG="v13.8.7"
ARG  GITLAB_GITALY_BUILD_DIR="${GITLAB_HOME}/gitlab-gitaly-builder"
# it must be a git repository, or following error will happen: "fatal: Not a git repository (or any of the parent directories): .git"
ARG  GITLAB_GITALY_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitaly.git"

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## the default PREFIX is /usr/local, so binary will be in /usr/local/bin.
## node in /usr/local/node, and go is in /usr/local/go.
RUN git clone -q -b ${GITLAB_GITALY_VERSION_TAG} --depth 1 ${GITLAB_GITALY_DOWNLOAD_URL} ${GITLAB_GITALY_BUILD_DIR} \
    && mkdir -p ${GITLAB_GITALY_INSTALL_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_GITALY_BUILD_DIR} ${GITLAB_GITALY_INSTALL_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " \
    cd ${GITLAB_GITALY_BUILD_DIR}; \
    export PATH=${GOROOT}/bin:$PATH; \
    make install PREFIX=${GITLAB_GITALY_INSTALL_DIR};" \
    && cp -a ${GITLAB_GITALY_BUILD_DIR}/ruby ${GITLAB_GITALY_INSTALL_DIR} \
    && rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/**/cache \
    && rm -rf ${GITLAB_GITALY_BUILD_DIR}

## the binary is located in ${GITLAB_GITALY_INSTALL_DIR}

# && cp -a ${GITLAB_GITALY_BUILD_DIR}/ruby ${GITLAB_GITALY_INSTALL_DIR} \
# && cp -a ${GITLAB_GITALY_BUILD_DIR}/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml \
# && rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/**/cache \
# && cp -r ${GITLAB_GITALY_BUILD_DIR}/bin ${GITLAB_GITALY_INSTALL_DIR} \
