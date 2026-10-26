# DallasBerry setup

Quick setup for running the DS18B20 Berry application on a Tasmota device.

## 1. Wire the sensor

Connect the DS18B20 `VDD` to 3.3 V, `GND` to ground, and `DQ` to an available GPIO. Add a 4.7 kΩ pull-up resistor between `DQ` and 3.3 V. For multiple sensors, connect them in parallel on the same 1-Wire bus.

## 2. Configure Tasmota and this project

- Use a Tasmota device with Berry and MQTT enabled and connected to your broker.
- Choose the 1-Wire GPIOs and set them in `DallasTemp01.be` as `oneWirePins = [4, 5]` (up to eight pins). Change the example pins to match your wiring. **Do not assign these pins in Tasmota's Configuration / Configure Module menu.**
- Set the MQTT topic root and publish options in `configure01.be` (`mqttTopicRoot`, precision, and heartbeat).
- Create `../HomeAssistant/dallasberry_mapping.be` beside this repository. The build requires it; map each sensor ROM to its topic ID and display name:

  ```berry
  oneWireDeviceMap = {
    "28B90517000000E3": {
      "device_id": "living-room",
      "device_name": "Living room"
    }
  }
  ```

  Find sensor ROMs after deployment using the web UI's **Scan** button. A mapping can be updated and the app rebuilt afterward.

## 3. Build and deploy (Windows)

In `build.bat`, set `host` to the Tasmota device's IP address. Ensure 7-Zip is installed at the configured path; the script also uses `curl` and `git`. From this repository's directory, run:

```bat
build.bat -u -r
```

This creates `DallasTemp.tapp`, uploads it and the `DallasTemp01.be` / `DallasTemp02.be` overrides, then restarts Tasmota. The mapping file is packaged into the TAPP as `ha_mapping.be`.

## 4. Verify

Open the Tasmota web UI and confirm the Dallas temperature panel appears. Use **Scan** to discover connected sensors and check their readings. Confirm that MQTT publishes each mapped sensor at `<mqttTopicRoot>/<device_id>`; messages are retained and republished on value changes or the configured heartbeat.
