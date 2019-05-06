#!/usr/bin/env bash

if [[ -z $DOMAINS || -z $LE_EMAIL || -z $CF_API_EMAIL || -z $CF_API_KEY || -z $SECRET ]]; then
  echo "DOMAINS, LE_EMAIL, CF_API_EMAIL, CF_API_KEY, SECRET environment variables required"
  exit 1
fi

CURRENT_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
NAMESPACE=${NAMESPACE:-$CURRENT_NAMESPACE}

cat <<EOF > /cloudflare.ini
dns_cloudflare_email = ${CF_API_EMAIL}
dns_cloudflare_api_key = ${CF_API_KEY}
EOF

ls /cloudflare.ini || exit 1
chmod 600 /cloudflare.ini

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare.ini \
  -n --agree-tos -m ${LE_EMAIL} -d ${DOMAINS}

CERTPATH=/etc/letsencrypt/live/$(echo ${DOMAINS} | cut -f1 -d',')

ls ${CERTPATH} || exit 1

cat /secret-template.json | \
  sed "s/NAMESPACE/${NAMESPACE}/" | \
  sed "s/NAME/${SECRET}/" | \
  sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
  sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem | base64 | tr -d '\n')/" \
  > /secret-patch.json

ls /secret-patch.json || exit 1

curl -v -k --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -XPATCH \
  -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  -H "Accept: application/json, */*" \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -d @/secret-patch.json https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET} > /dev/null
