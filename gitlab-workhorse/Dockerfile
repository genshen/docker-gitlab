FROM genshen/gitlab-base-builder AS gitlab-workhorse-builder
### docker build --rm -t genshen/gitlab-workhorse-builder .

## version number should better be the same in /home/git/gitlab/GITLAB_WORKHORSE_VERSION
## see files in https://gitlab.com/gitlab-org/gitlab-ce for corresponding gitlab version.
ENV  GITLAB_WORKHORSE_INSTALL_DIR="${GITLAB_HOME}/gitlab-workhorse" \
     GITLAB_WORKHORSE_VERSION_TAG="v7.6.0"
ARG  GITLAB_WORKHORSE_BUILD_DIR="${GITLAB_HOME}/gitlab-workhorse-builder"
# it must be a git repository, or following error will happen: "fatal: Not a git repository (or any of the parent directories): .git"
ARG  GITLAB_WORKHORSE_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-workhorse.git"

## node is in /usr/local/node, and go is in /usr/local/go.
RUN git clone -q -b ${GITLAB_WORKHORSE_VERSION_TAG} --depth 1 ${GITLAB_WORKHORSE_DOWNLOAD_URL} ${GITLAB_WORKHORSE_BUILD_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_WORKHORSE_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " \
    cd ${GITLAB_WORKHORSE_BUILD_DIR}; \
    export PATH=${GOROOT}/bin:$PATH; \
    make install PREFIX=${GITLAB_WORKHORSE_INSTALL_DIR} " \
    && rm -rf ${GITLAB_WORKHORSE_BUILD_DIR}

## the binary is located in ${GITLAB_WORKHORSE_INSTALL_DIR}/bin
