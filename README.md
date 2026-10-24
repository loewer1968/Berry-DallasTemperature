# Berry-DallasTemperature

A Berry application for DS18B20 temperature sensors

This application

- scans one or more 1-Wire buses for DS18B20 sensors (up to eight configured GPIOs)
- captures each sensor's ROM ID and acquires temperature values
- checks value validity, detects bus faults, and identifies unsupported/fake sensor families
- supports per-sensor offsets, SetOption8 (Celsius/Fahrenheit), and freeze-on-error
- displays sensor state and controls in the Tasmota web UI
- publishes each mapped sensor to its own MQTT topic when the rounded value changes
- republishes unchanged values on a configurable heartbeat interval
- provides a ROM-to-device-ID/device-name mapping for Home Assistant

Find more [information](ReadmeDallasTemp.md)

# Berry-ThingSpeak

If you want to store, aggregate and visualize data without a smart home server at all, Mathlab's ThingSpeak service is very helpful.

The Berry driver 'ThingSpeak' makes it easy to use ThingSpeak.

Find more [information](ReadmeThingSpeak.md)

## DallasBerry MQTT and Home Assistant

The active configuration publishes each sensor independently below `saar159/<tasmota-name>/<device-id>`. The ROM mapping, device IDs, and display names are maintained in the sibling workspace file `../HomeAssistant/dallasberry_mapping.be`. Home Assistant entities and topics are defined in `../HomeAssistant/kellersensoren.yaml`.

MQTT defaults are configured in `configure01.be`: one decimal place and a forced update every 600 seconds. Messages are retained.

## Fork and acknowledgements

This repository is a fork of [wjohn007/Berry-DallasTemperature](https://github.com/wjohn007/Berry-DallasTemperature). Thank you to the original author for the DS18B20 Berry driver and application this fork builds upon.

The active fork is [loewer1968/Berry-DallasTemperature](https://github.com/loewer1968/Berry-DallasTemperature).

All fork-specific adaptations described here were developed with GitHub Copilot assistance. The application was tested against a Tasmota ESP32-S3 at `192.168.168.173`: GPIO 4 detected 10 sensors and GPIO 5 detected 13, for 23 sensors total. Live MQTT checks confirmed individual retained messages using the mapped sensor names.

