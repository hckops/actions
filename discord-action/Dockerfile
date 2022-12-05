FROM alpine:3.17

RUN apk upgrade --update && apk --no-cache add \
  bash \
  curl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
