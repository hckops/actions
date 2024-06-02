FROM hckops/kube-base

# https://github.com/digitalocean/doctl/releases
ARG DOCTL_VERSION=1.107.0

# doctl
RUN curl -sSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" | tar -xzf - -C /usr/local/bin && \
  doctl version
