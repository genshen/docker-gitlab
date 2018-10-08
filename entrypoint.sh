#!/bin/bash
set -e

SSHD=$(which sshd)
BUNDLE=$(which bundle)

## create a file to indicate the gitlab has been initialized.
if [[ ! -f "${GITLAB_DATA_DIR}/GITLAB_INIT" ]]; then 
    ## initialize database.
    cd ${GITLIB_DIR}
    sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:setup RAILS_ENV=${RAILS_ENV} force=yes
    sudo -u ${GITLAB_USER} -H touch ${GITLAB_DATA_DIR}/GITLAB_INI
fi

## start sshd
generate_ssh_key() {
  echo -n "${1^^} "
  ssh-keygen -qt ${1} -N '' -f ${2}
}

generate_ssh_host_keys() {
  if [[ ! -e ${GITLAB_DATA_DIR}/ssh/ssh_host_rsa_key ]]; then
    echo -n "Generating OpenSSH host keys... "
    generate_ssh_key rsa      ${GITLAB_DATA_DIR}/ssh/ssh_host_rsa_key
    generate_ssh_key dsa      ${GITLAB_DATA_DIR}/ssh/ssh_host_dsa_key
    generate_ssh_key ecdsa    ${GITLAB_DATA_DIR}/ssh/ssh_host_ecdsa_key
    generate_ssh_key ed25519  ${GITLAB_DATA_DIR}/ssh/ssh_host_ed25519_key
    echo
  fi

  # ensure existing host keys have the right permissions(root)
  chmod 0600 ${GITLAB_DATA_DIR}/ssh/*_key
  chmod 0644 ${GITLAB_DATA_DIR}/ssh/*.pub
}

## config and start sshd.
mkdir -p ${GITLAB_DATA_DIR}/ssh
# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=864190.
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd
# sudo mkdir /var/run/sshd # Missing privilege separation directory: /run/sshd
generate_ssh_host_keys 
# sshd re-exec requires execution with an absolute path.
# start-stop-daemon is only used on debian system.
start-stop-daemon --background --start --exec ${SSHD} -- -D -E ${GITLAB_LOG_DIR}/sshd.log

## todo start mail_room(user:git)

## start gitaly(user:git, note: dir is ${GITLAB_DIR})
start-stop-daemon --background --start --chdir ${GITLAB_DIR} --user ${GITLAB_USER} \
    --exec ${GITALY_DIR}/bin/gitaly -- ${GITALY_DIR}/config.toml

## start gitlab-workhorse(user:git)
start-stop-daemon --background --start --chdir ${GITLAB_WORKHORSE_DIR} --user ${GITLAB_USER} \
    --exec ${GITLAB_WORKHORSE_DIR}/bin/gitlab-workhorse \
    -- -listenUmask 0 -listenNetwork tcp -listenAddr ":8181" 
    -authBackend http://127.0.0.1:8080{{GITLAB_RELATIVE_URL_ROOT}}  \
    -authSocket ${GITLAB_DIR}/tmp/sockets/gitlab.socket \
    -documentRoot ${GITLAB_DIR}/public \
    -proxyHeadersTimeout {{GITLAB_WORKHORSE_TIMEOUT}}

## start unicorn(user:git)
start-stop-daemon --background --start --chdir ${GITLAB_DIR} --user ${GITLAB_USER} \
    --exec ${BUNDLE} -- exec unicorn_rails -c ${GITLAB_DIR}/config/unicorn.rb -E ${RAILS_ENV}

## start sidekiq(user:git)
start-stop-daemon --background --start --chdir ${GITLAB_DIR} --user ${GITLAB_USER} \
  --exec ${BUNDLE} -- exec sidekiq -c {{SIDEKIQ_CONCURRENCY}} \
  -C ${GITLAB_DIR}/config/sidekiq_queues.yml \
  -e ${RAILS_ENV} \
  -t {{SIDEKIQ_SHUTDOWN_TIMEOUT}} \
  -P ${GITLAB_DIR}/tmp/pids/sidekiq.pid \
  -L ${GITLAB_DIR}/log/sidekiq.log \
