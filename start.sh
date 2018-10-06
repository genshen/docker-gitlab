#!/bin/bash
set -e

## start sshd
sudo sshd  -D -E ${GITLAB_LOG_DIR}/sshd.log

## todo start mail_room

## start gitaly
cd ${GITALY_DIR}
${GITALY_DIR}/bin/gitaly ${GITALY_DIR}/config.toml

## start gitlab-workhorse
cd ${GITLAB_WORKHORSE_DIR}
${GITLAB_WORKHORSE_DIR}/bin/gitlab-workhorse -listenUmask 0 -listenNetwork tcp -listenAddr ":8181" 
    -authBackend http://127.0.0.1:8080{{GITLAB_RELATIVE_URL_ROOT}}  \
    -authSocket ${GITLAB_INSTALL_DIR}/tmp/sockets/gitlab.socket \
    -documentRoot ${GITLAB_INSTALL_DIR}/public \
    -proxyHeadersTimeout {{GITLAB_WORKHORSE_TIMEOUT}}

## start unicorn
cd ${GITLAB_DIR}
bundle exec unicorn_rails -c ${GITLAB_DIR}/config/unicorn.rb -E ${RAILS_ENV}

## start sidekiq
cd ${GITLAB_DIR}
bundle exec sidekiq -c {{SIDEKIQ_CONCURRENCY}}
  -C ${GITLAB_DIR}/config/sidekiq_queues.yml \
  -e ${RAILS_ENV} \
  -t {{SIDEKIQ_SHUTDOWN_TIMEOUT}} \
  -P ${GITLAB_DIR}/tmp/pids/sidekiq.pid \
  -L ${GITLAB_DIR}/log/sidekiq.log \
