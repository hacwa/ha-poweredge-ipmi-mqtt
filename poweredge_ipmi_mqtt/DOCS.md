# PowerEdge IPMI MQTT Documentation

## Example configuration

Use your own values in Home Assistant. Do not commit real credentials to Git.

    idrac_host: "192.0.2.10"
    idrac_user: "root"
    idrac_password: "change_me"
    mqtt_host: "a0d7b954-emqx"
    mqtt_port: 1883
    mqtt_user: ""
    mqtt_password: ""
    topic_prefix: "server/poweredge"
    discovery_prefix: "homeassistant"
    poll_interval: 10
    device_identifier: "poweredge_ipmi"
    device_name: "Dell PowerEdge IPMI"
    device_model: "PowerEdge"
    sensor_inlet_temp_name: "Inlet Temp"
    sensor_temperature_1_name: "Temp"
    sensor_fan1_name: "Fan1"
    sensor_fan2_name: "Fan2"
    sensor_power_consumption_name: "Pwr Consumption"
    sensor_current_1_name: "Current 1"
    sensor_voltage_1_name: "Voltage 1"
    sensor_cpu_usage_name: "CPU Usage"
    sensor_io_usage_name: "IO Usage"
    sensor_mem_usage_name: "MEM Usage"
    sensor_sys_usage_name: "SYS Usage"

## Options

### idrac_host

The iDRAC IP address or hostname.

### idrac_user

The iDRAC username.

### idrac_password

The iDRAC password.

### mqtt_host

The MQTT broker hostname.

Default:

    a0d7b954-emqx

### mqtt_port

The MQTT broker port.

Default:

    1883

### mqtt_user

Optional MQTT username.

### mqtt_password

Optional MQTT password.

### topic_prefix

MQTT topic prefix for sensor states.

Example:

    server/poweredge

### discovery_prefix

Home Assistant MQTT discovery prefix.

Default:

    homeassistant

### poll_interval

Polling interval in seconds.

### device_identifier

Stable Home Assistant MQTT discovery device identifier.

### device_name

Friendly device name shown in Home Assistant.

### device_model

Device model shown in Home Assistant.

### sensor_*_name

The exact IPMI sensor names to read from ipmitool sensor.

## Security

Do not commit real credentials.

Use a dedicated iDRAC user if possible.

## Limitations

This add-on is read-only.

It does not control fan speed.
