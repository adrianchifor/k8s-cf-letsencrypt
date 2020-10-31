FROM python:3.7-alpine

LABEL org.opencontainers.image.source https://github.com/adrianchifor/k8s-cf-letsencrypt

RUN apk add --no-cache bash curl \
  && apk add --no-cache --virtual build-dependencies gcc g++ musl-dev libffi-dev openssl-dev \
  && pip install certbot-dns-cloudflare \
  && apk del build-dependencies \
  && rm -r /root/.cache

RUN mkdir /etc/letsencrypt

COPY certbot.sh /
COPY secret-template.json /

CMD ["bash", "/certbot.sh"]
