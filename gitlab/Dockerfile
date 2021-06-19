FROM gitlab-base-builder AS gitlab-builder

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_VERSION=v13.11.5

ARG GITLAB_BUILD_DIR="${GITLAB_HOME}/gitlab-build"
ARG GITLAB_DOWNLOAD_URL="https://gitlab.com/gitlab-org/gitlab-foss.git"
# install postfix

## postgresql-dev: libpq-dev on ubuntu.
##
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libpq-dev \
    && git clone -q -b ${GITLAB_VERSION} --depth 1 ${GITLAB_DOWNLOAD_URL} ${GITLAB_BUILD_DIR} \
    && cd ${GITLAB_BUILD_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " \
     export PATH=${GOROOT}/bin:${NODE_HOME}/bin:${YARN_BIN_GITLAB_USER}:$PATH; \
     bundle install -j $(nproc) --deployment --without development test mysql aws kerberos"

# mkdir ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \

RUN cd ${GITLAB_BUILD_DIR} \
    && sudo -u ${GITLAB_USER} -H sh -c " \
    export PATH=${GOROOT}/bin:${NODE_HOME}/bin:${YARN_BIN_GITLAB_USER}:$PATH; \
    cp ${GITLAB_BUILD_DIR}/config/database.yml.postgresql ${GITLAB_BUILD_DIR}/config/database.yml; \
    cp ${GITLAB_BUILD_DIR}/config/gitlab.yml.example ${GITLAB_BUILD_DIR}/config/gitlab.yml; \
    cp ${GITLAB_BUILD_DIR}/config/resque.yml.example  ${GITLAB_BUILD_DIR}/config/resque.yml; \
    bundle exec rake gettext:compile RAILS_ENV=production; \
    yarn install --production --pure-lockfile ; \
    yarn add ajv@^4.0.0; \
    bundle exec rake gitlab:assets:compile RAILS_ENV=production NODE_ENV=production NODE_OPTIONS='--max_old_space_size=2048';" \
    && rm -rf ${GITLAB_BUILD_DIR}/node_modules

## data copy and clean unnecessary data.
## todo: del vendor/bundle/ruby/2.4.0/cache (60MB, need to known ruby version)
## todo: del ${GITLAB_BUILD_DIR}.
RUN rm -rf ${GITLAB_HOME}/.cache \
    && rm -rf ${GITLAB_BUILD_DIR}/tmp/cache/* ${GITLAB_BUILD_DIR}/.git \
    && mkdir -p ${GITLAB_INSTALL_DIR} \
    && chown -R ${GITLAB_USER}: ${GITLAB_INSTALL_DIR} \
    && cp -a  ${GITLAB_BUILD_DIR}/. ${GITLAB_INSTALL_DIR}/
    # copy from build dir to install dir (including hiden dirs).
