# Exposing the K8s API using a Proxy

This repository contains K8s resources to deploy a TCP Proxy using Envoy or HAProxy to expose the K8s API for private clusters. This is necessary to be able to add private k8s cluster to an ArgoCD Instance. 

    Notes:
    - Currently ArgoCD doesn’t support HTTP Proxies to be able to add private k8 clusters.
    - You should need a Certificate to secure the network communication. These examples use a Self-signed certificated, but it should be signed by a trust CA. 

## How to use

### Create a self-signed certificate.

``` shell
mkdir certs
openssl genrsa 2048 > certs/key.pem
openssl req -new -x509 -nodes -sha1 -days 3650 -key certs/key.pem \
  -subj "/C=US/ST=CA/L=SF/O=PayPal/OU=dcos-kubernetes/CN=*" > certs/crt.pem

# Using HAProxy
cat certs/crt.pem certs/key.pem > certs/haproxy.pem
```

### Using Envoy Proxy

1. Update your Cluster endpoint or IP [here](envoy/config/envoy.yaml#L48).

2. Copy your certificate and key.

``` shell
cp certs/*.pem envoy/config
```

3. Deploy Envoy Proxy

``` shell
kubeclt apply -k envoy/ -n <your_namespace>
```

4. Get Service IP

``` shell
kubectl get services -n <your_namespace> envoy-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Using HAProxy Proxy

1. Update your Cluster endpoint or IP [here](haproxy/config/haproxy.cfg#L31).

2. Copy your certificate and key.

``` shell
cp certs/*.pem haproxy/config
```

3. Deploy HAProxy

``` shell
kubectl apply -k haproxy/ -n <your_namespace>
```

4. Get Service IP

``` shell
kubectl get services -n <your_namespace> haproxy-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Adding the Cluster to ArgoCD

1. Generate your Cluster yaml.

    Run this script in an environment where you have access to the K8s Cluster to add.

``` shell
# This script will create a SA, Cluster Role and Cluster Binding in your target cluster
# https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters
cd argocd
./get_cluster_yaml.sh
```

Check the new file **cluster.yaml** and edit the missing parameters (*envoy_or_haprxy_service*  and *your_cluster_name*)

2. Add the cluster to the ArgoCD Instance

    Run this script in an environment where you have access to the ArgoCD K8s Cluster.

``` shell
cd argocd
kubectl apply -f cluster.yaml
```

### Clean Up

``` shell
# Delete Envoy
kubeclt apply -k envoy/ -n <your_namespace>
# Delete HAProxy
kubeclt apply -k haproxy/ -n <your_namespace>
# Delete SA, Cluster Role and Cluster Binding
kubectl delete -f argocd/sa.yaml
```
