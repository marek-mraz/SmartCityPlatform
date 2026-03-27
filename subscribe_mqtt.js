#!/usr/bin/env node
/**
 * Simple MQTT Subscriber for M5Stack Sensor Data
 * 
 * Usage:
 *   npm install mqtt
 *   node subscribe-m5stack.js
 */

const mqtt = require("mqtt");

// Configuration based on your test script
const CONFIG = {
  host: "smartcity.mark-frost.com",
  port: 1883,
  // Using IoT Agent credentials to listen to the device
  username: "iot_agent",     
  password: "iot_password",
  clientId: "agent_listener_" + Math.random().toString(16).slice(2, 8),
  
  apiKey: "4jggokgpepnvsb2uv4s40d59ov",
  deviceId: "M5Stack003",
};

// The topic where the M5Stack publishes its attributes
const topic = `/${CONFIG.apiKey}/${CONFIG.deviceId}/attrs`;

console.log(`[CONNECTING] To broker mqtt://${CONFIG.host}:${CONFIG.port}...`);

const client = mqtt.connect({
  host: CONFIG.host,
  port: CONFIG.port,
  username: CONFIG.username,
  password: CONFIG.password,
  clientId: CONFIG.clientId,
  clean: true,
});

client.on("connect", () => {
  console.log(`[CONNECTED] Successfully connected as ${CONFIG.username}`);
  
  // Subscribe to the M5Stack topic
  client.subscribe(topic, { qos: 1 }, (err) => {
    if (err) {
      console.error(`[ERROR] Failed to subscribe: ${err.message}`);
      process.exit(1);
    }
    console.log(`[SUBSCRIBED] Listening for messages on: ${topic}\n`);
    console.log(`Waiting for M5Stack data... (Press Ctrl+C to exit)\n`);
  });
});

client.on("message", (receivedTopic, message) => {
  try {
    // Attempt to parse as JSON for pretty printing
    const payload = JSON.parse(message.toString());
    const timestamp = payload._ts ? new Date(payload._ts).toLocaleTimeString() : new Date().toLocaleTimeString();
    
    console.log(`[${timestamp}] 📩 Data received from ${receivedTopic}:`);
    console.dir(payload, { colors: true, depth: null });
    console.log("--------------------------------------------------");
  } catch (e) {
    // Fallback if the message isn't valid JSON
    console.log(`[${new Date().toLocaleTimeString()}] 📩 Raw message on ${receivedTopic}:`);
    console.log(message.toString());
    console.log("--------------------------------------------------");
  }
});

client.on("error", (err) => {
  console.error(`[MQTT ERROR] ${err.message}`);
});

client.on("close", () => {
  console.log(`[DISCONNECTED] Connection to broker closed.`);
});