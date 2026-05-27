# PowerEdge IPMI MQTT

Publishes Dell PowerEdge iDRAC/IPMI sensor data to MQTT for Home Assistant.

This add-on reads sensor data using `ipmitool sensor` and publishes values to MQTT. It also publishes Home Assistant MQTT discovery configuration for detected sensors.

## Features

- Reads Dell PowerEdge sensor data over IPMI LAN
- Publishes sensor values to MQTT
- Publishes Home Assistant MQTT discovery entities
- Supports configurable MQTT topic prefix
- Supports configurable Home Assistant discovery prefix
- Supports configurable device name and identifier
- Read-only monitoring only

## Requirements

- Dell PowerEdge server with iDRAC
- IPMI over LAN enabled in iDRAC
- Valid iDRAC credentials
- MQTT broker available to Home Assistant

## Notes

This add-on does not currently control fan speed. It only monitors and publishes available IPMI sensor values.

Fan control may be added later, but should be opt-in and include safe defaults.
