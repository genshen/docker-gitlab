#!/bin/bash
set -e

SSHD=$(which sshd)
BUNDLE=$(which bundle)

## set default env
GITLAB_RELATIVE_URL_ROOT=${GITLAB_RELATIVE_URL_ROOT:-}
GITLAB_WORKHORSE_TIMEOUT=${GITLAB_WORKHORSE_TIMEOUT:-5m0s}

## SIDEKIQ
SIDEKIQ_SHUTDOWN_TIMEOUT=${SIDEKIQ_SHUTDOWN_TIMEOUT:-4}
SIDEKIQ_CONCURRENCY=${SIDEKIQ_CONCURRENCY:-25}
SIDEKIQ_MEMORY_KILLER_MAX_RSS=${SIDEKIQ_MEMORY_KILLER_MAX_RSS:-1000000}
GITLAB_SIDEKIQ_LOG_FORMAT=${GITLAB_SIDEKIQ_LOG_FORMAT:-default}

## if the directory dose not exists, then create it and set owner.
mkdir_and_mod () {
    for dir_permi in "$@"
    do
    # if the dirctory exists, just skip it.
        IFS=':' read -r d permi <<< "$dir_permi"
        if [[ -f "$d" ]]; then
            rm $d
        fi
        if ! [[ -d "$d" ]]; then
            mkdir -p $d;
            chown -R ${GITLAB_USER}: $d;
            sudo -u ${GITLAB_USER} -H chmod -R ${permi} $d
        fi
    done
}

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

####================================
#== start of configure of filesystem
####================================
echo "setting up sshd service and data directory."
## config and start sshd.
mkdir -p ${GITLAB_DATA_DIR}/ssh
# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=864190.
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd
# sudo mkdir /var/run/sshd # Missing privilege separation directory: /run/sshd
generate_ssh_host_keys 

## link ~/.ssh dir
mkdir_and_mod ${GITLAB_DATA_DIR}/.ssh:700
# sudo -u ${GITLAB_USER} -H chmod 700 ${GITLAB_DATA_DIR}/.ssh

## config gitlab/tmp dir
mkdir_and_mod ${GITLAB_DATA_DIR}/tmp:u+rwX ${GITLAB_DATA_DIR}/tmp/pids/:u+rwX \
    ${GITLAB_DATA_DIR}/tmp/sockets/:u+rwX ${GITLAB_DATA_DIR}/tmp/sockets/private:0700
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DIR}/tmp/
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/pids/
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/sockets/

## log dir
mkdir_and_mod ${GITLAB_LOG_DIR}/gitlab:u+rwX,go-w
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX,go-w ${GITLAB_LOG_DIR}/gitlab

## public/uploads dir
# Make sure only the GitLab user has access to the public/uploads/ directory
# now that files in public/uploads are served by gitlab-workhorse
mkdir_and_mod ${GITLAB_DATA_DIR}/public:0744 ${GITLAB_DATA_DIR}/public/uploads:0700
# sudo -u ${GITLAB_USER} -H chmod 0700 ${GITLAB_DATA_DIR}/public/uploads

## builds dir.
# todo: # WORKAROUND for https://github.com/sameersbn/docker-gitlab/issues/509
mkdir_and_mod ${GITLAB_DATA_DIR}/builds/:u+rwX
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/builds/

## shared dir.
# Change the permissions of the directory where CI artifacts are stored
mkdir_and_mod ${GITLAB_DATA_DIR}/shared/:u+rwX
mkdir_and_mod ${GITLAB_DATA_DIR}/shared/artifacts/:u+rwX \
    ${GITLAB_DATA_DIR}/shared/lfs-objects/:u+rwX \
    ${GITLAB_DATA_DIR}/shared/pages/:u+rwX \
    ${GITLAB_DATA_DIR}/shared/registry/:u+rwX
mkdir_and_mod ${GITLAB_DATA_DIR}/shared/artifacts/tmp:u+rwX
mkdir_and_mod ${GITLAB_DATA_DIR}/shared/artifacts/tmp/cache:u+rwX \
    ${GITLAB_DATA_DIR}/shared/artifacts/tmp/upload:u+rwX
# sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/shared/artifacts/
# Change the permissions of the directory where GitLab Pages are stored
# sudo -u ${GITLAB_USER} -H chmod -R ug+rwX ${GITLAB_DATA_DIR}/shared/pages/

# repository dir
mkdir_and_mod ${GITLAB_DATA_DIR}/repositories:u+rwX
echo "done"
####=======================
#==end of configure of filesystem
####=======================


## create a file to indicate the gitlab has been initialized.
echo "inititalizing database."
if [[ ! -f "${GITLAB_DATA_DIR}/GITLAB_INIT" ]]; then 
    ## initialize database.
    cd ${GITLAB_DIR}
    sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:setup RAILS_ENV=${RAILS_ENV} force=yes
    sudo -u ${GITLAB_USER} -H touch ${GITLAB_DATA_DIR}/GITLAB_INIT
fi
echo "done"


# sshd re-exec requires execution with an absolute path.
# start-stop-daemon is only used on debian system.
echo "starting sshd service."
start-stop-daemon --background --start --exec ${SSHD} -- -D -E ${GITLAB_LOG_DIR}/sshd.log
echo "done"

## start unicorn(user:git)
echo "starting unicorn_rails"
start-stop-daemon --background --start --chdir ${GITLAB_DIR} --user ${GITLAB_USER} \
    --exec ${BUNDLE} -- exec unicorn_rails -c ${GITLAB_DIR}/config/unicorn.rb -E ${RAILS_ENV}
echo "done"
#OR:    # Remove old unicorn socket if it exists
# rm -f "$rails_socket" 2>/dev/null
    # Start the web server
# RAILS_ENV=$RAILS_ENV bin/web start

## start sidekiq(user:git)
echo "starting gitlab sidekiq"
start-stop-daemon --background --start --chdir ${GITLAB_DIR} --user ${GITLAB_USER} \
  --exec ${BUNDLE} -- exec sidekiq -c ${SIDEKIQ_CONCURRENCY} \
  -C ${GITLAB_DIR}/config/sidekiq_queues.yml \
  -e ${RAILS_ENV} \
  -t ${SIDEKIQ_SHUTDOWN_TIMEOUT} \
  -P ${GITLAB_DIR}/tmp/pids/sidekiq.pid \
  -L ${GITLAB_DIR}/log/sidekiq.log \
echo "done"
# OR: 
#  RAILS_ENV=$RAILS_ENV bin/background_jobs start &

## start gitlab-workhorse(user:git)
echo "starting gitlab-workhorse"
start-stop-daemon --background --start --chdir ${GITLAB_WORKHORSE_DIR} --user ${GITLAB_USER} \
    --exec ${GITLAB_WORKHORSE_DIR}/bin/gitlab-workhorse \
    -- -listenUmask 0 -listenNetwork tcp -listenAddr ":8181"  \
    -authBackend http://127.0.0.1:8080${GITLAB_RELATIVE_URL_ROOT}  \
    -authSocket ${GITLAB_DIR}/tmp/sockets/gitlab.socket \
    -documentRoot ${GITLAB_DIR}/public \
    -proxyHeadersTimeout ${GITLAB_WORKHORSE_TIMEOUT}
echo "done"
# OR:
# $app_root/bin/daemon_with_pidfile $gitlab_workhorse_pid_path  \
#    /usr/bin/env PATH=$gitlab_workhorse_dir:$PATH \
#    gitlab-workhorse $gitlab_workhorse_options \
#    >> $gitlab_workhorse_log 2>&1 &


## todo start mail_room(user:git)

## todo gitlab pages
# OR:
# $app_root/bin/daemon_with_pidfile $gitlab_pages_pid_path \
# $gitlab_pages_dir/gitlab-pages $gitlab_pages_options \
#  >> $gitlab_pages_log 2>&1 &


## start gitaly(user:git, note: dir is ${GITLAB_DIR})
echo "starting gitaly"
start-stop-daemon --background --start --chdir ${GITALY_DIR} --user ${GITLAB_USER} \
    --exec ${GITALY_DIR}/bin/gitaly -- ${GITALY_DIR}/config.toml
echo "done"
# OR:
# $app_root/bin/daemon_with_pidfile $gitaly_pid_path $gitaly_dir/gitaly $gitaly_dir/config.toml >> $gitaly_log 2>&1 &

