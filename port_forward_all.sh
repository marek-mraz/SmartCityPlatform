#!/bin/bash
#
# Port-forward all SmartCity Platform services from the fiware namespace.
# Usage: ./port_forward_all.sh [--selective]
#   --selective  Prompt before each service (y/n)
#
# Press Ctrl+C to stop all port-forwards.

NAMESPACE="fiware"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PIDS=()
SERVICES=()

cleanup() {
    echo -e "\n${YELLOW}Stopping all port-forwards...${NC}"
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    rm -f /tmp/pf_smartcity_*.log
    echo -e "${GREEN}All port-forwards stopped.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

start_port_forward() {
    local svc_name="$1"
    local local_port="$2"
    local remote_port="$3"
    local label="$4"
    local ns="${5:-$NAMESPACE}"
    local log_file="/tmp/pf_smartcity_${svc_name}_${local_port}.log"

    if [[ "$SELECTIVE" == true ]]; then
        read -rp "  Forward ${label} (${svc_name}:${remote_port} → localhost:${local_port})? [Y/n] " answer
        [[ "$answer" =~ ^[Nn]$ ]] && return
    fi

    kubectl -n "$ns" port-forward "svc/${svc_name}" "${local_port}:${remote_port}" > "$log_file" 2>&1 &
    local pid=$!
    PIDS+=("$pid")
    SERVICES+=("${label}|localhost:${local_port}|${pid}")
    echo -e "  ${GREEN}✔${NC} ${svc_name}:${remote_port} → ${BOLD}localhost:${local_port}${NC} (PID: ${pid})"
}

wait_for_port() {
    local port="$1"
    local name="$2"
    local max_wait="${3:-10}"
    for i in $(seq 1 "$max_wait"); do
        if nc -z localhost "$port" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done
    echo -e "  ${RED}⚠ ${name} on port ${port} may not be ready yet (check logs: /tmp/pf_smartcity_*.log)${NC}"
    return 1
}

SELECTIVE=false
[[ "$1" == "--selective" ]] && SELECTIVE=true

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   SmartCity Platform — Port Forward All Services     ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "  Namespace: ${BOLD}${NAMESPACE}${NC}"
echo ""

# --- Context Broker ---
echo -e "${YELLOW}[Context Broker]${NC}"
start_port_forward "scorpio"               9090  9090  "Scorpio (NGSI-LD Broker)"

# --- IoT ---
echo -e "\n${YELLOW}[IoT]${NC}"
start_port_forward "iot-agent-json"        4041  4041  "IoT Agent JSON"

# --- ArgoCD ---
echo -e "\n${YELLOW}[ArgoCD]${NC}"
start_port_forward "argocd-server"         8088  443   "ArgoCD" "argocd"

# --- Databases ---
echo -e "\n${YELLOW}[Databases]${NC}"
# start_port_forward "tsdb"                  5432  5432  "TimescaleDB"
start_port_forward "mongodb-iotagent"      27017 27017 "MongoDB (IoT Agent)"
# start_port_forward "keycloak-db"           5433  5432  "Keycloak PostgreSQL"
# Scorpio's internal PostgreSQL (if needed, uses scorpio-postgres service)
# start_port_forward "scorpio-postgresql"  5434  5432  "Scorpio PostgreSQL"

# --- MQTT Broker ---
echo -e "\n${YELLOW}[MQTT — EMQX]${NC}"
start_port_forward "emqx"                  1883  1883  "EMQX MQTT"
start_port_forward "emqx"                  18083 18083 "EMQX Dashboard API"

# --- Auth ---
# echo -e "\n${YELLOW}[Auth]${NC}"
# start_port_forward "keycloak-keycloakx-http" 8080 80   "Keycloak"

# --- API Gateway ---
echo -e "\n${YELLOW}[API Gateway]${NC}"
start_port_forward "apisix"                9080  80    "APISIX (PEP Proxy)"

# --- Visualization / UI ---
echo -e "\n${YELLOW}[Visualization]${NC}"
start_port_forward "grafana"               3001  80    "Grafana"
start_port_forward "nexurbis-manager"      3002  3000  "Nexurbis Manager"

# --- Node-RED ---
echo -e "\n${YELLOW}[Automation]${NC}"
start_port_forward "node-red"              1880  1880  "Node-RED"

# --- Data pipeline ---
echo -e "\n${YELLOW}[Data Pipeline]${NC}"
start_port_forward "orion-sync-unwrapper"  8081  8080  "Orion Sync Unwrapper"

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   All port-forwards started!                        ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Service URLs:${NC}"
echo -e "  Scorpio (Context Broker)   ${CYAN}http://localhost:9090${NC}"
echo -e "  IoT Agent JSON             ${CYAN}http://localhost:4041${NC}"
echo -e "  TimescaleDB                ${CYAN}postgresql://localhost:5432${NC}"
echo -e "  MongoDB (IoT Agent)        ${CYAN}mongodb://localhost:27017${NC}"
  echo -e "  ArgoCD                     ${CYAN}https://localhost:8088${NC}"
# echo -e "  Keycloak PostgreSQL        ${CYAN}postgresql://localhost:5433${NC}"
echo -e "  EMQX MQTT                  ${CYAN}mqtt://localhost:1883${NC}"
echo -e "  EMQX Dashboard API         ${CYAN}http://localhost:18083${NC}"
# echo -e "  Keycloak                   ${CYAN}http://localhost:8080${NC}"
echo -e "  APISIX (PEP Proxy)         ${CYAN}http://localhost:9080${NC}"
echo -e "  Grafana                    ${CYAN}http://localhost:3001${NC}"
echo -e "  Nexurbis Manager           ${CYAN}http://localhost:3002${NC}"
echo -e "  Node-RED                   ${CYAN}http://localhost:1880${NC}"
echo -e "  Orion Sync Unwrapper       ${CYAN}http://localhost:8081${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all port-forwards${NC}"
echo ""

wait
