# actions

For a working example see [kube-template](https://github.com/hckops/kube-template/blob/main/.github/workflows/kube-do.yml)

### kube-do-action

[![test-kube](https://github.com/hckops/actions/actions/workflows/test-kube.yml/badge.svg)](https://github.com/hckops/actions/actions/workflows/test-kube.yml)

> Manage DigitalOcean Kubernetes cluster lifecycle

Create or delete clusters based on a config definition
```diff
# examples/kube-do-sample.yaml
version: 1
name: do-sample
provider: digitalocean
+ status: UP
- status: DOWN

config:
  region: lon1
  size: s-1vcpu-2gb
  count: 1
```

Example
```bash
- name: Provision
  uses: hckops/actions/kube-do-action@main
  with:
    access-token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
    config-path: examples/kube-do-sample.yaml
    wait: true
```

Requires `DIGITALOCEAN_ACCESS_TOKEN` secret
* [How to Create a Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token)
* Create a [Personal Access Token](https://cloud.digitalocean.com/account/api/tokens)

How to test it locally
```bash
# build image
docker build -t hckops/kube-do-action ./kube-do-action

# run action
docker run --rm \
  -e GITHUB_REPOSITORY="INVALID_GITHUB_REPOSITORY" \
  hckops/kube-do-action \
  "INVALID_GITHUB_TOKEN" "INVALID_ACCESS_TOKEN" "./examples/kube-do-sample.yaml" \
  "false" "false" "false"
```

TODOs
- [ ] validate cluster definition `ClusterConfig`
- [ ] scheduler
    * reconcile cluster drift status
    * delete development clusters (add flag) after working hours
- [ ] try to remove `github-token` from inputs
- [ ] implementation: shell vs ???

### bootstrap-action

[![test-bootstrap](https://github.com/hckops/actions/actions/workflows/test-bootstrap.yml/badge.svg)](https://github.com/hckops/actions/actions/workflows/test-bootstrap.yml)

> Bootstrap a platform with ArgoCD

Example
```bash
- name: Bootstrap
  uses: hckops/actions/bootstrap-action@main
  with:
    gitops-ssh-key: ${{ secrets.GITOPS_SSH_KEY }}
    argocd-admin-password: ${{ secrets.ARGOCD_ADMIN_PASSWORD }}
    kubeconfig: <REPOSITORY_NAME>-kubeconfig.yaml
    chart-path: ./charts/argocd-config
    version: HEAD
```

Requires
* `GITOPS_SSH_KEY` secret
    - [Generate a new SSH key pair](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key)
    ```bash
    # generate ssh key pair
    ssh-keygen -t ed25519 -C "gitops@example.com" -N '' -f /tmp/id_ed25519_gitops

    # add public key to a github user account with access to the repo
    cat /tmp/id_ed25519_gitops.pub | xclip -selection clipboard

    # create secret with private key
    cat /tmp/id_ed25519_gitops | xclip -selection clipboard

    # cleanup
    rm /tmp/id_ed25519_gitops*
    ```
* `ARGOCD_ADMIN_PASSWORD` secret
    - [User Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management)
    - [How to change admin password](https://argo-cd.readthedocs.io/en/stable/faq/#i-forgot-the-admin-password-how-do-i-reset-it)

How to test it locally on minikube
```bash
# see "scripts/local.sh"
make bootstrap

# admin|argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### discord-action

[![test-discord](https://github.com/hckops/actions/actions/workflows/test-discord.yml/badge.svg)](https://github.com/hckops/actions/actions/workflows/test-discord.yml)

> Interact with Discord API

Example of *Create message*
```bash
- name: Notification
  uses: hckops/actions/discord-action@main
  with:
    action: create-message
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_URL }}
    message: "Hello World"
```

Requires `DISCORD_WEBHOOK_URL` secret
* [Intro to Webhooks](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)

How to test it locally
```bash
DISCORD_WEBHOOK_URL="INVALID_URL"
make discord-create webhook=${DISCORD_WEBHOOK_URL} message=test

docker build -t hckops/discord-action ./discord-action
docker run --rm hckops/discord-action "create-message" ${DISCORD_WEBHOOK_URL} "docker"
```

## Development

### Docker images

[![docker-ci](https://github.com/hckops/actions/actions/workflows/docker-ci.yml/badge.svg)](https://github.com/hckops/actions/actions/workflows/docker-ci.yml)

> Actions base images

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

### minikube

* [Documentation](https://minikube.sigs.k8s.io)

```bash
# install 
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

# local cluster
minikube start --driver=docker --embed-certs
minikube delete --all

# verify status
kubectl get nodes
```
