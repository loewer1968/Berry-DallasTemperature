# Berry-DallasTemperature

A Berry application for DS18B20 temperature sensors

## Motivation

I attach great importance to stable error detection.

Unfortunately, the power-on-reset value of the sensor with the value 85 is not clear.</br>
The application tries to eliminate this disadvantage.

If a sensor is used in an application, its status must be signaled even if it is not connected.</br>
The registration method takes this requirement into account.

## Different Scenes

After start of application without connected sensors

- sensores are connected but no bus-scan has done

![Scene-01](images/scene01.png)

After bus-scan has performed

![Scene-02](images/scene02.png)

After sensor's device-0 data-pin is yanked

![Scene-02](images/scene03.png)

## How to install

The active workspace configures GPIO 4 and GPIO 5 in `DallasTemp01.be` using `oneWirePins`. Edit that list to select up to eight OneWire GPIOs. Do not configure a GPIO used by this application in Tasmota's **Configuration / Configure Module** menu.

From the `Berry-DallasTemperature` directory, run `build.bat -u -r`. The script builds `DallasTemp.tapp`, uploads it and the user override files, then restarts the controller.

The build expects the mapping file at the sibling workspace path `../HomeAssistant/dallasberry_mapping.be` and packages it as `ha_mapping.be`. If you cloned this repository by itself, place that mapping file in the expected sibling `HomeAssistant` directory before building.

After that the "After start of application" scene should be visible.

## MQTT and Home Assistant

Configure the MQTT root, debug logging, value precision, and heartbeat in `configure01.be`:

```berry
mqttTopicRoot = "saar159"
mqttDebugEnabled = true
mqttRoundDigits = 1
mqttForcePublishIntervalSec = 600
```

Each sensor is published independently to:

```text
saar159/<tasmota-name>/<device-id>
```

The payload includes `device_id`, `device_name`, `sensor_id` (the 1-Wire ROM), `pin`, `value`, `offset`, `timestamp`, and `last_measurement`. The value is rounded to `mqttRoundDigits` decimal places. A message is sent when the rounded value changes, or after `mqttForcePublishIntervalSec` seconds even if it has not changed. Messages are retained so a new subscriber receives the last value.

### ROM mapping

Keep the mapping in the workspace-level file `../HomeAssistant/dallasberry_mapping.be`, not in the Berry source. Each ROM maps to both the topic-level device ID and the display name:

```berry
oneWireDeviceMap = {
  "28B90517000000E3": {
    "device_id": "HZ-P-Unten_H01",
    "device_name": "HZ-P-Unten_H01"
  }
}
```

`device_id` becomes the final MQTT topic level. `device_name` is included in the payload and used as the sensor's displayed name. `build.bat` packages this mapping as `ha_mapping.be`; the mapping file must be present beside the DallasBerry repository in the `HomeAssistant` folder when building.

### Home Assistant

The 23 heating entities are configured in `../HomeAssistant/kellersensoren.yaml`. Each entity subscribes to `saar159/<tasmota-name>/<device-name>` and reads `value_json.value`; the JSON attributes include the device ID/name, ROM, GPIO, and measurement timestamps. Preserve the entity `unique_id` values when changing display names to avoid creating duplicate entities in Home Assistant.

The DallasBerry topics use the Tasmota hostname, for example `ESPTest01`. Replace that segment in the HA YAML if the device hostname changes.

### Live test

Tested on a Tasmota ESP32-S3 at `192.168.168.173` with GPIO 4 and GPIO 5 enabled. The device detected 10 sensors on GPIO 4 and 13 on GPIO 5 (23 total). Broker checks confirmed one retained message per mapped sensor topic, with live updates when the rounded value changed. The configured 600-second unchanged-value heartbeat is documented but was not observed through a full 10-minute wait during this test.

All fork-specific adaptations described in this guide were developed with GitHub Copilot assistance.

### Registered vs. temporary sensors

A sensor is registered via its address.
- the application is constantly trying to read values ​​from this sensor
- it cannot be deleted from the list of sensors to be detected.

### Button 'Scan'

Initiates the Bus-Scanning process, that collects the available devices.

### Button 'Clear list'

All temporary sensors will be cleared in the task list, but never those sensors, which are registered.

```be
device = dallasTemp.register("28C9229E2022089E")
device.name = "myDevice.02"
device.offset = 1

```

### Enable Logging

The berry-variable 'dallasTemp' is global.

Use following statement in the Berry-Console to obtain more log-information.

```be
    dallasTemp.infoEnable=true

```

### Enable/disable enrichment of the sensor message tele/.../SENSOR

```be
    dallasTemp.enableSensorMsg=true

```

If 'enableSensorMsg' is activated then the sensor messages will be extended like

```json
 {
	"Time": "2024-01-16T18:42:21",
	"ANALOG": {
		"Illuminance1": 0
	},
	"OneWire.Group.01": {
		"gpio": 16,
		"devices": [
			{
				"address": "28C9229E2022089E",
				"name": "Boiler Temperature",
				"value": 33.0,
				"hasError": false
			}
		]
	},
	"TempUnit": "C"
}     

```

The sensor value is calculated depending on 'SetOption8'.

### Fault detection

- The application detects the error when the GND/power/data pin is faulty. In this case, the status “hasError” is set to “true”.
- After an error detection, 2 consecutive valid values ​​are required to reset the hasError flag.

### Freeze value on error

If the freezeOnError property is enabled (default setting), the last captured value will not be changed as long as the capture is in error.

```be
    device = dallasTemp.register("28C9229E2022089E")
    device.freezeOnError = true      # default value is true

```
