#!/bin/bash
set -e

## this function is recommended to run in root mode.
## But, if this des is in git user HOME, non-root can be ok.
mkdir_for_git (des)
{
    # if the dirctory exists, just remove it.
    if [ -d "$des" ] then
        rm $des
    if
    mkdir -p $des
    chown -R ${GITLAB_USER}: $des
}

## ths des dir must be in GITLAB_USER HOME dir.
ln_f(src, des)
{
    mkdir_for_git(src)
    sudo -u ${GITLAB_USER} -H ln -sf src des
}

## install necessary packages.
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
   sudo ca-certificates curl openssh-server git-core ruby logrotate

gem install bundler --no-ri --no-rdoc

rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub
# configure user env.
sudo -u ${GITLAB_USER} -H git config --global core.autocrlf input
sudo -u ${GITLAB_USER} -H git config --global gc.auto 0
sudo -u ${GITLAB_USER} -H git config --global repack.writeBitmaps true
sudo -u ${GITLAB_USER} -H git config --global receive.advertisePushOptions true

mkdir_for_git ${GITLAB_DIR}
mkdir_for_git ${GITALY_DIR}
mkdir_for_git ${GITLAB_PAGES_DIR}
mkdir_for_git ${GITLAB_SHELL_DIR}
mkdir_for_git ${GITLAB_WORKHORSE_DIR}

mkdir_for_git ${GITLAB_DATA_DIR}
mkdir_for_git ${GITLAB_CACHE_DIR}
mkdir_for_git ${GITLAB_LOG_DIR}

# remove gitlab shell and workhorse secrets
rm -f ${GITLAB_DIR}/.gitlab_shell_secret ${GITLAB_DIR}/.gitlab_workhorse_secret

## init ~/.ssh dir
rm -rf ${GITLAB_HOME}/.ssh
ln_f ${GITLAB_DATA_DIR}/.ssh ${GITLAB_HOME}/.ssh
sudo -u ${GITLAB_USER} -H chmod 700 ${GITLAB_DATA_DIR}/.ssh

## init gitlab tmp dir.
# the dir ${GITLAB_DIR}/tmp already exists.
# https://docs.gitlab.com/ce/install/installation.html#configure-it
echo "start gitlab config."
ln_f ${GITLAB_DATA_DIR}/tmp/pids/ ${GITLAB_DIR}/tmp/pids
ln_f ${GITLAB_DATA_DIR}/tmp/sockets/ ${GITLAB_DIR}/tmp/sockets
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DIR}/tmp/
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/pids/
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/tmp/sockets/

## init gitlab log dir.
rm -rf ${GITLAB_DIR}/log
ln_f ${GITLAB_LOG_DIR}/gitlab ${GITLAB_DIR}/log
sudo -u ${GITLAB_USER} -H chmod -R u+rwX,go-w ${GITLAB_LOG_DIR}/gitlab

## init public/upload dir.
rm -rf ${GITLAB_DIR}/public/uploads
ln_f ${GITLAB_DATA_DIR}/public/uploads ${GITLAB_DIR}/public/uploads
# Make sure only the GitLab user has access to the public/uploads/ directory
# now that files in public/uploads are served by gitlab-workhorse
sudo -u ${GITLAB_USER} -H chmod 0700 ${GITLAB_DATA_DIR}/public/uploads
# Change the permissions of the directory where CI job traces are stored
# todo: # WORKAROUND for https://github.com/sameersbn/docker-gitlab/issues/509
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/builds/
# Change the permissions of the directory where CI artifacts are stored
sudo -u ${GITLAB_USER} -H chmod -R u+rwX ${GITLAB_DATA_DIR}/shared/artifacts/
# Change the permissions of the directory where GitLab Pages are stored
sudo -u ${GITLAB_USER} -H chmod -R ug+rwX ${GITLAB_DATA_DIR}/shared/pages/

## init .secret
rm -rf ${GITLAB_DIR}/.secret
ln_f ${GITLAB_DATA_DIR}/.secret ${GITLAB_DIR}/.secret

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

# Install Init Script
cp ${GITLAB_DIR}/lib/support/init.d/gitlab /etc/init.d/gitlab
cp ${GITLAB_DIR}/lib/support/logrotate/gitlab /etc/logrotate.d/gitlab
