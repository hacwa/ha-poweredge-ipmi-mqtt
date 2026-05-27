# PowerEdge IPMI MQTT Home Assistant Add-on Repository

This repository provides a Home Assistant add-on for publishing Dell PowerEdge iDRAC/IPMI sensor data to MQTT.

The add-on is intended for Dell PowerEdge servers with IPMI over LAN enabled through iDRAC.

## Add-on

- `poweredge_ipmi_mqtt` - Publishes IPMI sensor readings to MQTT and creates Home Assistant MQTT discovery entities.

## Installation

In Home Assistant:

1. Go to Settings.
2. Go to Add-ons.
3. Open the Add-on Store.
4. Select the three-dot menu.
5. Select Repositories.
6. Add this repository URL:

https://github.com/hacwa/ha-poweredge-ipmi-mqtt

## Requirements

- Dell PowerEdge server with iDRAC
- IPMI over LAN enabled in iDRAC
- Home Assistant MQTT broker, for example Mosquitto
- Valid iDRAC username and password

## Security notes

This add-on requires iDRAC/IPMI credentials. Use a dedicated iDRAC user with the minimum permissions required to read sensors.

Do not commit real IP addresses, usernames, or passwords into this repository.
