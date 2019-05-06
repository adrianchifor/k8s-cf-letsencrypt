# k8s-cf-letsencrypt

Provision Let's Encrypt TLS certificates using dns-01 challenge for Cloudflare and save them into a Kubernetes secret.

### Environment variables

- `DOMAINS` - comma-separated list of domains to provision certs for
- `LE_EMAIL` - email passed to Let's Encrypt for expiry notifications
- `CF_API_EMAIL` - Cloudflare account email
- `CF_API_KEY` - Cloudflare API key (do not hardcode in jobs spec, keep safe)
- `SECRET` - k8s secret where to save the provisioned certs
- `NAMESPACE` (optional) - the k8s namespace of `SECRET`, defaults to current namespace

## Setup

#### Prepare k8s secret

We create an empty k8s secret that will be filled in by the `cf-letsencrypt` job.

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: letsencrypt-certs
  namespace: default
type: Opaque
EOF
```

#### RBAC

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cf-letsencrypt
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: cf-letsencrypt
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create","patch"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: cf-letsencrypt
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cf-letsencrypt
subjects:
- kind: ServiceAccount
  name: cf-letsencrypt
  namespace: default
EOF
```

#### One-time Job

Store your Cloudflare email and API key in the `cloudflare` k8s Secret and create a k8s Job that will provision Let's Encrypt TLS certs for `DOMAINS`, registered with `LE_EMAIL` and save into the `SECRET` k8s Secret that we prepared above.

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare
  namespace: default
data:
  api-key: YOUR_CLOUDFLARE_API_KEY_BASE64
  email: YOUR_CLOUDFLARE_EMAIL_BASE64
type: Opaque
---
apiVersion: batch/v1
kind: Job
metadata:
  name: cf-letsencrypt
  namespace: default
  labels:
    app: cf-letsencrypt
spec:
  template:
    metadata:
      name: cf-letsencrypt
      labels:
        app: cf-letsencrypt
    spec:
      serviceAccountName: cf-letsencrypt
      restartPolicy: Never
      containers:
      - name: cf-letsencrypt
        image: quay.io/adrianchifor/k8s-cf-letsencrypt:master
        imagePullPolicy: Always
        resources:
          requests:
            cpu: 10m
            memory: 20Mi
        env:
        - name: DOMAINS
          value: example.com,www.example.com
        - name: LE_EMAIL
          value: email@example.com
        - name: CF_API_EMAIL
          valueFrom:
            secretKeyRef:
              name: cloudflare
              key: email
        - name: CF_API_KEY
          valueFrom:
            secretKeyRef:
              name: cloudflare
              key: api-key
        - name: SECRET
          value: letsencrypt-certs
EOF
```

#### Cron Job

Same thing as `One-time Job`, it just runs on a schedule as k8s CronJob.

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare
  namespace: default
data:
  api-key: YOUR_CLOUDFLARE_API_KEY_BASE64
  email: YOUR_CLOUDFLARE_EMAIL_BASE64
type: Opaque
---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: cf-letsencrypt
  namespace: default
  labels:
    app: cf-letsencrypt
spec:
  # Every month on 1st at 9am
  schedule: "0 9 1 * *"
  concurrencyPolicy: "Forbid"
  successfulJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          name: cf-letsencrypt
          labels:
            app: cf-letsencrypt
        spec:
          serviceAccountName: cf-letsencrypt
          restartPolicy: Never
          containers:
          - name: cf-letsencrypt
            image: quay.io/adrianchifor/k8s-cf-letsencrypt:master
            imagePullPolicy: Always
            resources:
              requests:
                cpu: 10m
                memory: 20Mi
            env:
            - name: DOMAINS
              value: example.com,www.example.com
            - name: LE_EMAIL
              value: email@example.com
            - name: CF_API_EMAIL
              valueFrom:
                secretKeyRef:
                  name: cloudflare
                  key: email
            - name: CF_API_KEY
              valueFrom:
                secretKeyRef:
                  name: cloudflare
                  key: api-key
            - name: SECRET
              value: letsencrypt-certs
EOF
```

## Usage

A common way to use the provisioned TLS certs k8s secret is with ingress controllers like:

```
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: example
spec:
  rules:
    - host: example.com
      http:
        paths:
        - path: /
          backend:
            serviceName: example
            servicePort: 80
  tls:
    - hosts:
      - example.com
      secretName: letsencrypt-certs
EOF
```
