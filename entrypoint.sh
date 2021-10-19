#!/bin/bash
set -e

SSHD=$(which sshd)
BUNDLE=$(which bundle)
GITLAB_REPOS_DATA_DIR=${GITLAB_DATA_DIR}/repositories
GITLAB_WORKHORSE_WORK_DIR=${GITLAB_WORKHORSE_DIR} # run gitlab-workhorse in this directory.

## set default env
GITLAB_RELATIVE_URL_ROOT=${GITLAB_RELATIVE_URL_ROOT:-}
GITLAB_WORKHORSE_TIMEOUT=${GITLAB_WORKHORSE_TIMEOUT:-5m0s}

## SIDEKIQ
SIDEKIQ_SHUTDOWN_TIMEOUT=${SIDEKIQ_SHUTDOWN_TIMEOUT:-4}
SIDEKIQ_CONCURRENCY=${SIDEKIQ_CONCURRENCY:-25}
SIDEKIQ_MEMORY_KILLER_MAX_RSS=${SIDEKIQ_MEMORY_KILLER_MAX_RSS:-1000000}
GITLAB_SIDEKIQ_LOG_FORMAT=${GITLAB_SIDEKIQ_LOG_FORMAT:-default}

## helper function
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

## helper function
generate_ssh_key() {
  echo -n "${1^^} "
  ssh-keygen -qt ${1} -N '' -f ${2}
}

## helper function
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

## config sshd and .ssh directory.
config_ssh() {
    mkdir -p ${GITLAB_DATA_DIR}/ssh
    # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=864190.
    mkdir -p /var/run/sshd
    chmod 0755 /var/run/sshd
    # sudo mkdir /var/run/sshd # Missing privilege separation directory: /run/sshd
    generate_ssh_host_keys 

    ## link ~/.ssh dir
    mkdir_and_mod ${GITLAB_DATA_DIR}/.ssh:700
    if [[ ! -d ${GITLAB_HOME}/.ssh/authorized_keys ]]; then
        sudo -u ${GITLAB_USER} -H touch ${GITLAB_HOME}/.ssh/authorized_keys
        sudo -u ${GITLAB_USER} -H chmod 600 ${GITLAB_HOME}/.ssh/authorized_keys
        # sudo -u ${GITLAB_USER} -H ln -sf ${GITLAB_HOME}/.ssh/authorized_keys ${GITLAB_HOME}/authorized_keys
    fi
    # authorized_keys.lock
    # sudo -u ${GITLAB_USER} -H chmod 700 ${GITLAB_DATA_DIR}/.ssh
}

config_filesystem() {
    ## config gitlab/tmp dir
    mkdir_and_mod ${GITLAB_DATA_DIR}/tmp:u+rwX ${GITLAB_DATA_DIR}/tmp/pids/:u+rwX \
        ${GITLAB_DATA_DIR}/tmp/sockets/:u+rwX ${GITLAB_DATA_DIR}/tmp/sockets/private:0700 \
        ${GITLAB_DATA_DIR}/tmp/prometheus_multiproc_dir/:u+rwX
    # clean pids before starting gitlab.
    rm -rf ${GITLAB_DATA_DIR}/tmp/pids/*
    # sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp
    # sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DIR}/tmp/
    # sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/pids/
    # sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/sockets/

    ## log dir
    mkdir_and_mod ${GITLAB_LOG_DIR}/gitlab:u+rwX,go-w
    if [[ ! -f "${GITLAB_LOG_DIR}/gitlab/gitlab-shell.log" ]]; then
        sudo -u ${GITLAB_USER} -H touch ${GITLAB_LOG_DIR}/gitlab/gitlab-shell.log
    fi
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
        ${GITLAB_DATA_DIR}/shared/registry/:u+rwX
    mkdir_and_mod ${GITLAB_DATA_DIR}/shared/artifacts/tmp:u+rwX
    mkdir_and_mod ${GITLAB_DATA_DIR}/shared/artifacts/tmp/cache:u+rwX \
        ${GITLAB_DATA_DIR}/shared/artifacts/tmp/upload:u+rwX
    mkdir_and_mod ${GITLAB_PAGES_DATA_DIR}:u+rwX

    # sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/shared/artifacts/
    # Change the permissions of the directory where GitLab Pages are stored
    # sudo -u ${GITLAB_USER} -H chmod -R ug+rwX ${GITLAB_DATA_DIR}/shared/pages/

    # repository dir
    if [[ ! -d ${GITLAB_REPOS_DATA_DIR} ]]; then
        mkdir_and_mod ${GITLAB_REPOS_DATA_DIR}:u+rwX
        sudo -u ${GITLAB_USER} -H chmod ug+rwX,o-rwx ${GITLAB_REPOS_DATA_DIR}
        sudo -u ${GITLAB_USER} -H chmod g+s ${GITLAB_REPOS_DATA_DIR}
    fi

    ## config secrets
    local shell_secret="${GITLAB_DIR}/.gitlab_shell_secret"
    if [[ ! -f "${shell_secret}" ]]; then
        sudo -u ${GITLAB_USER} -H openssl rand -hex -out "${shell_secret}" 16
        chmod 600 "${shell_secret}"
        sudo -u ${GITLAB_USER} -H ln -s "${shell_secret}" ${GITLAB_SHELL_DIR}/.gitlab_shell_secret
    fi

    local workhorse_secret="${GITLAB_WORKHORSE_WORK_DIR}/.gitlab_workhorse_secret"
    if [[ ! -f "${workhorse_secret}" ]]; then
        sudo -u ${GITLAB_USER} -H openssl rand -base64 -out "${workhorse_secret}" 32
        chmod 600 "${workhorse_secret}"
    fi
}

init_db() {
    ## create a file GITLAB_INIT to indicate the gitlab has been initialized.
    if [[ ! -f "${GITLAB_DATA_DIR}/GITLAB_INIT" ]]; then 
        ## initialize database.
        cd ${GITLAB_DIR}
        sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:setup RAILS_ENV=${RAILS_ENV} force=yes
        sudo -u ${GITLAB_USER} -H touch ${GITLAB_DATA_DIR}/GITLAB_INIT
    fi
}

start_gitlab_daemons() {
    ## start puma(user:git)
    # echo "starting puma"
    # start-stop-daemon --background --start --chdir ${GITLAB_DIR} --chuid ${GITLAB_USER} \
    #     --exec ${BUNDLE} -- exec puma --config ${GITLAB_DIR}/config/puma.rb -E ${RAILS_ENV}
    # echo "done"

    # Start the web server
    echo "starting web"
    cd ${GITLAB_DIR}
    sudo -u ${GITLAB_USER} -H RAILS_ENV=${RAILS_ENV} bin/web start
    echo "done"

    ## start sidekiq(user:git)
    echo "starting gitlab sidekiq"
    start-stop-daemon --background --start --chdir ${GITLAB_DIR} --chuid ${GITLAB_USER} \
    --exec ${BUNDLE} -- exec sidekiq -c ${SIDEKIQ_CONCURRENCY} \
        -C ${GITLAB_DIR}/config/sidekiq_queues.yml \
        -e ${RAILS_ENV} \
        -t ${SIDEKIQ_SHUTDOWN_TIMEOUT} \
        -P ${GITLAB_DIR}/tmp/pids/sidekiq.pid \
        -L ${GITLAB_DIR}/log/sidekiq.log \
    echo "done"
    # OR: 
    #  RAILS_ENV=$RAILS_ENV bin/background_jobs start &

    ## start gitaly(user:git, note: dir is ${GITLAB_DIR})
    echo "starting gitaly"
    start-stop-daemon --background --start --chdir ${GITALY_DIR} --chuid ${GITLAB_USER} \
        --exec ${GITALY_DIR}/bin/gitaly -- ${GITALY_DIR}/config.toml
    echo "done"
    # OR:
    # $app_root/bin/daemon_with_pidfile $gitaly_pid_path $gitaly_dir/gitaly $gitaly_dir/config.toml >> $gitaly_log 2>&1 &

    ## start gitlab-workhorse(user:git)
    echo "starting gitlab-workhorse"
    local workhorse_network="tcp"
    local workhorse_addr=":8181"
    if [[ ${WORKHORSE_LISTEN_NETWORK} = "unix" ]]; then
        workhorse_network="unix"
        workhorse_addr="${GITLAB_DIR}/tmp/sockets/gitlab-workhorse.socket"
        echo "gitlab-workhorse is running to listen unix socket at ${workhorse_addr}"
    else
        echo "gitlab-workhorse is running to listen tcp socket at ${workhorse_addr}"
    fi
    start-stop-daemon --start --chdir ${GITLAB_WORKHORSE_WORK_DIR} --chuid ${GITLAB_USER} \
        --exec ${GITLAB_WORKHORSE_DIR}/bin/gitlab-workhorse \
        -- -secretPath ${GITLAB_WORKHORSE_WORK_DIR}/.gitlab_workhorse_secret \
        -listenUmask 0 -listenNetwork ${workhorse_network} -listenAddr ${workhorse_addr} \
        -authBackend http://127.0.0.1:8080${GITLAB_RELATIVE_URL_ROOT}  \
        -authSocket ${GITLAB_DIR}/tmp/sockets/gitlab.socket \
        -documentRoot ${GITLAB_DIR}/public \
        -proxyHeadersTimeout ${GITLAB_WORKHORSE_TIMEOUT} \
        -logFile ${GITLAB_LOG_DIR}/gitlab/gitlab-workhorse.log
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
}

run_rake_task() {
    cd ${GITLAB_DIR}
    sudo -u ${GIT_USER} -H bundle exec rake $@
}

usage() {
    cat << EOF
Arguments:
    help            - show this help messgae.
    init            - init gitlab database.
    start           - start gitlab service.
    run [command]   - init filesystem (setting data files, and ssh config) and then run a specified command.
    [command]       - run the specified command, eg. bash.
EOF
}

if [ "$1" != "" ]; then
    case $1 in
        help)
            usage
            exit
            ;;
        rake)
            shift 1
            run_rake_task $@
        ;;
        init)
            echo "setting up data directory."
            # config_ssh
            config_filesystem
            echo "done"
            echo "starting gitaly."
            start-stop-daemon --background --start --chdir ${GITALY_DIR} --chuid ${GITLAB_USER} \
                --exec ${GITALY_DIR}/bin/gitaly -- ${GITALY_DIR}/config.toml
            echo "done"
            echo "inititalizing database."
            init_db
            echo "done"
        ;;
        run)
            echo "initializing sshd service and setting up data directory."
            config_ssh
            config_filesystem
            echo "done"
            shift
            exec "$@"
            ;;
        start)
            echo "initializing sshd service and setting up data directory."
            config_ssh
            config_filesystem
            echo "done"

            # sshd re-exec requires execution with an absolute path.
            # start-stop-daemon is only used on debian system.
            echo "starting sshd daemons."
            start-stop-daemon --background --start --exec ${SSHD} -- -D -E ${GITLAB_LOG_DIR}/sshd.log
            echo "done"
            start_gitlab_daemons
            ;;
        *)
            exec "$@"
            ;;
    esac
    shift
fi
