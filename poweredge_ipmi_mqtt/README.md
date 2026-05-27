# PowerEdge IPMI MQTT

Publishes Dell PowerEdge iDRAC/IPMI sensor data to MQTT for Home Assistant.

## What it does

- Supports multiple Dell PowerEdge servers from one add-on instance
- Runs ipmitool sensor against each configured iDRAC
- Extracts configured sensor names
- Publishes sensor values to MQTT
- Publishes Home Assistant MQTT discovery config
- Publishes per-server availability state

## Configuration

Configure servers in the Home Assistant add-on configuration UI.

Each server must have a unique topic_prefix and device_identifier.

## MQTT host

Default MQTT host:

    a0d7b954-emqx

Use this for the EMQX Home Assistant add-on. If using Mosquitto, change mqtt_host to the correct broker hostname.

## Notes

This add-on is read-only. It does not control fan speed.
