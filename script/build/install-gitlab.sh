#!/bin/bash
# set -e

# https://docs.gitlab.com/ee/install/installation.html#1-packages-dependencies
apt-get update
# install ca-certificates apt-transport-https packages for downloading from https website.
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y sudo wget git-core postfix ca-certificates apt-transport-https \
    build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libre2-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate rsync python-docutils pkg-config cmake

## install golang
wget ${GOLANG_DOWNLOAD_URL} -O /tmp/golang.tar.gz
tar -C /usr/local -xzvf /tmp/golang.tar.gz
export GOROOT=/usr/local/go
export PATH=$PATH:/usr/local/go/bin

## install ruby
wget ${RUBY_DOWNLOAD_RUL} -O /tmp/ruby.tar.gz
tar -C /tmp/ruby-src -xzvf /tmp/ruby.tar.gz
cd /tmp ruby
./configure
make ${BUILD_PROS}
make install

## install nodejs
wget ${NODEJS_DOWNLOAD_URL} -O /tmp/node.tar.xz
mkdir /usr/local/node
tar -xvf /tmp/node.tar.xz -C /usr/local --strip-components=1
export PATH=/usr/local/node/bin:~/.yarn/bin:$PATH
npm install --global yarn

# remove the host keys generated during openssh-server installation
rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# add ${GITLAB_USER} user
adduser --gecos 'GitLab' ${GITLAB_USER}
passwd -d ${GITLAB_USER}
