## Build docker images
```bash
cd builder
docker build --rm -t genshen/gitlab-builder  .
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
```