FROM python:3.7-alpine

RUN apk add --no-cache bash \
  && apk add --no-cache --virtual build-dependencies gcc g++ musl-dev libffi-dev openssl-dev \
  && pip install certbot-dns-cloudflare \
  && apk del build-dependencies \
  && rm -r /root/.cache

RUN mkdir /etc/letsencrypt

COPY certbot.sh /
COPY secret-template.json /

CMD ["bash", "/certbot.sh"]
