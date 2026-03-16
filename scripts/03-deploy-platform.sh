#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/utils.sh"


check_dependency "helm"
check_dependency "kubectl"


log_info "Deploying Platform Umbrella Chart (ArgoCD Applications)..."
# Load .env if present[ -f "$(dirname "$0")/../.env" ] && source "$(dirname "$0")/../.env"
DOMAIN=${DOMAIN:-"example.com"}

# Render the umbrella chart and apply it as ArgoCD Application CRDs
helm template fiware-platform "$(dirname "$0")/../platform" \
  --set host="${DOMAIN}" \
  --set source=https://github.com/Mrazbb/SmartCity \
  --set branch=main \
  --set destination_namespace=fiware \
  --namespace argocd | kubectl apply -n argocd -f -

log_info "FIWARE Platform deployed successfully to ArgoCD!"
log_info "You can monitor the synchronization progress by running: kubectl get applications -n argocd"