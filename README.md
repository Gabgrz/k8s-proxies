# K8s API Proxies for Private Clusters

This repository contains Kubernetes resources to deploy TCP proxies using **Envoy** or **HAProxy** to expose the Kubernetes API for private clusters. This is necessary to add private Kubernetes clusters to an Argo CD instance.

## Overview

This solution addresses the limitation where Argo CD doesn't support HTTP proxies for adding private Kubernetes clusters. By using TCP proxies with TLS termination, you can securely expose your private cluster's API server to Argo CD.

### Key Features

- **Two Proxy Options**: Choose between Envoy or HAProxy based on your needs
- **TLS Security**: Secure communication with TLS certificates
- **Argo CD Integration**: Complete setup for adding private clusters to Argo CD
- **Production Ready**: Includes health checks, resource limits, and proper configuration

## Prerequisites

- Kubernetes cluster with kubectl access
- Argo CD instance running
- OpenSSL for certificate generation
- Access to the private cluster you want to add to ArgoCD

## Quick Start

### 1. Create TLS Certificates

Generate self-signed certificates (for production, use certificates signed by a trusted CA):

```bash
mkdir certs
openssl genrsa 2048 > certs/key.pem
openssl req -new -x509 -nodes -sha1 -days 3650 -key certs/key.pem > certs/crt.pem

# For HAProxy (combine cert and key)
cat certs/crt.pem certs/key.pem > certs/haproxy.pem
```

### 2. Choose Your Proxy

#### Option A: Envoy Proxy

1. **Update cluster endpoint** in `envoy/config/envoy.yaml` (line 48):
   ```yaml
   address: YOUR_CLUSTER_IP_OR_ENDPOINT
   ```

2. **Copy certificates**:
   ```bash
   cp certs/*.pem envoy/config/
   ```

3. **Deploy Envoy**:
   ```bash
   kubectl apply -k envoy/ -n <your_namespace>
   ```

4. **Get service IP**:
   ```bash
   kubectl get services -n <your_namespace> envoy-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

#### Option B: HAProxy

1. **Update cluster endpoint** in `haproxy/config/haproxy.cfg` (line 31):
   ```
   server kube-apiserver YOUR_CLUSTER_IP_OR_ENDPOINT:443 check ssl verify none
   ```

2. **Copy certificates**:
   ```bash
   cp certs/*.pem haproxy/config/
   ```

3. **Deploy HAProxy**:
   ```bash
   kubectl apply -k haproxy/ -n <your_namespace>
   ```

4. **Get service IP**:
   ```bash
   kubectl get services -n <your_namespace> haproxy-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

### 3. Add Cluster to Argo CD

1. **Generate cluster configuration** (run on the target cluster):
   ```bash
   cd argocd
   ./get_cluster_yaml.sh
   ```

2. **Edit the generated `cluster.yaml`**:
   - Replace `<your_cluster_name>` with your cluster name
   - Replace `<envoy_or_haproxy_service>` with the service IP from step 2

3. **Apply to Argo CD cluster**:
   ```bash
   kubectl apply -f cluster.yaml
   ```

## Configuration Details

### Envoy Configuration

- **Port**: 6443 (Kubernetes API standard)
- **TLS**: Terminates TLS and forwards to backend
- **Load Balancing**: Round-robin
- **Health Checks**: TCP socket check on port 6443

### HAProxy Configuration

- **Port**: 6443 (Kubernetes API standard)
- **TLS**: Terminates TLS and forwards to backend
- **Load Balancing**: Least connections
- **Health Checks**: SSL check with verification disabled

### Argo CD Integration

The `argocd/` directory contains:
- `sa.yaml`: ServiceAccount, ClusterRole, and ClusterRoleBinding for Argo CD
- `get_cluster_yaml.sh`: Script to generate Argo CD cluster secret
- Generated `cluster.yaml`: Argo CD cluster configuration

## Security Considerations

⚠️ **Important Security Notes**:

- These examples use self-signed certificates for simplicity
- **For production**: Use certificates signed by a trusted CA
- The HAProxy configuration disables SSL verification (`verify none`)
- Consider implementing proper certificate validation in production
- Review and adjust RBAC permissions in `argocd/sa.yaml` based on your security requirements

## Troubleshooting

### Common Issues

1. **Certificate errors**: Ensure certificates are properly mounted and accessible
2. **Connection refused**: Verify the target cluster IP/endpoint is correct
3. **Argo CD connection fails**: Check that the proxy service is accessible from Argo CD
4. **Permission denied**: Verify the ServiceAccount has proper RBAC permissions

### Debug Commands

```bash
# Check proxy logs
kubectl logs -n <namespace> deployment/envoy-proxy
kubectl logs -n <namespace> deployment/haproxy-server

# Test connectivity
kubectl port-forward -n <namespace> service/envoy-proxy 6443:6443
curl -k https://localhost:6443/version

# Check Argo CD cluster status
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
```

## Cleanup

To remove all resources:

```bash
# Delete proxy deployments
kubectl delete -k envoy/ -n <your_namespace>
kubectl delete -k haproxy/ -n <your_namespace>

# Delete Argo CD resources
kubectl delete -f argocd/sa.yaml
kubectl delete -f argocd/cluster.yaml
```