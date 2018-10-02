FROM genshen/gitlab-builder AS gitlab-pages-builder
### docker build --rm -t genshen/gitlab-pages-builder .

## version number should better be the same in /home/git/gitlab/GITLAB_PAGES_VERSION
## see files in https://gitlab.com/gitlab-org/gitlab-ce for corresponding gitlab version.
ENV  GITLAB_PAGES_INSTALL_DIR="${GITLAB_HOME}/gitlab-pages" \
     GITLAB_PAGES_VERSION_TAG="v0.6.0"
ARG  GITLAB_PAGES_BUILD_DIR="${GITLAB_HOME}/gitlab-pages-builder"
ARG  GITLAB_PAGES_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-pages.git"

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## node ruby are in /usr/local, and go is in /usr/local/go.
RUN git clone -q -b ${GITLAB_PAGES_VERSION_TAG} --depth 1 ${GITLAB_PAGES_DOWNLOAD_URL} ${GITLAB_PAGES_BUILD_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_PAGES_BUILD_DIR} \
    && cd ${GITLAB_PAGES_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " export PATH=${GOROOT}/bin:$PATH; make all" \
    && mkdir -p ${GITLAB_PAGES_INSTALL_DIR} \
    && cp -r ${GITLAB_PAGES_BUILD_DIR}/bin ${GITLAB_PAGES_INSTALL_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_PAGES_INSTALL_DIR} \
    && rm -rf ${GITLAB_PAGES_BUILD_DIR}

## the binary is located in ${GITLAB_PAGES_INSTALL_DIR}/bin