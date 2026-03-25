#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/../.env"


BRANCH=${BRANCH:-"main"}

if [ -z "$DOMAIN" ]; then
  echo "DOMAIN is not set"
  exit 1
fi

if [ -z "$SOURCE" ]; then
  echo "SOURCE is not set"
  exit 1
fi

check_dependency "helm"
check_dependency "kubectl"


log_info "Deploying Platform Umbrella Chart (ArgoCD Applications)..."
# Load .env if present[ -f "$(dirname "$0")/../.env" ] && source "$(dirname "$0")/../.env"
DOMAIN=${DOMAIN:-"example.com"}
SOURCE_URL=${SOURCE:-"https://github.com/Mrazbb/SmartCity"}
BRANCH=${BRANCH:-"main"}

log_info "Checking if ArgoCD is installed..."
if ! kubectl get customresourcedefinition applications.argoproj.io >/dev/null 2>&1; then
  log_info "ArgoCD CRDs not found. Installing ArgoCD..."
  kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
  kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  
  log_info "Waiting for ArgoCD CRDs to be established..."
  kubectl wait --for=condition=established --timeout=120s crd/applications.argoproj.io || true
else
  log_info "ArgoCD is already installed."
fi

# Render the umbrella chart and apply it as ArgoCD Application CRDs
helm template fiware-platform "$(dirname "$0")/../platform" \
  --set host="${DOMAIN}" \
  --set source="${SOURCE_URL}" \
  --set branch="${BRANCH}" \
  --set destination_namespace=fiware \
  --namespace argocd | kubectl apply -n argocd -f -

log_info "FIWARE Platform deployed successfully to ArgoCD!"
log_info "You can monitor the synchronization progress by running: kubectl get applications -n argocd"