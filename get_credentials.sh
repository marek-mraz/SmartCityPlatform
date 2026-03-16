#!/bin/bash
echo "--------------------------------------------------"
echo "FIWARE SmartCity Credentials & Endpoints"
echo "--------------------------------------------------"

[ -f .env ] && source .env
DOMAIN=${DOMAIN:-"example.com"}

# Load Kubeconfig if not set
if [ -z "$KUBECONFIG" ]; then
    if [ -f "./talosconfig" ]; then
        export KUBECONFIG="$(pwd)/kubeconfig"
    elif [ -f "./k3s_deploy/k3s-kubeconfig.yaml" ]; then
        export KUBECONFIG="$(pwd)/k3s_deploy/k3s-kubeconfig.yaml"
    elif [ -f "./k3s-kubeconfig.yaml" ]; then
        export KUBECONFIG="$(pwd)/k3s-kubeconfig.yaml"
    else
        export KUBECONFIG="$HOME/.kube/config"
    fi
fi

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Error: Kubernetes cluster not reachable. Check your KUBECONFIG."
    exit 1
fi

# Domains
echo "URLS:"
echo "  ArgoCD:       https://argocd.${DOMAIN}"
echo "  Grafana:      https://grafana.${DOMAIN}"
echo "  Keycloak:     https://auth.${DOMAIN}"
echo "  Orion:        https://orion-ld.${DOMAIN}"
echo "  Scorpio:      https://scorpio.${DOMAIN}"
echo "  Node-RED:     https://node-red.${DOMAIN}"
echo "  Kong:         https://kong.${DOMAIN}"
echo "  QuantumLeap:  https://quantumleap.${DOMAIN}"
echo ""

# ArgoCD
echo "ArgoCD:"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: admin"
echo "  Pass: ${ARGO_PWD:-<Not Found>}"
echo ""

# Grafana
echo "Grafana:"
GRAF_USER=$(kubectl -n fiware get secret grafana-admin-user -o jsonpath='{.data.admin-user}' 2>/dev/null | base64 -d)
GRAF_PWD=$(kubectl -n fiware get secret grafana-admin-user -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d)
echo "  User: ${GRAF_USER:-fiwareAdmin}"
echo "  Pass: ${GRAF_PWD:-fiwareAdmin}"
echo ""

# Keycloak Admin
echo "Keycloak Admin:"
KC_USER=$(kubectl -n fiware get secret keycloak-admin-credentials -o jsonpath='{.data.username}' 2>/dev/null | base64 -d)
KC_PWD=$(kubectl -n fiware get secret keycloak-admin-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: ${KC_USER:-<Not Found>}"
echo "  Pass: ${KC_PWD:-<Not Found>}"
echo ""

# Keycloak App Users
echo "Keycloak App Users:"
ADMIN_USER_PWD=$(kubectl -n fiware get secret admin-user-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
CONSUMER_USER_PWD=$(kubectl -n fiware get secret consumer-user-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: admin-user"
echo "  Pass: ${ADMIN_USER_PWD:-<Not Found>}"
echo "  User: consumer-user"
echo "  Pass: ${CONSUMER_USER_PWD:-<Not Found>}"
echo ""

# MongoDB (Used by IoT Agent)
echo "MongoDB:"
MONGO_PWD=$(kubectl -n fiware get secret mongodb-orion -o jsonpath='{.data.mongodb-root-password}' 2>/dev/null | base64 -d)
echo "  User: root"
echo "  Pass: ${MONGO_PWD:-test}"
echo ""

# TimescaleDB
echo "TimescaleDB:"
TSDB_PWD=$(kubectl -n fiware get secret tsdb-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: admin"
echo "  Pass: ${TSDB_PWD:-<Not Found>}"
echo ""
