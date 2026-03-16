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



echo "Deleting Platform Umbrella Chart (ArgoCD Applications)..."

helm template fiware-platform "$(dirname "$0")/../platform" \
  --set host="${DOMAIN}" \
  --set source="${SOURCE}" \
  --set branch="${BRANCH}" \
  --set destination_namespace=fiware \
  --namespace argocd | kubectl delete -n argocd -f -

echo "FIWARE Platform apps deleted successfully!"