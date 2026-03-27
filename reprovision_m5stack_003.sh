#!/bin/bash

TENANT="airquality"
FIWARE_SERVICEPATH="/data"
DEVICE_ID="M5Stack003"
ENTITY_ID="urn:ngsi-ld:AirQualityObserved:M5Stack:003"
ENTITY_TYPE="AirQualityObserved"
CONTEXT="https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.3.jsonld"

SCORPIO_URL="http://localhost:9090"

echo "Starting port-forward for EMQX API..."
kubectl -n fiware port-forward svc/emqx 18083:18083 > emqx_pf.log 2>&1 &
EMQX_PF_PID=$!

echo "Waiting for EMQX port-forward..."
EMQX_PF_SUCCESS=false
for i in {1..15}; do
  if curl -s http://localhost:18083 > /dev/null; then
    EMQX_PF_SUCCESS=true
    break
  fi
  sleep 1
done

if [ "$EMQX_PF_SUCCESS" = false ]; then
  echo "Error: Failed to establish EMQX port-forward. Check emqx_pf.log"
  kill $EMQX_PF_PID 2>/dev/null
  exit 1
fi

EMQX_PWD=$(kubectl -n fiware get secret emqx-dashboard-credentials -o jsonpath='{.data.EMQX_DASHBOARD__DEFAULT_PASSWORD}' | base64 -d)

echo -e "\n\n0. Setting up EMQX Authentication and Users..."
curl -s -u "admin:${EMQX_PWD}" -X POST "http://localhost:18083/api/v5/authentication" \
  -H "Content-Type: application/json" \
  -d '{
    "mechanism": "password_based",
    "backend": "built_in_database",
    "user_id_type": "clientid"
  }' > /dev/null

curl -s -u "admin:${EMQX_PWD}" -X POST "http://localhost:18083/api/v5/authentication/password_based:built_in_database/users" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "iot_agent",
    "password": "iot_password"
  }' > /dev/null || true

curl -s -u "admin:${EMQX_PWD}" -X POST "http://localhost:18083/api/v5/authentication/password_based:built_in_database/users" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "'${DEVICE_ID}'",
    "password": "device_secret"
  }' > /dev/null || true

echo -e "\n\n0. Setting up EMQX Rules for Sparkplug B..."

# Rule 1: JSON to Sparkplug B (Protobuf)
curl -s -u "admin:${EMQX_PWD}" -X POST "http://localhost:18083/api/v5/rules" \
  -H "Content-Type: application/json" \
  -d @- > /dev/null <<EOF
{
  "name": "JSON_to_SparkplugB",
  "sql": "SELECT spb_encode(json_decode(payload)) as payload FROM \"spBv1.0_JSON/SmartCity/DDATA/M5Stack003\"",
  "actions":[{
    "function": "republish",
    "args": {
      "topic": "spBv1.0/SmartCity/DDATA/M5Stack003",
      "payload": "\${payload}"
    }
  }]
}
EOF

# Rule 2: Sparkplug B to IoT Agent (Flat JSON)
curl -s -u "admin:${EMQX_PWD}" -X POST "http://localhost:18083/api/v5/rules" \
  -H "Content-Type: application/json" \
  -d @- > /dev/null <<EOF
{
  "name": "SparkplugB_to_IoTAgent",
  "sql": "SELECT json_encode(first(jq('.metrics | map({(.name): .value}) | add', spb_decode(payload)))) as payload FROM \"spBv1.0/SmartCity/DDATA/M5Stack003\"",
  "actions":[{
    "function": "republish",
    "args": {
      "topic": "/m5stack/M5Stack003/attrs",
      "payload": "\${payload}"
    }
  }]
}
EOF

echo "Restarting IoT Agent to apply potential connection fixes..."
kubectl -n fiware rollout restart deploy/iot-agent-json
kubectl -n fiware rollout status deploy/iot-agent-json

echo "Starting port-forward for iot-agent-json..."
kubectl -n fiware port-forward svc/iot-agent-json 4041:4041 > iot_agent_pf.log 2>&1 &
PF_IOT_PID=$!

echo "Starting port-forward for Scorpio..."
kubectl -n fiware port-forward svc/scorpio 9090:9090 > scorpio_pf.log 2>&1 &
KUBE_PROXY_PID=$!

echo "Waiting for IOTA and Scorpio port-forwards..."
PF_SUCCESS=false
for i in {1..15}; do
  if curl -s http://localhost:4041 > /dev/null && curl -s http://localhost:9090 > /dev/null; then
    PF_SUCCESS=true
    break
  fi
  sleep 1
done

if [ "$PF_SUCCESS" = false ]; then
  echo "Error: Failed to establish port-forwards. Check scorpio_pf.log and iot_agent_pf.log"
  kill $PF_IOT_PID 2>/dev/null
  kill $KUBE_PROXY_PID 2>/dev/null
  kill $EMQX_PF_PID 2>/dev/null
  exit 1
fi

# -------------------------------------------------------------------------
# 0.5 Cleanup existing resources (Teardown)
# -------------------------------------------------------------------------
echo -e "\n\n0.5 Cleaning up existing device, entity, and service (if they exist)..."

# Delete the device in the IoT Agent (current servicepath)
curl -s -X DELETE "http://localhost:4041/iot/devices/${DEVICE_ID}" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: ${FIWARE_SERVICEPATH}" > /dev/null

# Delete the device under root servicepath (stale registration)
curl -s -X DELETE "http://localhost:4041/iot/devices/${DEVICE_ID}" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: /" > /dev/null

# Delete the service group in the IoT Agent (current servicepath)
curl -s -X DELETE "http://localhost:4041/iot/services?resource=/iot/json&apikey=m5stack" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: ${FIWARE_SERVICEPATH}" > /dev/null

# Delete stale service group under root servicepath
curl -s -X DELETE "http://localhost:4041/iot/services?resource=/iot/json&apikey=4jggokgpepnvsb2uv4s40d59ov" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: /" > /dev/null

# Delete the entity in Scorpio
curl -s -X DELETE "${SCORPIO_URL}/ngsi-ld/v1/entities/${ENTITY_ID}" \
  -H "NGSILD-Tenant: ${TENANT}" > /dev/null

# -------------------------------------------------------------------------

# 1. Create the Tenant (Service Group) in the IoT Agent
# This explicitly tells the IoT Agent how to handle the "airquality" tenant 
# and where to route its data.
echo -e "\n\n1. Creating Service (Tenant) in IoT Agent..."
curl -i -X POST "http://localhost:4041/iot/services" \
  -H "Content-Type: application/json" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: ${FIWARE_SERVICEPATH}" \
  -d '{
    "services":[
      {
        "apikey": "m5stack",
        "cbroker": "http://scorpio:9090",
        "entity_type": "'${ENTITY_TYPE}'",
        "resource": "/iot/json"
      }
    ]
  }'

# 2. Create the entity directly at the Context Broker (Scorpio)
# By passing the NGSILD-Tenant header, Scorpio will natively auto-create the 
# tenant DB on the fly if it does not yet exist.
echo -e "\n\n2. Creating entity at Context Broker (Scorpio)..."
curl -i -X POST "${SCORPIO_URL}/ngsi-ld/v1/entities" \
  -H "Content-Type: application/ld+json" \
  -H "NGSILD-Tenant: ${TENANT}" \
  -d '{
    "id": "'${ENTITY_ID}'",
    "type": "'${ENTITY_TYPE}'",
    "name": {
      "type": "Property",
      "value": "M5Stack Air Quality Sensor 003"
    },
    "location": {
      "type": "GeoProperty",
      "value": {
        "type": "Point",
        "coordinates":[19.1563278, 48.7383681]
      }
    },
    "@context":[
      "'${CONTEXT}'"
    ]
  }'

# 3. Provision the device in the IoT Agent
echo -e "\n\n3. Provisioning M5Stack:003 with NGSI-LD properties in IoT Agent..."
curl -s -X POST "http://localhost:4041/iot/devices" \
  -H "Content-Type: application/json" \
  -H "fiware-service: ${TENANT}" \
  -H "fiware-servicepath: ${FIWARE_SERVICEPATH}" \
  -d '{
    "devices":[
      {
        "device_id": "'${DEVICE_ID}'",
        "entity_name": "'${ENTITY_ID}'",
        "entity_type": "'${ENTITY_TYPE}'",
        "transport": "MQTT",
        "ngsiVersion": "ld",
        "attributes":[
          { "object_id": "co2", "name": "co2", "type": "Property" },
          { "object_id": "temperature", "name": "temperature", "type": "Property" },
          { "object_id": "humidity", "name": "humidity", "type": "Property" },
          { "object_id": "pm1", "name": "pm1", "type": "Property" },
          { "object_id": "pm25", "name": "pm25", "type": "Property" },
          { "object_id": "pm4", "name": "pm4", "type": "Property" },
          { "object_id": "pm10", "name": "pm10", "type": "Property" },
          { "object_id": "sen_temp", "name": "sen_temp", "type": "Property" },
          { "object_id": "sen_hum", "name": "sen_hum", "type": "Property" },
          { "object_id": "voc", "name": "voc", "type": "Property" },
          { "object_id": "nox", "name": "nox", "type": "Property" },
          { "object_id": "battery", "name": "battery", "type": "Property" },
          { "object_id": "rssi", "name": "rssi", "type": "Property" }
        ]
      }
    ]
  }'

# 4. Check / Get the entity from the Context Broker
echo -e "\n\n4. Fetching entity from Context Broker (Scorpio) to verify..."
curl -s -X GET "${SCORPIO_URL}/ngsi-ld/v1/entities/${ENTITY_ID}" \
  -H "NGSILD-Tenant: ${TENANT}" \
  -H "Accept: application/ld+json" | python3 -m json.tool 2>/dev/null || \
curl -s -X GET "${SCORPIO_URL}/ngsi-ld/v1/entities/${ENTITY_ID}" \
  -H "NGSILD-Tenant: ${TENANT}" \
  -H "Accept: application/ld+json"

echo -e "\n\nCleaning up..."
kill $PF_IOT_PID
kill $KUBE_PROXY_PID 2>/dev/null
kill $EMQX_PF_PID 2>/dev/null

echo "Done! Sensor M5Stack:003 is provisioned and verified in Scorpio."



