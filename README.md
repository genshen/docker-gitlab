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

## Database
For currently, only postgresql is supported.
### another note
In docker compose, 127.0.0.1 (and its reserved DNS name localhost) always refers to the current container, never the host.
So, in database config (file config/database.yml), the **host** term should set to postgresql container name.

So is the redis server hostname.

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

