# Spec 001: DallasBerry Per-Sensor MQTT

- Status: Draft for review
- Scope: DallasBerry multi-pin sensor acquisition, MQTT publishing, and Home Assistant integration
- Updated: 2026-10-24

## 1. Context

DallasBerry reads DS18B20 sensors on configured OneWire GPIOs. The current deployment uses GPIO 4 and GPIO 5 on Tasmota device `ESPTest01` (`192.168.168.173`). Twenty-three known sensors are mapped by 1-Wire ROM to a stable device ID and display name.

The previous MQTT format sent all sensors for a GPIO in one array payload. The target format is one message per sensor, with a stable topic, rounded scalar value, change-based publishing, a forced heartbeat, and retained state.

## 2. Goals

- Publish each valid sensor independently.
- Keep ROM-to-device-ID/name mapping in configuration, not application source.
- Suppress messages when only sub-precision measurement noise changes.
- Publish changed rounded values promptly and unchanged values at the heartbeat interval.
- Let new MQTT subscribers and Home Assistant receive each sensor's latest value.
- Preserve existing Home Assistant entity IDs.
- Keep topics independent of the Tasmota hostname.

## 3. Non-Goals

- Replacing Tasmota's native `tele/.../SENSOR` messages.
- Managing the MQTT broker or Home Assistant installation.
- MQTT discovery or automatic entity creation.
- Changing OneWire wiring or DallasBerry fault-detection behavior.
- Changing the separate LWP power and energy sensors.

## 4. Configuration

| Setting | Current default | Meaning |
| --- | --- | --- |
| `oneWirePins` | `[4, 5]` | GPIOs scanned for OneWire devices; at most eight. |
| `mqttTopicRoot` | `saar159/sensors` | Root topic; leading/trailing `/` are normalized away. |
| `mqttRoundDigits` | `1` | Decimal places used for comparison and published values; accepted range 0..6. |
| `mqttForcePublishIntervalSec` | `600` | Maximum interval between successful updates while the device is running. |
| `mqttDebugEnabled` | `true` in this workspace | Enables MQTT debug output. |
| `oneWireDeviceMap` | `HomeAssistant/dallasberry_mapping.be` | ROM-to-`device_id`/`device_name` map, packaged into the TAPP by `build.bat`. |

The build expects `HomeAssistant/dallasberry_mapping.be` beside the DallasBerry repository. Each map entry contains a ROM, `device_id`, and `device_name`. In the current mapping, `device_id` equals `device_name`.

## 5. MQTT Contract

### 5.1 Topic

```text
<mqttTopicRoot>/<device_id>
```

Example: `saar159/sensors/HZ-P-Unten_H01`. The topic is case-sensitive, has no leading slash, and does not contain the Tasmota hostname. The hostname remains in the payload for diagnostics.

### 5.2 Payload

Each topic carries one JSON object, not a `sensors[]` array:

```json
{
  "tasmota_name": "ESPTest01",
  "pin": 4,
  "device_id": "HZ-P-Unten_H01",
  "device_name": "HZ-P-Unten_H01",
  "sensor_id": "28B90517000000E3",
  "value": 29.7,
  "offset": 0,
  "timestamp": "2026-10-24T14:00:00",
  "last_measurement": "2026-10-24T14:00:00"
}
```

`value` is rounded to the configured precision. The MQTT retain flag is enabled.

### 5.3 Publish Rules

- Do not publish a sensor whose value is `nil`.
- Publish the first valid value after startup.
- Round before comparing with the last successfully published value.
- Publish when the rounded value changes.
- If unchanged, publish when `mqttForcePublishIntervalSec` expires since the last successful publish.
- Track last value and publish time independently per GPIO and ROM.
- On a publish failure, do not advance the cache; retry on a later valid collection.
- The cache is in memory. A Berry/Tasmota restart causes an initial publish after the next valid reading.

## 6. Home Assistant

`HomeAssistant/kellersensoren.yaml` defines 23 heating sensors using `saar159/sensors/<device_name>`. Each entity reads `value_json.value` and exposes device ID/name, ROM, GPIO, message timestamp, and measurement time as attributes. Existing `unique_id` values are preserved. Two LWP entities remain in the file. The HA topic does not need to change when the Tasmota hostname changes.

## 7. Acceptance Criteria

1. Each valid mapped sensor publishes only to `saar159/sensors/<device_id>`.
2. Payloads contain the mapped ID/name, ROM, GPIO, scalar value, and timestamps.
3. The Tasmota hostname is present in the payload but not the topic.
4. Values are rounded before change detection and before publication.
5. A changed rounded value publishes on the next successful collection.
6. An unchanged valid sensor publishes again no later than the configured heartbeat interval, subject to the collection cycle and running Berry VM.
7. Failed publishes do not update cached value or publish time.
8. A fresh subscriber receives retained state for sensors that have published successfully.
9. The 23 ROMs, DallasBerry mappings, and HA topic/entity definitions agree.
10. An invalid sensor does not block other sensors from publishing.

## 8. Verification Status

Previously tested against Tasmota ESP32-S3 `ESPTest01` at `192.168.168.173`: GPIO 4 reported 10 sensors and GPIO 5 reported 13 (23 total). Broker tests confirmed per-sensor, name-based topics, rounded values, and retained messages. The Home Assistant YAML parsed with 23 heating entities and two LWP entities; topic names, ROM mappings, and unique IDs were checked.

The full 600-second unchanged-value heartbeat has not been observed through a timed 10-minute test yet.

## 9. Open Questions

- Should MQTT debug logging default to `false` outside the test workspace?
- Should the 600-second heartbeat remain the production default?
- Is local MQTT API success sufficient, or should broker-level acknowledgement/monitoring be required?
- Should unmapped ROMs use the raw ROM as `device_id` and the generated DallasBerry name as `device_name`?
- Should legacy retained H01-H23 topics be removed after migration?