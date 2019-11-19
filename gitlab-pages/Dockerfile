FROM golang:1.13.4-buster AS gitlab-pages-builder

## version number should better be the same in /home/git/gitlab/GITLAB_PAGES_VERSION
## see files in https://gitlab.com/gitlab-org/gitlab-foss for corresponding gitlab version.
ENV  GITLAB_PAGES_INSTALL_DIR="/usr/local/gitlab-pages" \
     GITLAB_PAGES_VERSION_TAG="v1.11.0"
ARG  GITLAB_PAGES_BUILD_DIR="/tmp/gitlab-pages-builder"
ARG  GITLAB_PAGES_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-pages.git"

RUN apt-get clean && apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    git-core make

## compiler from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh
## node ruby are in /usr/local, and go is in /usr/local/go.
RUN git clone -q -b ${GITLAB_PAGES_VERSION_TAG} --depth 1 ${GITLAB_PAGES_DOWNLOAD_URL} ${GITLAB_PAGES_BUILD_DIR} \
    && cd ${GITLAB_PAGES_BUILD_DIR} \
    && make all -j $(nproc) \
    && mkdir -p ${GITLAB_PAGES_INSTALL_DIR} \
    && cp -a ${GITLAB_PAGES_BUILD_DIR}/bin ${GITLAB_PAGES_INSTALL_DIR} \
    && cp -a ${GITLAB_PAGES_BUILD_DIR}/shared ${GITLAB_PAGES_INSTALL_DIR} \
    && rm -rf ${GITLAB_PAGES_BUILD_DIR}

## the binary is located in ${GITLAB_PAGES_INSTALL_DIR}/bin


### docker build --rm -t genshen/gitlab-pages .
FROM debian:buster-slim AS gitlab-pages

LABEL maintainer="genshenchu@gmail.com" \
      description="gitlab-pages images."

ENV GITLAB_PAGES_USER="git" \
    GITLAB_PAGES_HOME="/home/git/gitlab-pages"

ENV GITLAB_PAGES_DATA_DIR="${GITLAB_PAGES_HOME}/pages" \
    GITLAB_PAGES_CONF_FILE="${GITLAB_PAGES_HOME}/pages.conf" \
    GITLAB_PAGES_LOG="${GITLAB_PAGES_HOME}/gitlab-pages.log" 

RUN apt-get clean && apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    zip unzip \
    && adduser --disabled-login --gecos 'GitLab' ${GITLAB_PAGES_USER} \
    && passwd -d ${GITLAB_PAGES_USER}

COPY --chown=git:git --from=gitlab-pages-builder /usr/local/gitlab-pages ${GITLAB_PAGES_HOME}/

EXPOSE 8080/tcp 4433/tcp
VOLUME ["${GITLAB_PAGES_DATA_DIR}"]
# "${GITLAB_PAGES_CONF_FILE}", "${GITLAB_PAGES_LOG}"

USER ${GITLAB_PAGES_USER}
WORKDIR ${GITLAB_PAGES_HOME}
CMD ["./bin/gitlab-pages", "--help"]
