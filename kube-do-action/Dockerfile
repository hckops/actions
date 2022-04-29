FROM alpine:3.15

RUN apk upgrade --update && apk --no-cache add \
  bash \
  git

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
