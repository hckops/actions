FROM hckops/kube-base:0.4.3

ENV PARAM_GITHUB_TOKEN=${GITHUB_TOKEN}

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
