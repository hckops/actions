# actions

## Development

***How to build and publish images manually***

* [DockerHub](https://hub.docker.com/u/hckops)
* [action](.github/workflows/docker-ci.yml)

```bash
make docker-build
make docker-publish version=v0.1.0 token=<ACCESS_TOKEN>
make docker-clean

# run command
docker run --rm hckops/kube-base /bin/bash -c <kubectl|helm|argocd>
# start temporary container
docker run --rm --name hck-kube -it hckops/kube-<base|aws|do>
```

***How to test action locally***

* [act](https://github.com/nektos/act)

```bash
# install
curl -sSL https://github.com/nektos/act/releases/download/v0.2.26/act_Linux_x86_64.tar.gz | sudo tar -xzf - -C /usr/local/bin
```
