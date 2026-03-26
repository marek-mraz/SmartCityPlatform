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
echo "  Manager:      https://manager.${DOMAIN}"
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

# Keycloak DB
echo "Keycloak DB:"
KC_DB_PWD=$(kubectl -n fiware get secret keycloak-db-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: keycloak"
echo "  Pass: ${KC_DB_PWD:-<Not Found>}"
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

# Keycloak Client Secrets
echo "Keycloak Client Secrets:"
GRAFANA_OAUTH_SECRET=$(kubectl -n fiware get secret grafana-oauth -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
MQTT_EXPLORER_OAUTH_SECRET=$(kubectl -n fiware get secret mqtt-explorer-oauth2 -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
EMQX_DASHBOARD_OAUTH_SECRET=$(kubectl -n fiware get secret emqx-dashboard-oauth2 -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
CB_PEP_SECRET=$(kubectl -n fiware get secret cb-pep-credentials -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
NGSILD_OAUTH_SECRET=$(kubectl -n fiware get secret ngsild-oauth -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
NODE_RED_OAUTH_SECRET=$(kubectl -n fiware get secret node-red-oauth2 -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)
NODE_RED_NGSILD_SECRET=$(kubectl -n fiware get secret node-red-ngsild -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)

echo "  Grafana: ${GRAFANA_OAUTH_SECRET:-<Not Found>}"
echo "  MQTT Explorer: ${MQTT_EXPLORER_OAUTH_SECRET:-<Not Found>}"
echo "  EMQX Dashboard: ${EMQX_DASHBOARD_OAUTH_SECRET:-<Not Found>}"
echo "  CB PEP: ${CB_PEP_SECRET:-<Not Found>}"
echo "  NGSILD: ${NGSILD_OAUTH_SECRET:-<Not Found>}"
echo "  Node-RED: ${NODE_RED_OAUTH_SECRET:-<Not Found>}"
NEXURBIS_MANAGER_SECRET=$(kubectl -n fiware get secret nexurbis-manager-oauth2 -o jsonpath='{.data.client-secret}' 2>/dev/null | base64 -d)

echo "  Node-RED NGSILD: ${NODE_RED_NGSILD_SECRET:-<Not Found>}"
echo "  Nexurbis Manager: ${NEXURBIS_MANAGER_SECRET:-<Not Found>}"
echo ""

# EMQX Dashboard
echo "EMQX Dashboard:"
EMQX_PWD=$(kubectl -n fiware get secret emqx-dashboard-credentials -o jsonpath='{.data.EMQX_DASHBOARD__DEFAULT_PASSWORD}' 2>/dev/null | base64 -d)
echo "  User: admin"
echo "  Pass: ${EMQX_PWD:-<Not Found>}"
echo ""

# MongoDB (Used by IoT Agent)
echo "MongoDB:"
MONGO_PWD=$(kubectl -n fiware get secret mongodb-iotagent -o jsonpath='{.data.mongodb-root-password}' 2>/dev/null | base64 -d)
echo "  User: root"
echo "  Pass: ${MONGO_PWD:-test}"
echo ""

# TimescaleDB
echo "TimescaleDB:"
TSDB_PWD=$(kubectl -n fiware get secret tsdb-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: postgres"
echo "  Pass: ${TSDB_PWD:-<Not Found>}"
echo ""

# Nexurbis DB
echo "Nexurbis DB:"
NEXURBIS_DB_PWD=$(kubectl -n fiware get secret nexurbis-db-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
echo "  User: postgres"
echo "  Pass: ${NEXURBIS_DB_PWD:-<Not Found>}"
echo ""