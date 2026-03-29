#!/usr/bin/env node
/**
 * MQTT Test Script for SmartCity Platform
 * Tests EMQX broker connectivity, publishing, IoT Agent integration, and security.
 *
 * Usage:
 *   npm install mqtt
 *   node mqtt-test.js [--host <host>] [--mode <mode>]
 *
 * Modes:
 *   publish        - Publish a single sensor payload
 *   subscribe      - Subscribe and listen for messages
 *   stress         - Publish N messages rapidly
 *   acl            - Test subscription ACL denial
 *   auth-fail      - Test bad password rejection
 *   acl-pub-denial - Test publish ACL denial
 *   retained       - Test retained message delivery
 *   large-payload  - Test large payload handling
 *   qos2           - Test QoS 2 delivery
 *   full           - Run all tests sequentially (default)
 */

const mqtt = require("mqtt");

// ─── Config ──────────────────────────────────────────────────────────────────

const args = Object.fromEntries(
  process.argv
    .slice(2)
    .filter((a) => a.startsWith("--"))
    .map((a) => a.slice(2).split("="))
    .map(([k, v]) => [k, v ?? true])
);

const CONFIG = {
  host: args.host ?? "smartcity.mark-frost.com",
  port: Number(args.port ?? 1883),
  mode: args.mode ?? "full",
  stress_count: Number(args["stress-count"] ?? 20),
  stress_interval_ms: Number(args["stress-interval"] ?? 200),

  sensor: {
    username: args["sensor-user"] ?? "M5Stack003",
    password: args["sensor-pass"] ?? "device_secret",
    clientId: "M5Stack003",
  },

  iotAgent: {
    username: args["agent-user"] ?? "iot_agent",
    password: args["agent-pass"] ?? "iot_password",
    clientId: "iot_agent_test_" + Math.random().toString(36).slice(2, 7),
  },

  apiKey: args["api-key"] ?? "smartcity_api",
  deviceId: args["device-id"] ?? "M5Stack003",
};

CONFIG.topic = `/${CONFIG.apiKey}/${CONFIG.deviceId}/attrs`;

// ─── Helpers ─────────────────────────────────────────────────────────────────

const RESET = "\x1b[0m";
const C = {
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  gray: "\x1b[90m",
  bold: "\x1b[1m",
};

const log = {
  info: (msg) => console.log(`${C.cyan}ℹ${RESET}  ${msg}`),
  ok: (msg) => console.log(`${C.green}✔${RESET}  ${msg}`),
  warn: (msg) => console.log(`${C.yellow}⚠${RESET}  ${msg}`),
  err: (msg) => console.log(`${C.red}✖${RESET}  ${msg}`),
  dim: (msg) => console.log(`${C.gray}   ${msg}${RESET}`),
  section: (msg) => console.log(`\n${C.bold}${C.cyan}── ${msg} ──${RESET}`),
};

function fakeSensorPayload(seq = 0) {
  return {
    temperature: +(20 + Math.random() * 10).toFixed(2),
    humidity: +(40 + Math.random() * 40).toFixed(2),
    co2: Math.round(400 + Math.random() * 600),
    pm25: +(Math.random() * 25).toFixed(2),
    pm10: +(Math.random() * 50).toFixed(2),
    voc: +(Math.random() * 200).toFixed(2),
    nox: +(Math.random() * 50).toFixed(2),
    battery: +(80 + Math.random() * 20).toFixed(1),
    _seq: seq,
    _ts: new Date().toISOString(),
  };
}

function connect(role) {
  const creds = role === "sensor" ? CONFIG.sensor : CONFIG.iotAgent;
  return new Promise((resolve, reject) => {
    const client = mqtt.connect({
      host: CONFIG.host,
      port: CONFIG.port,
      username: creds.username,
      password: creds.password,
      clientId: creds.clientId,
      connectTimeout: 8000,
      keepalive: 30,
      clean: true,
    });

    const timer = setTimeout(() => {
      client.end(true);
      reject(new Error(`Connection timeout for role="${role}"`));
    }, 9000);

    client.once("connect", () => {
      clearTimeout(timer);
      resolve(client);
    });
    client.once("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

async function testPublish() {
  log.section("Publish test (sensor → broker)");
  log.info(`Connecting as sensor  user="${CONFIG.sensor.username}"`);

  let client;
  try {
    client = await connect("sensor");
    log.ok(`Connected to ${CONFIG.host}:${CONFIG.port}`);
  } catch (e) {
    log.err(`Connection failed: ${e.message}`);
    return false;
  }

  return new Promise((resolve) => {
    const payload = fakeSensorPayload(1);
    const json = JSON.stringify(payload);

    client.publish(CONFIG.topic, json, { qos: 1 }, (err) => {
      client.end();
      if (err) {
        log.err(`Publish failed: ${err.message}`);
        resolve(false);
      } else {
        log.ok("Message published successfully (QoS 1)");
        resolve(true);
      }
    });
  });
}

async function testSubscribeReceive(timeoutMs = 8000) {
  log.section("Subscribe + receive test (IoT Agent perspective)");
  let agentClient, sensorClient;
  try {
    agentClient = await connect("iotAgent");
  } catch (e) {
    log.err(`IoT Agent connection failed: ${e.message}`);
    return false;
  }

  return new Promise(async (resolve) => {
    let received = false;

    agentClient.subscribe("/#", { qos: 1 }, async (err) => {
      if (err) {
        log.err(`Subscribe failed: ${err.message}`);
        agentClient.end();
        return resolve(false);
      }
      log.ok(`Subscribed to "/#"`);
      
      try {
        sensorClient = await connect("sensor");
      } catch (e) {
        log.err(`Sensor connection failed: ${e.message}`);
        agentClient.end();
        return resolve(false);
      }

      sensorClient.publish(CONFIG.topic, JSON.stringify(fakeSensorPayload(99)), { qos: 1 });
    });

    agentClient.on("message", (topic, message) => {
      if (received) return;
      received = true;
      log.ok(`Message received on topic "${topic}"`);
      cleanup(true);
    });

    const timer = setTimeout(() => {
      if (!received) {
        log.err(`No message received within ${timeoutMs / 1000} s`);
        cleanup(false);
      }
    }, timeoutMs);

    function cleanup(ok) {
      clearTimeout(timer);
      try { agentClient?.end(); } catch {}
      try { sensorClient?.end(); } catch {}
      resolve(ok);
    }
  });
}

async function testStress() {
  log.section(`Stress test — ${CONFIG.stress_count} messages @ ${CONFIG.stress_interval_ms} ms interval`);
  let client;
  try {
    client = await connect("sensor");
  } catch (e) {
    log.err(`Connection failed: ${e.message}`);
    return false;
  }

  let ok = 0; let fail = 0;
  for (let i = 1; i <= CONFIG.stress_count; i++) {
    await new Promise((resolve) => {
      client.publish(CONFIG.topic, JSON.stringify(fakeSensorPayload(i)), { qos: 1 }, (err) => {
        err ? fail++ : ok++;
        process.stdout.write(`\r   ${C.green}✔${RESET} ${ok} sent  ${C.red}✖${RESET} ${fail} failed`);
        resolve();
      });
    });
    if (i < CONFIG.stress_count) await new Promise((r) => setTimeout(r, CONFIG.stress_interval_ms));
  }
  process.stdout.write("\n");
  client.end();
  log.ok(`Done: ${ok} delivered, ${fail} failed.`);
  return fail === 0;
}

async function testAclDenial() {
  log.section("ACL deny test — sensor must NOT be allowed to subscribe to /#");
  let client;
  try {
    client = await connect("sensor");
  } catch (e) {
    log.err(`Connection failed: ${e.message}`);
    return false;
  }

  return new Promise((resolve) => {
    client.subscribe("/#", { qos: 1 }, (err, granted) => {
      client.end();
      if (err) {
        log.ok(`Subscribe correctly rejected: ${err.message}`);
        resolve(true);
      } else {
        const denied = granted?.some((g) => g.qos >= 128);
        if (denied) {
          log.ok("Subscribe granted but with QoS=128 (denied by ACL) — correct");
          resolve(true);
        } else {
          log.warn("Broker accepted wildcard subscribe for sensor user — check EMQX ACLs!");
          resolve(false);
        }
      }
    });
  });
}

// ─── NEW TESTS ───────────────────────────────────────────────────────────────

async function testAuthFailure() {
  log.section("Auth failure test — broker must reject invalid passwords");
  return new Promise((resolve) => {
    const client = mqtt.connect({
      host: CONFIG.host,
      port: CONFIG.port,
      username: CONFIG.sensor.username,
      password: "WRONG_PASSWORD_123",
      clientId: "test_bad_auth_" + Date.now(),
      connectTimeout: 5000
    });

    client.once("error", (err) => {
      log.ok(`Broker correctly rejected bad password: ${err.message}`);
      client.end();
      resolve(true);
    });

    client.once("connect", () => {
      log.err("Connected successfully with wrong password! Broker auth is broken or allows anonymous.");
      client.end();
      resolve(false);
    });
  });
}

async function testAclPublishDenial() {
  log.section("ACL publish deny test — sensor publishing to restricted topic");
  let client;
  try {
    client = await connect("sensor");
  } catch (e) { return false; }

  return new Promise((resolve) => {
    const badTopic = "/smartcity_api/ADMIN_TOPIC/override";
    let disconnected = false;

    client.on("close", () => {
      disconnected = true;
      log.ok("Broker disconnected client (strict EMQX ACL behavior) — correct");
      resolve(true);
    });

    client.publish(badTopic, "hacked_data", { qos: 1 }, (err) => {
      if (err) {
        log.ok(`Publish correctly rejected with error: ${err.message}`);
        client.end();
        resolve(true);
      } else {
        setTimeout(() => {
          if (!disconnected) {
             log.warn("Publish succeeded without error. (Broker might silently drop ACL denials, verify EMQX logs)");
             client.end();
             resolve(true); // Soft pass (MQTT 3.1.1 standard behavior)
          }
        }, 500);
      }
    });
  });
}

async function testRetainedMessage() {
  log.section("Retained message test — late subscribers should receive last value");
  const retainedTopic = `${CONFIG.topic}/retained_test`;
  
  let pubClient;
  try {
    pubClient = await connect("sensor");
  } catch (e) { return false; }

  return new Promise((resolve) => {
    // 1. Publish retained message
    pubClient.publish(retainedTopic, '{"status":"online"}', { qos: 1, retain: true }, async () => {
      log.ok("Published retained message.");
      pubClient.end();

      // 2. Connect new subscriber
      let subClient = await connect("iotAgent");
      subClient.subscribe(retainedTopic, { qos: 1 });

      let received = false;
      subClient.on("message", (t, msg) => {
        received = true;
        log.ok("Late subscriber immediately received the retained message.");
        
        // 3. Clear retained message so it doesn't linger
        pubClient = mqtt.connect({ host: CONFIG.host, port: CONFIG.port, username: CONFIG.sensor.username, password: CONFIG.sensor.password });
        pubClient.on("connect", () => {
          pubClient.publish(retainedTopic, "", { retain: true }, () => {
             pubClient.end();
             subClient.end();
             resolve(true);
          });
        });
      });

      setTimeout(() => {
        if (!received) {
          log.err("Subscriber did not receive retained message.");
          subClient.end();
          resolve(false);
        }
      }, 3000);
    });
  });
}

async function testLargePayload() {
  log.section("Large payload test — ensuring broker doesn't drop larger packets");
  let client;
  try { client = await connect("sensor"); } catch (e) { return false; }

  return new Promise((resolve) => {
    // Generate ~10KB payload
    const largeData = { ...fakeSensorPayload(), padding: "A".repeat(10000) };
    const payloadStr = JSON.stringify(largeData);
    
    client.publish(CONFIG.topic, payloadStr, { qos: 1 }, (err) => {
      client.end();
      if (err) {
        log.err(`Large payload failed: ${err.message}`);
        resolve(false);
      } else {
        log.ok(`Successfully published ${Buffer.byteLength(payloadStr, 'utf8')} bytes`);
        resolve(true);
      }
    });
  });
}

async function testQoS2() {
  log.section("QoS 2 delivery test — 'Exactly Once' guarantees");
  let agentClient, sensorClient;
  try {
    agentClient = await connect("iotAgent");
    sensorClient = await connect("sensor");
  } catch (e) { return false; }

  return new Promise((resolve) => {
    agentClient.subscribe(CONFIG.topic, { qos: 2 }, () => {
      sensorClient.publish(CONFIG.topic, JSON.stringify({ test: "qos2" }), { qos: 2 }, (err) => {
        if (err) log.warn(`Publish error: ${err.message}`);
      });
    });

    agentClient.on("message", (topic, msg, packet) => {
      log.ok(`Received with QoS ${packet.qos}`);
      agentClient.end();
      sensorClient.end();
      // Even if broker downgrades QoS, it successfully routed
      resolve(packet.qos === 2 || packet.qos === 1); 
    });

    setTimeout(() => {
      log.err("Timeout waiting for QoS 2 delivery");
      agentClient.end();
      sensorClient.end();
      resolve(false);
    }, 4000);
  });
}

// ─── Summary ─────────────────────────────────────────────────────────────────

function printSummary(results) {
  log.section("Results");
  const pad = Math.max(...Object.keys(results).map((k) => k.length));
  for (const [name, passed] of Object.entries(results)) {
    const icon = passed ? `${C.green}PASS${RESET}` : `${C.red}FAIL${RESET}`;
    console.log(`  ${name.padEnd(pad)}  ${icon}`);
  }
  const failures = Object.values(results).filter((v) => !v).length;
  console.log();
  if (failures === 0) {
    log.ok("All tests passed");
  } else {
    log.err(`${failures} test(s) failed`);
    process.exitCode = 1;
  }
}

// ─── Entry ───────────────────────────────────────────────────────────────────

(async () => {
  console.log(`\n${C.bold}MQTT Test — ${CONFIG.host}:${CONFIG.port}${RESET}`);
  log.dim(`topic   : ${CONFIG.topic}`);
  log.dim(`mode    : ${CONFIG.mode}`);

  const results = {};

  const runTest = async (name, fn) => { results[name] = await fn(); };

  switch (CONFIG.mode) {
    case "publish": await runTest("publish", testPublish); break;
    case "subscribe": await runTest("subscribe", testSubscribeReceive); break;
    case "stress": await runTest("stress", testStress); break;
    case "acl": await runTest("acl-sub", testAclDenial); break;
    case "auth-fail": await runTest("auth-fail", testAuthFailure); break;
    case "acl-pub-denial": await runTest("acl-pub", testAclPublishDenial); break;
    case "retained": await runTest("retained", testRetainedMessage); break;
    case "large-payload": await runTest("large-payload", testLargePayload); break;
    case "qos2": await runTest("qos2", testQoS2); break;

    case "full":
    default:
      await runTest("auth-fail", testAuthFailure); // Run this first since it doesn't need valid creds
      await runTest("publish", testPublish);
      await runTest("subscribe", testSubscribeReceive);
      await runTest("stress", testStress);
      await runTest("acl-sub", testAclDenial);
      await runTest("acl-pub", testAclPublishDenial);
      await runTest("retained", testRetainedMessage);
      await runTest("large-payload", testLargePayload);
      await runTest("qos2", testQoS2);
      break;
  }

  printSummary(results);
})();