# IoT MQTT to Context Broker Guide

This guide explains how to connect your sensor via MQTT (EMQX) and route the data through the IoT Agent JSON to the Scorpio Context Broker.

## 1. Configure EMQX Authentication & ACLs

Because `EMQX_ALLOW_ANONYMOUS` is set to `false` and `EMQX_ACL_NOMATCH` is `deny`, we must explicitly create users and define what topics they can access.

### Step 1.1: Access EMQX Dashboard
1. Go to `https://emqx.<your-domain>` (or `http://localhost:18083` via port-forward).
2. Log in using `admin` and the password from `./get_credentials.sh` (EMQX Dashboard section).

### Step 1.2: Enable Password-Based Authentication
1. Go to **Access Control** -> **Authentication** in the left menu.
2. Click **Create**, select **Password-Based**, and choose **Built-in Database**.
3. Leave settings as default and click **Create**.

### Step 1.3: Add Users
1. In the Authentication list, click **Users** for the newly created Built-in Database.
2. Add the **IoT Agent User**:
   - Username: `iot_agent`
   - Password: `iot_password` (Matches the Helm chart configuration)
3. Add the **Sensor User**:
   - Username: `M5Stack003`
   - Password: `device_secret` (Matches `MQTT_PASS` in `config.h`)

### Step 1.4: Configure Authorization (ACL)
1. Go to **Access Control** -> **Authorization**.
2. Click **Create**, choose **Built-in Database**, and click **Create**.
3. Go to **Permissions** for this database and add the following rules:

**Rule 1: Allow IoT Agent to subscribe to all FIWARE topics**
- **Client ID / Username**: Username
- **Username**: `iot_agent`
- **Action**: Subscribe
- **Topic**: `/#` (or restricted to `+/+/attrs`)
- **Permission**: Allow

**Rule 2: Allow Sensor to publish to its topic**
- **Client ID / Username**: Username
- **Username**: `M5Stack003`
- **Action**: Publish
- **Topic**: `/smartcity_api/M5Stack003/attrs` (Replace `smartcity_api` with your `FIWARE_API_KEY`)
- **Permission**: Allow


## 2. Provision the Device in IoT Agent JSON

Now we must tell the IoT Agent JSON to listen for this device and map the JSON attributes to NGSI-LD entities in the Context Broker.

### Step 2.1: Port-Forward IoT Agent
Run the port-forward script to expose the IoT Agent API locally:
```bash
./port_forward_all.sh
```

### Step 2.2: Create a Service Group
This tells the IoT Agent to process messages sent to `/<api-key>/...` and creates entities with a specific prefix. We use the `airquality` tenant.

```bash
curl -iX POST 'http://localhost:4041/iot/services' \
-H 'Content-Type: application/json' \
-H 'fiware-service: airquality' \
-H 'fiware-servicepath: /' \
-d '{
  "services":[
    {
      "apikey": "smartcity_api",
      "cbroker": "http://scorpio:9090",
      "entity_type": "AirQualitySensor",
      "resource": ""
    }
  ]
}'
```

### Step 2.3: Provision the Device
This maps the incoming JSON fields to NGSI-LD properties.

```bash
curl -iX POST 'http://localhost:4041/iot/devices' \
-H 'Content-Type: application/json' \
-H 'fiware-service: airquality' \
-H 'fiware-servicepath: /' \
-d '{
  "devices":[
    {
      "device_id": "M5Stack003",
      "entity_name": "urn:ngsi-ld:AirQualitySensor:M5Stack003",
      "entity_type": "AirQualitySensor",
      "transport": "MQTT",
      "timezone": "Europe/Bratislava",
      "attributes":[
        { "object_id": "temperature", "name": "temperature", "type": "Property" },
        { "object_id": "humidity", "name": "humidity", "type": "Property" },
        { "object_id": "co2", "name": "co2", "type": "Property" },
        { "object_id": "pm25", "name": "pm25", "type": "Property" },
        { "object_id": "pm10", "name": "pm10", "type": "Property" },
        { "object_id": "voc", "name": "voc", "type": "Property" },
        { "object_id": "nox", "name": "nox", "type": "Property" },
        { "object_id": "battery", "name": "battery", "type": "Property" }
      ]
    }
  ]
}'
```

## 3. Verify in Context Broker
Once the sensor publishes a message to `/smartcity_api/M5Stack003/attrs`, the IoT Agent will automatically translate it and send it to the Context Broker.

You can verify the entity exists in Scorpio:
```bash
curl -s -X GET 'http://localhost:9090/ngsi-ld/v1/entities/urn:ngsi-ld:AirQualitySensor:M5Stack003' \
-H 'NGSILD-Tenant: airquality' | jq .
```