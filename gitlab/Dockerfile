FROM genshen/gitlab-builder AS gitlab_builder

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_VERSION=v10.5.8

ARG GITLAB_BUILD_DIR="${GITLAB_HOME}/gitlab-build"
ARG GITLAB_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-ce.git"
# install postfix

## postgresql-dev: libpq-dev on ubuntu.
##
RUN apk add --no-cache postgresql-dev \
    && export PATH=${GOROOT}/bin:${YARN_BIN_GITLAB_USER}:$PATH \
    && git clone -q -b ${GITLAB_VERSION} --depth 1 ${GITLAB_DOWNLOAD_URL} ${GITLAB_BUILD_DIR} \
    && cd ${GITLAB_BUILD_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H bundle install -j ${BUILD_PROS} --deployment --without development test mysql aws kerberos
# mkdir ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \

RUN ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \
    && cd ${GITLAB_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H yarn install --production --pure-lockfile \
    && sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:assets:compile USE_DB=false SKIP_STORAGE_VALIDATION=true
