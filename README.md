# PowerEdge IPMI MQTT Home Assistant Add-on Repository

Home Assistant add-on repository for publishing Dell PowerEdge iDRAC/IPMI sensor data to MQTT.

The add-on reads sensor data from Dell iDRAC/IPMI using ipmitool sensor, publishes selected values to MQTT, and creates Home Assistant MQTT discovery sensors.

## Add-on

- poweredge_ipmi_mqtt

## Installation

In Home Assistant:

1. Go to Settings
2. Go to Add-ons
3. Open the Add-on Store
4. Open the three-dot menu
5. Select Repositories
6. Add this repository:

    https://github.com/hacwa/ha-poweredge-ipmi-mqtt

Then install PowerEdge IPMI MQTT.

## Requirements

- Dell PowerEdge server with iDRAC
- IPMI over LAN enabled in iDRAC
- MQTT broker available to Home Assistant
- Valid iDRAC credentials
- Valid MQTT credentials if your broker requires authentication

## Security

Do not commit real iDRAC or MQTT credentials.

All sensitive values are configured in the Home Assistant add-on configuration UI.

## Notes

This add-on is read-only. It does not control fan speed.

Default sensor names are based on Dell PowerEdge T-series style IPMI output, but they are configurable.
