#/bin/bash

# Create Service Account and Binding Role
kubectl apply -f sa.yaml

# Get Bearer Token
name=$(kubectl get sa -n kube-system argocd-manager -o jsonpath='{.secrets[0].name}')
token=$(kubectl get -n kube-system secret/$name -o jsonpath='{.data.token}' | base64 --decode)

# Print Cluster Resource
cluster=$(cat << EOF 
apiVersion: v1
kind: Secret
metadata:
  name: <your_cluster_name>
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: <your_cluster_name>
  server: https://<envoy_or_haprxy_service>:6443
  config: |
    {
      "bearerToken": "$token",
      "tlsClientConfig": {
        "insecure": true
      }
    }
EOF
)

echo "$cluster" > cluster.yaml
