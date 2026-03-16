# SmartCity FIWARE Platform


This repository provides the Helm charts, configurations, and deployment scripts to provision a complete FIWARE-based Smart City ecosystem on a Kubernetes cluster.

## Required Tools

To deploy and manage this platform, you need the following tools installed on your system:

1. **Docker**: Container engine, necessary if you are running a local cluster via `kind`.
2. **Kubernetes CLI (`kubectl`)**: Required for interacting with the cluster.
3. **Helm (v3+)**: The Kubernetes package manager used for templating and deploying the platform components.
4. **Kind** (or **K3s**): Recommended for spinning up a local development cluster.
5. **Git**: Used for fetching the charts and GitOps synchronization via ArgoCD.

## Deployment Instructions

Follow these steps to deploy the FIWARE ecosystem:

### 1. Provision a Kubernetes Cluster
If you do not have a cluster running, you can create a local one using `kind`:
```bash
chmod +x ./scripts/01-create-cluster.sh
./scripts/01-create-cluster.sh
```

### 2. Deploy the Platform (ArgoCD + Umbrella Chart)
This script will install ArgoCD into the cluster and apply the central `platform` umbrella chart, which configures all other dependencies.
```bash
chmod +x ./scripts/03-deploy-platform.sh
./scripts/03-deploy-platform.sh
```

### 3. Retrieve Credentials and Endpoints
Once ArgoCD has synchronized the applications, you can retrieve the URLs and auto-generated passwords using the credentials script:
```bash
chmod +x ./get_credentials.sh
./get_credentials.sh
```

## Architecture Summary
The deployment relies on ArgoCD managing applications defined in the `platform/` Helm chart. These include:
- **Keycloak** for Identity and Access Management
- **Scorpio** (FIWARE Context Broker)
- **APISIX** (API Gateway)
- **EMQX** (MQTT Broker)
- **Node-RED** & **Grafana**
- **TimescaleDB** & **MongoDB**