#!/bin/bash

# https://dev.to/thenjdevopsguy/creating-a-kubernetes-service-account-to-run-pods-3ef9

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

kubectl exec --stdin --tty nginxpod --namespace ns-demo -- /bin/bash <<EOF
echo
echo token:
cat /run/secrets/kubernetes.io/serviceaccount/token
echo
echo
echo ca.crt:
cat /run/secrets/kubernetes.io/serviceaccount/ca.crt
echo
echo
echo namespace:
cat /run/secrets/kubernetes.io/serviceaccount/namespace
echo
echo
EOF



