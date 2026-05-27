# PowerEdge IPMI MQTT Documentation

## Example configuration

Set this in the Home Assistant add-on configuration UI.

    mqtt_host: "a0d7b954-emqx"
    mqtt_port: 1883
    mqtt_user: "mqtt"
    mqtt_password: "your_mqtt_password"
    discovery_prefix: "homeassistant"
    poll_interval: 10
    servers:
      - name: "Dell PowerEdge 1"
        idrac_host: "192.0.2.10"
        idrac_user: "root"
        idrac_password: "your_idrac_password"
        topic_prefix: "server/poweredge_1"
        device_identifier: "poweredge_1_ipmi"
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
      - name: "Dell PowerEdge 2"
        idrac_host: "192.0.2.11"
        idrac_user: "root"
        idrac_password: "your_idrac_password"
        topic_prefix: "server/poweredge_2"
        device_identifier: "poweredge_2_ipmi"
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

## Required uniqueness

These must be unique per server:

    topic_prefix
    device_identifier

## Security

Do not commit real iDRAC or MQTT credentials.

Configure credentials only in Home Assistant.
