# actions

### discord-action

> TODO

```bash
DISCORD_WEBHOOK_URL="INVALID_URL"
make discord-create webhook=${DISCORD_WEBHOOK_URL} message=test

docker build -t hckops/discord-action ./discord-action
docker run --rm hckops/discord-action "create-message" ${DISCORD_WEBHOOK_URL} "docker"
```

### kube-do-action

> TODO

```bash
docker build -t hckops/kube-do-action ./kube-do-action
docker run --rm \
  -e GITHUB_REPOSITORY="INVALID_GITHUB_REPOSITORY" \
  hckops/kube-do-action \
  "INVALID_GITHUB_TOKEN" "INVALID_ACCESS_TOKEN" "./examples/kube-do-sample.yaml" "false" "false"
```

### bootstrap-action

> TODO

```bash
docker build -t hckops/bootstrap-action ./bootstrap-action
docker run --rm hckops/bootstrap-action
```

## Development

### Docker images

* [DockerHub](https://hub.docker.com/u/hckops)

```bash
# run command
docker run --rm hckops/kube-base /bin/bash -c <kubectl|helm|argocd>
# start temporary container
docker run --rm --name hck-kube -it hckops/kube-<base|aws|do>
```

How to build and publish images manually
```bash
make docker-build
make docker-publish version=v0.1.0 token=<ACCESS_TOKEN>
make docker-clean
```
