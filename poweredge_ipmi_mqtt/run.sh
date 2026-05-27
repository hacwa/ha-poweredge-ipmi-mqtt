#!/usr/bin/env bash

set -u

CONFIG_PATH="/data/options.json"

log() {
  echo "[poweredge-ipmi-mqtt] $*"
}

get_config_value() {
  local key="$1"
  local fallback="$2"
  local value=""

  if [ -f "${CONFIG_PATH}" ]; then
    value="$(jq -r --arg key "${key}" '.[$key] // empty' "${CONFIG_PATH}" 2>/dev/null || true)"
  fi

  if [ -z "${value}" ] || [ "${value}" = "null" ]; then
    echo "${fallback}"
  else
    echo "${value}"
  fi
}

require_value() {
  local name="$1"
  local value="$2"

  if [ -z "${value}" ] || [ "${value}" = "null" ]; then
    log "Missing required configuration value: ${name}"
    exit 1
  fi
}

sanitize_identifier() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9_]/_/g' \
    | sed 's/__*/_/g' \
    | sed 's/^_//' \
    | sed 's/_$//'
}

IDRAC_HOST="$(get_config_value "idrac_host" "")"
IDRAC_USER="$(get_config_value "idrac_user" "root")"
IDRAC_PASSWORD="$(get_config_value "idrac_password" "")"

MQTT_HOST="$(get_config_value "mqtt_host" "a0d7b954-emqx")"
MQTT_PORT="$(get_config_value "mqtt_port" "1883")"
MQTT_USER="$(get_config_value "mqtt_user" "")"
MQTT_PASSWORD="$(get_config_value "mqtt_password" "")"

TOPIC_PREFIX="$(get_config_value "topic_prefix" "server/poweredge")"
DISCOVERY_PREFIX="$(get_config_value "discovery_prefix" "homeassistant")"
POLL_INTERVAL="$(get_config_value "poll_interval" "10")"

DEVICE_IDENTIFIER="$(sanitize_identifier "$(get_config_value "device_identifier" "poweredge_ipmi")")"
DEVICE_NAME="$(get_config_value "device_name" "Dell PowerEdge IPMI")"
DEVICE_MODEL="$(get_config_value "device_model" "PowerEdge")"

SENSOR_INLET_TEMP_NAME="$(get_config_value "sensor_inlet_temp_name" "Inlet Temp")"
SENSOR_TEMPERATURE_1_NAME="$(get_config_value "sensor_temperature_1_name" "Temp")"
SENSOR_FAN1_NAME="$(get_config_value "sensor_fan1_name" "Fan1")"
SENSOR_FAN2_NAME="$(get_config_value "sensor_fan2_name" "Fan2")"
SENSOR_POWER_CONSUMPTION_NAME="$(get_config_value "sensor_power_consumption_name" "Pwr Consumption")"
SENSOR_CURRENT_1_NAME="$(get_config_value "sensor_current_1_name" "Current 1")"
SENSOR_VOLTAGE_1_NAME="$(get_config_value "sensor_voltage_1_name" "Voltage 1")"
SENSOR_CPU_USAGE_NAME="$(get_config_value "sensor_cpu_usage_name" "CPU Usage")"
SENSOR_IO_USAGE_NAME="$(get_config_value "sensor_io_usage_name" "IO Usage")"
SENSOR_MEM_USAGE_NAME="$(get_config_value "sensor_mem_usage_name" "MEM Usage")"
SENSOR_SYS_USAGE_NAME="$(get_config_value "sensor_sys_usage_name" "SYS Usage")"

case "${POLL_INTERVAL}" in
  ''|*[!0-9]*)
    POLL_INTERVAL="10"
    ;;
esac

require_value "idrac_host" "${IDRAC_HOST}"
require_value "idrac_user" "${IDRAC_USER}"
require_value "idrac_password" "${IDRAC_PASSWORD}"
require_value "mqtt_host" "${MQTT_HOST}"
require_value "mqtt_port" "${MQTT_PORT}"
require_value "topic_prefix" "${TOPIC_PREFIX}"
require_value "discovery_prefix" "${DISCOVERY_PREFIX}"
require_value "device_identifier" "${DEVICE_IDENTIFIER}"
require_value "device_name" "${DEVICE_NAME}"
require_value "device_model" "${DEVICE_MODEL}"

mqtt_pub() {
  local topic="$1"
  local payload="$2"
  local retain="${3:-false}"

  local args=(
    -h "${MQTT_HOST}"
    -p "${MQTT_PORT}"
    -t "${topic}"
    -m "${payload}"
  )

  if [ -n "${MQTT_USER}" ]; then
    args+=( -u "${MQTT_USER}" )
  fi

  if [ -n "${MQTT_PASSWORD}" ]; then
    args+=( -P "${MQTT_PASSWORD}" )
  fi

  if [ "${retain}" = "true" ]; then
    args+=( -r )
  fi

  mosquitto_pub "${args[@]}"
}

ipmi_sensor() {
  ipmitool \
    -I lanplus \
    -H "${IDRAC_HOST}" \
    -U "${IDRAC_USER}" \
    -P "${IDRAC_PASSWORD}" \
    sensor 2>&1
}

publish_discovery_sensor() {
  local object_id="$1"
  local friendly_name="$2"
  local state_topic="$3"
  local unit="$4"
  local device_class="$5"

  local discovery_topic="${DISCOVERY_PREFIX}/sensor/${DEVICE_IDENTIFIER}/${object_id}/config"

  if [ -n "${device_class}" ]; then
    payload="$(
      cat <<JSON
{
  "name": "${friendly_name}",
  "unique_id": "${DEVICE_IDENTIFIER}_${object_id}",
  "state_topic": "${state_topic}",
  "availability_topic": "${TOPIC_PREFIX}/availability",
  "payload_available": "online",
  "payload_not_available": "offline",
  "unit_of_measurement": "${unit}",
  "device_class": "${device_class}",
  "state_class": "measurement",
  "device": {
    "identifiers": ["${DEVICE_IDENTIFIER}"],
    "name": "${DEVICE_NAME}",
    "manufacturer": "Dell",
    "model": "${DEVICE_MODEL}"
  }
}
JSON
    )"
  else
    payload="$(
      cat <<JSON
{
  "name": "${friendly_name}",
  "unique_id": "${DEVICE_IDENTIFIER}_${object_id}",
  "state_topic": "${state_topic}",
  "availability_topic": "${TOPIC_PREFIX}/availability",
  "payload_available": "online",
  "payload_not_available": "offline",
  "unit_of_measurement": "${unit}",
  "state_class": "measurement",
  "device": {
    "identifiers": ["${DEVICE_IDENTIFIER}"],
    "name": "${DEVICE_NAME}",
    "manufacturer": "Dell",
    "model": "${DEVICE_MODEL}"
  }
}
JSON
    )"
  fi

  mqtt_pub "${discovery_topic}" "${payload}" true || log "Failed to publish discovery for ${object_id}"
}

publish_discovery() {
  publish_discovery_sensor "server_inlet_temp" "${DEVICE_NAME} Inlet Temp" "${TOPIC_PREFIX}/server_inlet_temp" "°C" "temperature"
  publish_discovery_sensor "temperature_1" "${DEVICE_NAME} Temperature 1" "${TOPIC_PREFIX}/temperature_1" "°C" "temperature"
  publish_discovery_sensor "server_fan1_speed" "${DEVICE_NAME} Fan 1 Speed" "${TOPIC_PREFIX}/server_fan1_speed" "RPM" ""
  publish_discovery_sensor "server_fan2_speed" "${DEVICE_NAME} Fan 2 Speed" "${TOPIC_PREFIX}/server_fan2_speed" "RPM" ""
  publish_discovery_sensor "power_consumption" "${DEVICE_NAME} Power Consumption" "${TOPIC_PREFIX}/power_consumption" "W" "power"
  publish_discovery_sensor "current_1" "${DEVICE_NAME} Current 1" "${TOPIC_PREFIX}/current_1" "A" "current"
  publish_discovery_sensor "voltage_1" "${DEVICE_NAME} Voltage 1" "${TOPIC_PREFIX}/voltage_1" "V" "voltage"
  publish_discovery_sensor "cpu_usage" "${DEVICE_NAME} CPU Usage" "${TOPIC_PREFIX}/cpu_usage" "%" ""
  publish_discovery_sensor "io_usage" "${DEVICE_NAME} IO Usage" "${TOPIC_PREFIX}/io_usage" "%" ""
  publish_discovery_sensor "mem_usage" "${DEVICE_NAME} Memory Usage" "${TOPIC_PREFIX}/mem_usage" "%" ""
  publish_discovery_sensor "sys_usage" "${DEVICE_NAME} System Usage" "${TOPIC_PREFIX}/sys_usage" "%" ""
}

get_sensor_value_by_name() {
  local wanted="$1"

  echo "${SENSOR_OUTPUT}" | awk -F'|' -v wanted="${wanted}" '
    {
      name=$1
      value=$2
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/^[ \t]+|[ \t]+$/, "", value)

      if (name == wanted && value != "na" && value != "N/A" && value != "") {
        print value
        exit
      }
    }
  '
}

publish_known_sensor_if_present() {
  local ipmi_name="$1"
  local mqtt_name="$2"

  local value
  value="$(get_sensor_value_by_name "${ipmi_name}")"

  if [ -n "${value}" ]; then
    mqtt_pub "${TOPIC_PREFIX}/${mqtt_name}" "${value}" false && log "Published ${mqtt_name}=${value}"
  else
    log "Sensor unavailable: ${ipmi_name}"
  fi
}

log "Starting PowerEdge IPMI MQTT add-on"
log "iDRAC host: ${IDRAC_HOST}"
log "MQTT host: ${MQTT_HOST}:${MQTT_PORT}"

if [ -n "${MQTT_USER}" ]; then
  log "MQTT user: ${MQTT_USER}"
else
  log "MQTT user: none"
fi

log "Topic prefix: ${TOPIC_PREFIX}"
log "Discovery prefix: ${DISCOVERY_PREFIX}"
log "Poll interval: ${POLL_INTERVAL}"
log "Device identifier: ${DEVICE_IDENTIFIER}"
log "Device name: ${DEVICE_NAME}"
log "Device model: ${DEVICE_MODEL}"

mqtt_pub "${TOPIC_PREFIX}/availability" "online" true || log "MQTT unavailable at startup"
publish_discovery

while true; do
  SENSOR_OUTPUT="$(ipmi_sensor)"

  if ! echo "${SENSOR_OUTPUT}" | grep -q '|'; then
    log "IPMI returned no parseable sensor table"
    log "${SENSOR_OUTPUT}"
    mqtt_pub "${TOPIC_PREFIX}/availability" "offline" true || true
    sleep "${POLL_INTERVAL}"
    continue
  fi

  mqtt_pub "${TOPIC_PREFIX}/availability" "online" true || log "Failed to publish availability"

  publish_known_sensor_if_present "${SENSOR_INLET_TEMP_NAME}" "server_inlet_temp"
  publish_known_sensor_if_present "${SENSOR_TEMPERATURE_1_NAME}" "temperature_1"
  publish_known_sensor_if_present "${SENSOR_FAN1_NAME}" "server_fan1_speed"
  publish_known_sensor_if_present "${SENSOR_FAN2_NAME}" "server_fan2_speed"
  publish_known_sensor_if_present "${SENSOR_POWER_CONSUMPTION_NAME}" "power_consumption"
  publish_known_sensor_if_present "${SENSOR_CURRENT_1_NAME}" "current_1"
  publish_known_sensor_if_present "${SENSOR_VOLTAGE_1_NAME}" "voltage_1"
  publish_known_sensor_if_present "${SENSOR_CPU_USAGE_NAME}" "cpu_usage"
  publish_known_sensor_if_present "${SENSOR_IO_USAGE_NAME}" "io_usage"
  publish_known_sensor_if_present "${SENSOR_MEM_USAGE_NAME}" "mem_usage"
  publish_known_sensor_if_present "${SENSOR_SYS_USAGE_NAME}" "sys_usage"

  sleep "${POLL_INTERVAL}"
done
