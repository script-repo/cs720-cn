# Docker Container Export and Kubernetes Deployment Guide

This guide provides step-by-step instructions for exporting a running Docker container, storing it in a container registry, and deploying it to Kubernetes using kubectl.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Part 1: Export Running Docker Container](#part-1-export-running-docker-container)
3. [Part 2: Push to Container Registry](#part-2-push-to-container-registry)
4. [Part 3: Create Kubernetes Manifests](#part-3-create-kubernetes-manifests)
5. [Part 4: Deploy to Kubernetes](#part-4-deploy-to-kubernetes)
6. [Part 5: Verify and Manage Deployment](#part-5-verify-and-manage-deployment)
7. [Complete Example: CS720 Backend Service](#complete-example-cs720-backend-service)

---

## Prerequisites

### Required Tools

- Docker installed and running
- kubectl installed and configured
- Access to a Kubernetes cluster
- Access to a container registry (Docker Hub, GHCR, GCR, ECR, etc.)
- Registry credentials

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker ps

# Check kubectl
kubectl version --client
kubectl cluster-info

# Check cluster access
kubectl get nodes
```

---

## Part 1: Export Running Docker Container

### Step 1: Identify the Running Container

First, list all running containers to identify the one you want to export:

```bash
# List all running containers
docker ps

# Or filter by name
docker ps | grep backend
```

Example output:
```
CONTAINER ID   IMAGE                    COMMAND       CREATED       STATUS       PORTS                    NAMES
a1b2c3d4e5f6   cs720-backend:fixed-v2   "node app.js" 2 hours ago   Up 2 hours   0.0.0.0:3001->3001/tcp   cs720-backend
```

Note the `CONTAINER ID` or `NAMES` for the next steps.

### Step 2: Commit the Running Container to an Image

Create a new image from the running container. This captures the current state including any changes made since the container started.

```bash
# Syntax: docker commit [OPTIONS] CONTAINER [REPOSITORY[:TAG]]
docker commit cs720-backend cs720-backend:export-v1

# With metadata (recommended)
docker commit \
  --author "Your Name <your.email@example.com>" \
  --message "Exported working backend with all fixes" \
  cs720-backend cs720-backend:export-v1
```

**Important Notes:**
- This creates a new image layer on top of the base image
- Includes file system changes but NOT volume data
- Running processes are paused during commit

### Step 3: Verify the New Image

```bash
# List Docker images
docker images | grep cs720-backend

# Inspect the image
docker inspect cs720-backend:export-v1

# Check image size
docker images cs720-backend:export-v1 --format "{{.Size}}"
```

### Step 4: (Optional) Save Image as TAR File

For backup or offline transfer:

```bash
# Save single image
docker save cs720-backend:export-v1 -o cs720-backend-export-v1.tar

# Save compressed (recommended)
docker save cs720-backend:export-v1 | gzip > cs720-backend-export-v1.tar.gz

# Verify the file
ls -lh cs720-backend-export-v1.tar.gz
```

**To load later:**
```bash
# Load from tar file
docker load -i cs720-backend-export-v1.tar.gz

# Verify
docker images | grep cs720-backend
```

---

## Part 2: Push to Container Registry

### Option A: GitHub Container Registry (GHCR)

#### Step 1: Create Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with scopes:
   - `write:packages`
   - `read:packages`
   - `delete:packages` (optional)
3. Copy the token (you won't see it again)

#### Step 2: Login to GHCR

```bash
# Set your token as environment variable
export GITHUB_TOKEN=ghp_your_token_here

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Expected output:
```
Login Succeeded
```

#### Step 3: Tag Image for GHCR

```bash
# Syntax: ghcr.io/OWNER/IMAGE_NAME:TAG
docker tag cs720-backend:export-v1 ghcr.io/your-username/cs720-backend:export-v1

# Also tag as latest (optional)
docker tag cs720-backend:export-v1 ghcr.io/your-username/cs720-backend:latest
```

#### Step 4: Push to GHCR

```bash
# Push specific version
docker push ghcr.io/your-username/cs720-backend:export-v1

# Push latest tag
docker push ghcr.io/your-username/cs720-backend:latest
```

#### Step 5: Make Package Public (Optional)

1. Go to GitHub → Your profile → Packages
2. Find your package
3. Package settings → Change visibility → Public

### Option B: Docker Hub

#### Step 1: Login to Docker Hub

```bash
docker login

# Or specify username
docker login -u your-dockerhub-username
```

#### Step 2: Tag and Push

```bash
# Tag image (Docker Hub uses your username as namespace)
docker tag cs720-backend:export-v1 your-dockerhub-username/cs720-backend:export-v1

# Push to Docker Hub
docker push your-dockerhub-username/cs720-backend:export-v1
```

### Option C: Private Registry

```bash
# Login to private registry
docker login registry.example.com -u username

# Tag for private registry
docker tag cs720-backend:export-v1 registry.example.com/cs720-backend:export-v1

# Push
docker push registry.example.com/cs720-backend:export-v1
```

### Verify Push

```bash
# Pull from registry to verify
docker pull ghcr.io/your-username/cs720-backend:export-v1

# Or check via curl (for public images)
curl -L https://ghcr.io/v2/your-username/cs720-backend/tags/list
```

---

## Part 3: Create Kubernetes Manifests

### Understanding Kubernetes Resources

For a typical application deployment, you'll need:
1. **Namespace** (optional, for organization)
2. **Deployment** (manages pods and replicas)
3. **Service** (exposes deployment to network)
4. **ConfigMap** (configuration data)
5. **Secret** (sensitive data)
6. **PersistentVolumeClaim** (persistent storage, if needed)

### Step 1: Create Namespace (Optional)

```bash
# Create namespace via kubectl
kubectl create namespace cs720

# Or create manifest file: namespace.yaml
```

**namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cs720
  labels:
    name: cs720
    environment: production
```

### Step 2: Create ConfigMap

Store non-sensitive configuration:

**backend-configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: cs720
data:
  NODE_ENV: "production"
  PORT: "3001"
  OLLAMA_BASE_URL: "http://ollama-service:11434"
  OLLAMA_MODEL: "gemma2:2b-instruct-q4_K_M"
  PROXY_URL: "http://proxy-service:3002/proxy"
```

### Step 3: Create Secret

Store sensitive data (base64 encoded):

```bash
# Create secret from literal values
kubectl create secret generic backend-secrets \
  --from-literal=DATABASE_URL='postgresql://cs720:cs720_dev_password@postgres-service:5432/cs720' \
  --from-literal=JWT_SECRET='your-secret-key-change-in-production' \
  --namespace=cs720
```

**Or create manifest file (backend-secret.yaml):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: cs720
type: Opaque
data:
  # Base64 encoded values (use: echo -n 'value' | base64)
  DATABASE_URL: cG9zdGdyZXNxbDovL2NzNzIwOmNzNzIwX2Rldl9wYXNzd29yZEBwb3N0Z3Jlcy1zZXJ2aWNlOjU0MzIvY3M3MjA=
  JWT_SECRET: eW91ci1zZWNyZXQta2V5LWNoYW5nZS1pbi1wcm9kdWN0aW9u
```

**Encode secrets:**
```bash
echo -n 'your-database-url' | base64
echo -n 'your-jwt-secret' | base64
```

### Step 4: Create Deployment Manifest

**backend-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
  namespace: cs720
  labels:
    app: backend
    tier: application
spec:
  replicas: 2  # Number of pod replicas
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: application
    spec:
      # Pull image from registry
      imagePullSecrets:
        - name: ghcr-secret  # For private registries

      containers:
      - name: backend
        image: ghcr.io/your-username/cs720-backend:export-v1
        imagePullPolicy: Always

        ports:
        - containerPort: 3001
          name: http
          protocol: TCP

        # Environment variables from ConfigMap
        envFrom:
        - configMapRef:
            name: backend-config

        # Environment variables from Secret
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: DATABASE_URL
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: JWT_SECRET

        # Resource limits
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"

        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 20
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

        # Volume mounts (if needed)
        volumeMounts:
        - name: data-volume
          mountPath: /data
          readOnly: true

      # Volumes
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: data-pvc

      # Restart policy
      restartPolicy: Always
```

### Step 5: Create Service Manifest

**backend-service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: cs720
  labels:
    app: backend
spec:
  type: ClusterIP  # Internal service (use LoadBalancer for external)
  selector:
    app: backend
  ports:
  - name: http
    protocol: TCP
    port: 3001        # Service port
    targetPort: 3001  # Container port
  sessionAffinity: None
```

**For external access, use LoadBalancer or NodePort:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service-external
  namespace: cs720
spec:
  type: LoadBalancer  # Or NodePort
  selector:
    app: backend
  ports:
  - name: http
    protocol: TCP
    port: 80          # External port
    targetPort: 3001  # Container port
    # nodePort: 30001 # For NodePort type (30000-32767)
```

### Step 6: Create PersistentVolumeClaim (If Needed)

**data-pvc.yaml:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: cs720
spec:
  accessModes:
    - ReadOnlyMany  # Or ReadWriteOnce, ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard  # Depends on your cluster
```

### Step 7: Create Image Pull Secret (For Private Registries)

```bash
# Create Docker registry secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=your-email@example.com \
  --namespace=cs720
```

---

## Part 4: Deploy to Kubernetes

### Step 1: Organize Manifests

Create a directory structure:

```bash
mkdir -p k8s/base
cd k8s/base

# Move or create all manifest files here
# - namespace.yaml
# - backend-configmap.yaml
# - backend-secret.yaml
# - backend-deployment.yaml
# - backend-service.yaml
# - data-pvc.yaml
```

### Step 2: Apply Manifests in Order

```bash
# 1. Create namespace first
kubectl apply -f namespace.yaml

# 2. Create ConfigMap and Secrets
kubectl apply -f backend-configmap.yaml
kubectl apply -f backend-secret.yaml

# 3. Create PVC (if needed)
kubectl apply -f data-pvc.yaml

# 4. Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=$GITHUB_TOKEN \
  --namespace=cs720

# 5. Create Deployment
kubectl apply -f backend-deployment.yaml

# 6. Create Service
kubectl apply -f backend-service.yaml
```

### Step 3: Apply All at Once (Alternative)

```bash
# Apply all manifests in directory
kubectl apply -f k8s/base/

# Or apply recursively
kubectl apply -R -f k8s/
```

### Step 4: Deploy with Kustomize (Recommended for Multiple Environments)

Create `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cs720

resources:
  - namespace.yaml
  - backend-configmap.yaml
  - backend-secret.yaml
  - backend-deployment.yaml
  - backend-service.yaml
  - data-pvc.yaml

images:
  - name: ghcr.io/your-username/cs720-backend
    newTag: export-v1
```

**Deploy with Kustomize:**
```bash
kubectl apply -k k8s/base/
```

---

## Part 5: Verify and Manage Deployment

### Verify Deployment

```bash
# Check namespace
kubectl get namespace cs720

# Check all resources in namespace
kubectl get all -n cs720

# Check deployment status
kubectl get deployment backend-deployment -n cs720

# Check pods
kubectl get pods -n cs720
kubectl get pods -n cs720 -w  # Watch mode

# Check services
kubectl get service backend-service -n cs720

# Check ConfigMaps and Secrets
kubectl get configmap -n cs720
kubectl get secret -n cs720

# Check PVC
kubectl get pvc -n cs720
```

### Check Pod Details

```bash
# Describe deployment
kubectl describe deployment backend-deployment -n cs720

# Describe pod
kubectl describe pod <pod-name> -n cs720

# View pod logs
kubectl logs <pod-name> -n cs720

# Follow logs
kubectl logs -f <pod-name> -n cs720

# Logs from all pods with label
kubectl logs -l app=backend -n cs720 --all-containers=true
```

### Check Service Endpoint

```bash
# Get service details
kubectl get service backend-service -n cs720

# Describe service
kubectl describe service backend-service -n cs720

# Get endpoints
kubectl get endpoints backend-service -n cs720

# For LoadBalancer, get external IP
kubectl get service backend-service-external -n cs720
```

### Test the Deployment

```bash
# Port forward to test locally
kubectl port-forward -n cs720 service/backend-service 3001:3001

# Test in another terminal
curl http://localhost:3001/health

# Or port forward to a pod
kubectl port-forward -n cs720 <pod-name> 3001:3001
```

### Scaling

```bash
# Scale deployment
kubectl scale deployment backend-deployment --replicas=3 -n cs720

# Verify scaling
kubectl get pods -n cs720 -w

# Auto-scaling (HPA)
kubectl autoscale deployment backend-deployment \
  --min=2 --max=10 --cpu-percent=80 \
  -n cs720
```

### Update Deployment

```bash
# Update image to new version
kubectl set image deployment/backend-deployment \
  backend=ghcr.io/your-username/cs720-backend:export-v2 \
  -n cs720

# Check rollout status
kubectl rollout status deployment/backend-deployment -n cs720

# View rollout history
kubectl rollout history deployment/backend-deployment -n cs720

# Rollback to previous version
kubectl rollout undo deployment/backend-deployment -n cs720

# Rollback to specific revision
kubectl rollout undo deployment/backend-deployment --to-revision=2 -n cs720
```

### Troubleshooting

```bash
# Check events
kubectl get events -n cs720 --sort-by='.lastTimestamp'

# Check pod events
kubectl describe pod <pod-name> -n cs720 | grep -A 10 Events

# Execute command in pod
kubectl exec -it <pod-name> -n cs720 -- /bin/sh
kubectl exec -it <pod-name> -n cs720 -- env

# Check resource usage
kubectl top pods -n cs720
kubectl top nodes

# Debug with temporary pod
kubectl run debug --image=busybox -it --rm -n cs720 -- /bin/sh
```

### Cleanup

```bash
# Delete specific resources
kubectl delete deployment backend-deployment -n cs720
kubectl delete service backend-service -n cs720

# Delete all resources in namespace
kubectl delete all --all -n cs720

# Delete entire namespace (including all resources)
kubectl delete namespace cs720

# Or delete using manifest files
kubectl delete -f k8s/base/
```

---

## Complete Example: CS720 Backend Service

Here's a complete, real-world example deploying the CS720 backend service.

### Directory Structure

```
k8s/
├── base/
│   ├── namespace.yaml
│   ├── postgres/
│   │   ├── postgres-configmap.yaml
│   │   ├── postgres-secret.yaml
│   │   ├── postgres-pvc.yaml
│   │   ├── postgres-deployment.yaml
│   │   └── postgres-service.yaml
│   ├── backend/
│   │   ├── backend-configmap.yaml
│   │   ├── backend-secret.yaml
│   │   ├── backend-deployment.yaml
│   │   └── backend-service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── development/
    └── production/
```

### Complete Manifests

**k8s/base/namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cs720
  labels:
    name: cs720
    environment: production
```

**k8s/base/postgres/postgres-secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: cs720
type: Opaque
data:
  POSTGRES_USER: Y3M3MjA=  # cs720
  POSTGRES_PASSWORD: Y3M3MjBfZGV2X3Bhc3N3b3Jk  # cs720_dev_password
  POSTGRES_DB: Y3M3MjA=  # cs720
```

**k8s/base/postgres/postgres-pvc.yaml:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: cs720
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

**k8s/base/postgres/postgres-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: cs720
  labels:
    app: postgres
    tier: database
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - secretRef:
            name: postgres-secrets
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - cs720
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - cs720
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

**k8s/base/postgres/postgres-service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: cs720
  labels:
    app: postgres
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - name: postgres
    protocol: TCP
    port: 5432
    targetPort: 5432
```

**k8s/base/backend/backend-configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: cs720
data:
  NODE_ENV: "production"
  PORT: "3001"
  OLLAMA_BASE_URL: "http://ollama-service:11434"
  OLLAMA_MODEL: "gemma2:2b-instruct-q4_K_M"
  PROXY_URL: "http://proxy-service:3002/proxy"
```

**k8s/base/backend/backend-secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: cs720
type: Opaque
data:
  DATABASE_URL: cG9zdGdyZXNxbDovL2NzNzIwOmNzNzIwX2Rldl9wYXNzd29yZEBwb3N0Z3Jlcy1zZXJ2aWNlOjU0MzIvY3M3MjA=
  JWT_SECRET: eW91ci1zZWNyZXQta2V5LWNoYW5nZS1pbi1wcm9kdWN0aW9u
```

**k8s/base/backend/backend-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: cs720
  labels:
    app: backend
    tier: application
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: application
    spec:
      imagePullSecrets:
      - name: ghcr-secret

      initContainers:
      - name: wait-for-postgres
        image: busybox:1.35
        command: ['sh', '-c', 'until nc -z postgres-service 5432; do echo waiting for postgres; sleep 2; done']

      containers:
      - name: backend
        image: ghcr.io/your-username/cs720-backend:export-v1
        imagePullPolicy: Always
        ports:
        - containerPort: 3001
          name: http
        envFrom:
        - configMapRef:
            name: backend-config
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: DATABASE_URL
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: JWT_SECRET
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 20
          periodSeconds: 5
          timeoutSeconds: 3
```

**k8s/base/backend/backend-service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: cs720
  labels:
    app: backend
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 3001
```

**k8s/base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cs720

resources:
  - namespace.yaml
  - postgres/postgres-secret.yaml
  - postgres/postgres-pvc.yaml
  - postgres/postgres-deployment.yaml
  - postgres/postgres-service.yaml
  - backend/backend-configmap.yaml
  - backend/backend-secret.yaml
  - backend/backend-deployment.yaml
  - backend/backend-service.yaml
```

### Deployment Commands

```bash
# 1. Export running container
docker commit cs720-backend cs720-backend:export-v1

# 2. Tag for GHCR
docker tag cs720-backend:export-v1 ghcr.io/your-username/cs720-backend:export-v1

# 3. Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin

# 4. Push to registry
docker push ghcr.io/your-username/cs720-backend:export-v1

# 5. Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=$GITHUB_TOKEN \
  --namespace=cs720

# 6. Deploy to Kubernetes
kubectl apply -k k8s/base/

# 7. Watch deployment
kubectl get pods -n cs720 -w

# 8. Check status
kubectl get all -n cs720

# 9. Get service endpoint
kubectl get service backend-service -n cs720

# 10. Test the deployment
kubectl port-forward -n cs720 service/backend-service 3001:80
curl http://localhost:3001/health
```

### Monitoring

```bash
# Watch pods
watch kubectl get pods -n cs720

# Stream logs
kubectl logs -f -l app=backend -n cs720

# Check resource usage
kubectl top pods -n cs720
```

---

## Best Practices

### Security

1. **Never commit secrets** - Use Kubernetes Secrets or external secret managers
2. **Use private registries** - Keep images in private registries when possible
3. **Scan images** - Use tools like Trivy or Snyk to scan for vulnerabilities
4. **Use RBAC** - Implement role-based access control
5. **Network policies** - Restrict pod-to-pod communication
6. **Run as non-root** - Configure containers to run as non-root users

### Image Management

1. **Use specific tags** - Avoid `latest` tag in production
2. **Version images** - Use semantic versioning (v1.0.0)
3. **Multi-stage builds** - Optimize image size with multi-stage Dockerfiles
4. **Layer caching** - Order Dockerfile commands for better caching
5. **Image cleanup** - Regularly clean up unused images

### Kubernetes

1. **Resource limits** - Always set resource requests and limits
2. **Health checks** - Implement liveness and readiness probes
3. **Rolling updates** - Use rolling update strategy for zero-downtime
4. **Namespaces** - Organize resources with namespaces
5. **Labels** - Use consistent labeling strategy
6. **ConfigMaps/Secrets** - Separate configuration from code
7. **PV lifecycle** - Understand PV reclaim policies

### Monitoring and Logging

1. **Centralized logging** - Use ELK/EFK stack or cloud logging
2. **Metrics** - Implement Prometheus and Grafana
3. **Alerts** - Set up alerting for critical issues
4. **Distributed tracing** - Use Jaeger or similar for microservices

---

## Troubleshooting Guide

### Image Pull Errors

```bash
# Check image pull secret
kubectl get secret ghcr-secret -n cs720 -o yaml

# Recreate secret
kubectl delete secret ghcr-secret -n cs720
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=$GITHUB_TOKEN \
  --namespace=cs720

# Check pod events
kubectl describe pod <pod-name> -n cs720
```

### CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n cs720
kubectl logs <pod-name> -n cs720 --previous

# Check environment variables
kubectl exec <pod-name> -n cs720 -- env

# Describe pod for events
kubectl describe pod <pod-name> -n cs720
```

### Service Not Accessible

```bash
# Check service
kubectl get service -n cs720
kubectl describe service backend-service -n cs720

# Check endpoints
kubectl get endpoints backend-service -n cs720

# Check pod labels
kubectl get pods -n cs720 --show-labels

# Test from within cluster
kubectl run test --image=busybox -it --rm -n cs720 -- wget -O- http://backend-service:3001/health
```

### Persistent Volume Issues

```bash
# Check PVC status
kubectl get pvc -n cs720
kubectl describe pvc postgres-pvc -n cs720

# Check PV
kubectl get pv

# Check storage class
kubectl get storageclass
```

---

## Additional Resources

### Official Documentation

- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kustomize Documentation](https://kustomize.io/)

### Tools

- **k9s** - Terminal UI for Kubernetes
- **Lens** - Kubernetes IDE
- **Helm** - Package manager for Kubernetes
- **ArgoCD** - GitOps continuous delivery tool
- **Terraform** - Infrastructure as Code

### Commands Quick Reference

```bash
# Docker
docker ps                                  # List containers
docker images                              # List images
docker commit CONTAINER IMAGE:TAG          # Create image from container
docker save IMAGE | gzip > file.tar.gz     # Save image to file
docker load -i file.tar.gz                 # Load image from file
docker tag SOURCE TARGET                   # Tag image
docker push IMAGE:TAG                      # Push to registry

# kubectl
kubectl get pods -n NAMESPACE              # List pods
kubectl describe pod POD -n NAMESPACE      # Describe pod
kubectl logs POD -n NAMESPACE              # View logs
kubectl exec -it POD -n NAMESPACE -- sh    # Execute shell in pod
kubectl apply -f manifest.yaml             # Apply manifest
kubectl delete -f manifest.yaml            # Delete resources
kubectl port-forward svc/SERVICE PORT      # Port forward
kubectl scale deployment DEPLOY --replicas=N  # Scale deployment
kubectl rollout status deployment DEPLOY   # Check rollout status
kubectl rollout undo deployment DEPLOY     # Rollback deployment
```

---

## Conclusion

This guide covered the complete workflow from exporting a running Docker container to deploying it on Kubernetes. The key steps are:

1. Export container using `docker commit`
2. Push image to container registry (GHCR, Docker Hub, etc.)
3. Create Kubernetes manifests (Deployment, Service, ConfigMap, Secret)
4. Deploy to Kubernetes using `kubectl apply`
5. Verify and monitor the deployment

Remember to follow best practices for security, resource management, and monitoring in production environments.
