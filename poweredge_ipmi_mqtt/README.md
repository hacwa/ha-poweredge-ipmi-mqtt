# PowerEdge IPMI MQTT

Publishes Dell PowerEdge iDRAC/IPMI sensor data to MQTT for Home Assistant.

## What it does

- Runs ipmitool sensor
- Extracts configured sensor names
- Publishes sensor values to MQTT
- Publishes Home Assistant MQTT discovery config
- Publishes availability state

## Default MQTT host

The default MQTT host is:

    a0d7b954-emqx

This is suitable for the EMQX Home Assistant add-on. If using Mosquitto, change mqtt_host to the relevant broker hostname.

## Configuration

All private values must be set in the Home Assistant add-on configuration UI.

Required values:

- idrac_host
- idrac_user
- idrac_password
- mqtt_host
- mqtt_port
- topic_prefix
- discovery_prefix
- device_identifier
- device_name
- device_model

MQTT username and password are optional.

## Sensor mapping

The add-on publishes these MQTT topic suffixes:

| Sensor | Topic suffix |
|---|---|
| Inlet temperature | server_inlet_temp |
| Temperature 1 | temperature_1 |
| Fan 1 speed | server_fan1_speed |
| Fan 2 speed | server_fan2_speed |
| Power consumption | power_consumption |
| Current 1 | current_1 |
| Voltage 1 | voltage_1 |
| CPU usage | cpu_usage |
| IO usage | io_usage |
| Memory usage | mem_usage |
| System usage | sys_usage |

The IPMI sensor names are configurable because Dell models and firmware versions can expose different names.
