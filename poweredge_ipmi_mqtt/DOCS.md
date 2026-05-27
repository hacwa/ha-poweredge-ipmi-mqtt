# PowerEdge IPMI MQTT Documentation

## Configuration

Example configuration:

idrac_host: "192.168.1.100"
idrac_user: "monitoring"
idrac_password: "your_password"
mqtt_host: "core-mosquitto"
mqtt_port: 1883
mqtt_user: ""
mqtt_password: ""
topic_prefix: "server/poweredge"
discovery_prefix: "homeassistant"
device_name: "Dell PowerEdge"
device_identifier: "poweredge_ipmi"
poll_interval: 10

## Options

### idrac_host

The hostname or IP address of the iDRAC interface.

Example:

idrac_host: "192.168.1.100"

### idrac_user

The iDRAC username used for IPMI access.

Use a dedicated monitoring account where possible.

### idrac_password

The password for the iDRAC user.

### mqtt_host

The MQTT broker hostname.

For the official Home Assistant Mosquitto add-on, this is usually:

mqtt_host: "core-mosquitto"

### mqtt_port

The MQTT broker port.

Default:

mqtt_port: 1883

### mqtt_user

Optional MQTT username.

Leave empty if your broker does not require a username.

### mqtt_password

Optional MQTT password.

Leave empty if your broker does not require a password.

### topic_prefix

MQTT topic prefix used for state publishing.

Example:

topic_prefix: "server/poweredge"

Sensor states will be published under topics such as:

server/poweredge/fan1
server/poweredge/inlet_temp
server/poweredge/power_consumption

Exact topic names depend on the sensor names returned by iDRAC/IPMI.

### discovery_prefix

Home Assistant MQTT discovery prefix.

Default:

discovery_prefix: "homeassistant"

### device_name

Friendly device name shown in Home Assistant.

Example:

device_name: "Dell PowerEdge R730"

### device_identifier

Stable identifier used by Home Assistant MQTT discovery.

Use only letters, numbers and underscores.

Example:

device_identifier: "dell_poweredge_r730"

### poll_interval

How often to poll IPMI sensors, in seconds.

Default:

poll_interval: 10

## iDRAC requirements

IPMI over LAN must be enabled in iDRAC.

The iDRAC user must be allowed to read sensor data.

## MQTT discovery

The add-on publishes MQTT discovery config for each detected sensor.

Discovery config is retained.

Sensor state messages are not retained.

## Availability

The add-on publishes availability to:

server/poweredge/availability

Values:

online
offline

## Security

Do not publish real credentials in Git.

Do not use your main iDRAC administrator account unless absolutely required.

## Limitations

Sensor names and available values depend on the PowerEdge model, iDRAC version and firmware.

This add-on currently performs read-only monitoring. It does not control fan speed.
