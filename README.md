## Build docker images
<!--
            lang       statue   note     config  make
shell       ruby+go    ?                         ./bin/install; ./bin/compile;
workhorse   go         okk               redis   make install PREFIX=xxx
pages       go         okk               cmd arg make, and copy bin dir.
gitaly      go+ruby    okk      git              make install [PREFIX=xxx]; make to download and compile Ruby dependencies, and to compile the Go binary.
gitlab      ruby
-->
```bash
cd builder
docker build --rm -t genshen/gitlab-base-builder .
cd ../gitlab-shell
docker build --rm -t genshen/gitlab-shell-builder .
cd ../gitlab-workhorse
docker build --rm -t genshen/gitlab-workhorse-builder .
cd ../gitlab-pages
docker build --rm -t genshen/gitlab-pages-builder .
cd ../gitaly
docker build --rm -t genshen/gitlab-gitaly-builder .
cd ../gitlab
docker build --rm -t genshen/gitlab-builder .
# building intermediate images finished.
cd ../
docker build --rm -t genshen/gitlab .
```

## Configure notice.
### Database
For currently, only postgresql is supported.

In docker compose, 127.0.0.1 (and its reserved DNS name localhost) always refers to the current container, never the host.
So, in database config (file config/database.yml), the **host** term should set to postgresql container name.

So is the redis server hostname.

### gitlab-workhorse
In entrypoint of this gitlab image, the path of file *.gitlab_workhorse_secret* is set to be `${GITLAB_WORKHORSE_DIR}/.gitlab_workhorse_secret` (${GITLAB_WORKHORSE_DIR} is usually /home/git/gitlab-workhorse).  
if .gitlab_workhorse_secret file path is not configured correctly, the clone will return http 500 error when using http(s) protocol.  
You should also config .gitlab_workhorse_secret file path in config file `config/gitlab.yml`.  

## data map
Following directory are soft linked to ${GITLAB_DATA_DIR}, ${GITLAB_LOG_DIR} or ${GITLAB_CONFIG_DIR}.

> default, ${GITLAB_HOME} is /home/git; ${GITLAB_DIR} is ${GITLAB_HOME}/gitlab

sshd host key                ->  ${GITLAB_DATA_DIR}/ssh
${GITLAB_HOME}/repositories  ->  ${GITLAB_DATA_DIR}/repositories
${GITLAB_HOME}/.ssh          ->  ${GITLAB_DATA_DIR}/.ssh

${GITLAB_DIR}/builds         ->  ${GITLAB_DATA_DIR}/builds
${GITLAB_DIR}/public/uploads ->  ${GITLAB_DATA_DIR}/public/uploads
${GITLAB_DIR}/shared         ->  ${GITLAB_DATA_DIR}/shared
${GITLAB_DIR}/tmp            ->  ${GITLAB_DATA_DIR}/tmp

${GITLAB_DIR}/log            ->  ${GITLAB_LOG_DIR}/gitlab/
${GITLAB_SHELL_DIR}/gitlab-shell.log ->  ${GITLAB_LOG_DIR}/gitlab/gitlab-shell.log
sshd log                     ->  ${GITLAB_LOG_DIR}/sshd.log

${GITLAB_DIR}/config         ->  ${GITLAB_CONFIG_DIR}

## Run gitlab
Run `docker-compose up` command, the gitlab-workhorse will listen on tcp port 8181. You can alse change environment variable `WORKHORSE_LISTEN_NETWORK` from "unix" (default value is "tcp") to let gitlab-workhorse listen unix socket `${GITLAB_DATA_DIR}/tmp/sockets/gitlab.socket`.
