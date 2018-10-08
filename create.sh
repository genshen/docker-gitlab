#!/bin/bash
set -e

## todo filesystem initialization can be moved to entrypoint.sh.

## this function is recommended to run in root mode.
## But, if this des is in git user HOME, non-root can be ok.
mkdir_for_git ()
{
    all_dirs=$@
    for d in "$@"
    do
    # if the dirctory exists, just skip it.
        if [[ -f "$d" ]]; then
            rm $d
        fi
        if ! [[ -d "$d" ]]; then
            mkdir -p $d;
            chown -R ${GITLAB_USER}: $d;
        fi
    done
}

## ths des dir must be in GITLAB_USER HOME dir.
ln_f ()
{
    src=$1;
    des=$2;
    mkdir_for_git $src
    sudo -u ${GITLAB_USER} -H ln -sf $src $des;
}

ln_file ()
{
    src=$1;
    des=$2;
    touch $src;
    chown -R ${GITLAB_USER}: $src;
    sudo -u ${GITLAB_USER} -H ln -sf $src $des;
}

## config sshd.
sed -i \
  -e "s|^[#]*UsePAM yes|UsePAM no|" \
  -e "s|^[#]*UsePrivilegeSeparation yes|UsePrivilegeSeparation no|" \
  -e "s|^[#]*PasswordAuthentication yes|PasswordAuthentication no|" \
  -e "s|^[#]*LogLevel INFO|LogLevel VERBOSE|" \
  /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config

# in some system, those lines are commented.
sed -i "s|#HostKey|HostKey|g" /etc/ssh/sshd_config
sed -i "s|HostKey /etc/ssh/|HostKey ${GITLAB_DATA_DIR}/ssh/|g" /etc/ssh/sshd_config
# ssh_host file will be created at container runing.
rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

## link ~/.ssh dir
rm -rf ${GITLAB_HOME}/.ssh
ln_f ${GITLAB_DATA_DIR}/.ssh ${GITLAB_HOME}/.ssh

# configure user env.
sudo -u ${GITLAB_USER} -H git config --global core.autocrlf input
sudo -u ${GITLAB_USER} -H git config --global gc.auto 0
sudo -u ${GITLAB_USER} -H git config --global repack.writeBitmaps true
sudo -u ${GITLAB_USER} -H git config --global receive.advertisePushOptions true

# mkdir_for_git ${GITLAB_DIR} ${GITALY_DIR} ${GITLAB_PAGES_DIR} ${GITLAB_SHELL_DIR} ${GITLAB_WORKHORSE_DIR}
# @important: please make sure all upstream images data has owner ${GITLAB_USER}.
mkdir_for_git ${GITLAB_CONFIG_DIR} ${GITLAB_DATA_DIR} ${GITLAB_CACHE_DIR} ${GITLAB_LOG_DIR}

## init gitlab tmp dir.
# the dir ${GITLAB_DIR}/tmp already exists.
# https://docs.gitlab.com/ce/install/installation.html#configure-it
echo "linking gitlab config."
rm -rf ${GITLAB_DIR}/tmp/pids ${GITLAB_DIR}/tmp/sockets
ln_f ${GITLAB_DATA_DIR}/tmp/pids/ ${GITLAB_DIR}/tmp/pids
ln_f ${GITLAB_DATA_DIR}/tmp/sockets/ ${GITLAB_DIR}/tmp/sockets

# todo: Restrict Gitaly socket access
# sudo chmod 0700 /home/git/gitlab/tmp/sockets/private
# sudo chown git /home/git/gitlab/tmp/sockets/private

## init gitlab log dir.
rm -rf ${GITLAB_DIR}/log
ln_f ${GITLAB_LOG_DIR}/gitlab ${GITLAB_DIR}/log
ln_file ${GITLAB_LOG_DIR}/gitlab-shell.log ${GITLAB_SHELL_DIR}/gitlab-shell.log
# ln gitlab-shell logs (@see home/git/gitlab/lib/support/logrotate/gitlab)

## init public/upload dir.
rm -rf ${GITLAB_DIR}/public/uploads
ln_f ${GITLAB_DATA_DIR}/public/uploads ${GITLAB_DIR}/public/uploads

# Change the permissions of the directory where CI job traces are stored
rm -rf ${GITLAB_DIR}/builds/
ln_f ${GITLAB_DATA_DIR}/builds/ ${GITLAB_DIR}/builds

## shared dir
ln_f ${GITLAB_DATA_DIR}/shared/ ${GITLAB_DIR}/shared

# remove gitlab shell and workhorse secrets
rm -f ${GITLAB_DIR}/.gitlab_shell_secret ${GITLAB_DIR}/.gitlab_workhorse_secret

## init .secret
rm -rf ${GITLAB_DIR}/.secret
ln_file ${GITLAB_DATA_DIR}/.secret ${GITLAB_DIR}/.secret

## repository dir
rm -rf ${GIT_REPOSITORIES_DIR}
ln_f ${GITLAB_DATA_DIR}/repositories ${GIT_REPOSITORIES_DIR}


# todo Configure GitLab DB Settings
# todo in Configure: sudo -u git -H chmod 0600 config/secrets.yml

# configure sshd
sed -i \
  -e "s|^[#]*UsePAM yes|UsePAM no|" \
  -e "s|^[#]*UsePrivilegeSeparation yes|UsePrivilegeSeparation no|" \
  -e "s|^[#]*PasswordAuthentication yes|PasswordAuthentication no|" \
  -e "s|^[#]*LogLevel INFO|LogLevel VERBOSE|" \
  /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config

## copy config files
# copy gitlab config files
ln_file ${GITLAB_CONFIG_DIR}/gitlab.yml  ${GITLAB_DIR}/config/gitlab.yml
ln_file ${GITLAB_CONFIG_DIR}/database.yml  ${GITLAB_DIR}/config/database.yml
ln_file ${GITLAB_CONFIG_DIR}/redis.cache.yml  ${GITLAB_DIR}/config/redis.cache.yml
ln_file ${GITLAB_CONFIG_DIR}/redis.queues.yml  ${GITLAB_DIR}/config/redis.queues.yml
ln_file ${GITLAB_CONFIG_DIR}/redis.share_state.yml  ${GITLAB_DIR}/config/redis.share_state.yml
ln_file ${GITLAB_CONFIG_DIR}/resque.yml  ${GITLAB_DIR}/config/resque.yml
ln_file ${GITLAB_CONFIG_DIR}/secrets.yml  ${GITLAB_DIR}/config/secrets.yml
ln_file ${GITLAB_CONFIG_DIR}/unicorn.rb  ${GITLAB_DIR}/config/unicorn.rb

ln_file ${GITLAB_CONFIG_DIR}/initializers_rack_attack.rb  ${GITLAB_DIR}/config/initializers/rack_attack.rb

#copy gitlab-shell config files
ln_file ${GITLAB_CONFIG_DIR}/gitlab-shell.config.yml  ${GITLAB_SHELL_DIR}/config.yml

# copy gitaly config files
ln_file ${GITLAB_CONFIG_DIR}/gitaly.config.toml  ${GITALY_DIR}/config.toml


## Install Init Script
# cp ${GITLAB_DIR}/lib/support/init.d/gitlab /etc/init.d/gitlab

## Set up Logrotate
# fix "unknown group 'syslog'" error preventing logrotate from functioning (from: https://github.com/sameersbn/docker-gitlab/blob/master/assets/build/install.sh)
sed -i "s|^su root syslog$|su root root|" /etc/logrotate.conf
cp ${GITLAB_DIR}/lib/support/logrotate/gitlab /etc/logrotate.d/gitlab