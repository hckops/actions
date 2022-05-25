FROM alpine:3.16

RUN apk upgrade --update && apk --no-cache add \
  bash \
  curl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
