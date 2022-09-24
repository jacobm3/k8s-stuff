#!/bin/bash
#
# This script runs nginx in a k8s namespace and service account,
# then outputs the Vault commands to configure JWT authentication
# for the nginx service account.
#
# It relies on the jwks2pem script in this same directory to 
# convert the JWKS key to PEM format, as required by Vault.
#

cat > demo-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ns-demo
EOF

kubectl apply -f demo-namespace.yaml


cat > demo-serviceaccount.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-demo
  namespace: ns-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ns-demo
  name: role-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rb-demo
  namespace: ns-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-demo
subjects:
- kind: ServiceAccount
  name: sa-demo
  namespace: ns-demo
EOF

kubectl apply -f demo-serviceaccount.yaml

cat > demo-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginxpod
  namespace: ns-demo
spec:
  containers:
  - image: nginx:latest
    name: nginxpod
  serviceAccountName: sa-demo
EOF

kubectl apply -f demo-pod.yaml

# Retry this until the nginx pod is ready
until kubectl exec --stdin --tty nginxpod --namespace ns-demo -- \
  cat /run/secrets/kubernetes.io/serviceaccount/token > k8s.token 2>/dev/null;
do sleep 0.5; done

# Get JWT signing CA cert
kubectl get --raw "$(kubectl get --raw /.well-known/openid-configuration | jq -r '.jwks_uri' )" | \
  jq -r .keys[0] | ./jwks2pem > k8s.pem

cat <<EOX

#
# Vault Setup Commands
#

vault auth enable jwt

vault write auth/jwt/config \\
   jwt_validation_pubkeys=@k8s.pem

vault policy write jwt-demo - <<EOF
path "secret/*" {
  capabilities = ["read", "update", "list", "delete"]
}
EOF

vault write auth/jwt/role/jwt-demo \\
   role_type="jwt" \\
   user_claim="sub" \\
   bound_subject="system:serviceaccount:ns-demo:sa-demo" \\
   policies="jwt-demo" \\
   ttl="1h"

vault write auth/jwt/login \\
   role=jwt-demo \\
   jwt=@k8s.token

EOX