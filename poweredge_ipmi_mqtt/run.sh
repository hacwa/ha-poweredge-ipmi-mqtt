#!/usr/bin/env bash

set -u

CONFIG_PATH="/data/options.json"

log() {
  echo "[poweredge-ipmi-mqtt] $*"
}

get_root_config_value() {
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

get_server_value() {
  local server_json="$1"
  local key="$2"
  local fallback="$3"
  local value=""

  value="$(echo "${server_json}" | jq -r --arg key "${key}" '.[$key] // empty' 2>/dev/null || true)"

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
    return 1
  fi

  return 0
}

sanitize_identifier() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9_]/_/g' \
    | sed 's/__*/_/g' \
    | sed 's/^_//' \
    | sed 's/_$//'
}

MQTT_HOST="$(get_root_config_value "mqtt_host" "a0d7b954-emqx")"
MQTT_PORT="$(get_root_config_value "mqtt_port" "1883")"
MQTT_USER="$(get_root_config_value "mqtt_user" "")"
MQTT_PASSWORD="$(get_root_config_value "mqtt_password" "")"
DISCOVERY_PREFIX="$(get_root_config_value "discovery_prefix" "homeassistant")"
POLL_INTERVAL="$(get_root_config_value "poll_interval" "10")"

case "${POLL_INTERVAL}" in
  ''|*[!0-9]*)
    POLL_INTERVAL="10"
    ;;
esac

require_value "mqtt_host" "${MQTT_HOST}" || exit 1
require_value "mqtt_port" "${MQTT_PORT}" || exit 1
require_value "discovery_prefix" "${DISCOVERY_PREFIX}" || exit 1

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
  local idrac_host="$1"
  local idrac_user="$2"
  local idrac_password="$3"

  ipmitool \
    -I lanplus \
    -H "${idrac_host}" \
    -U "${idrac_user}" \
    -P "${idrac_password}" \
    sensor 2>&1
}

publish_discovery_sensor() {
  local device_identifier="$1"
  local device_name="$2"
  local device_model="$3"
  local topic_prefix="$4"
  local object_id="$5"
  local friendly_name="$6"
  local state_topic="$7"
  local unit="$8"
  local device_class="$9"

  local discovery_topic="${DISCOVERY_PREFIX}/sensor/${device_identifier}/${object_id}/config"

  if [ -n "${device_class}" ]; then
    payload="$(
      cat <<JSON
{
  "name": "${friendly_name}",
  "unique_id": "${device_identifier}_${object_id}",
  "state_topic": "${state_topic}",
  "availability_topic": "${topic_prefix}/availability",
  "payload_available": "online",
  "payload_not_available": "offline",
  "unit_of_measurement": "${unit}",
  "device_class": "${device_class}",
  "state_class": "measurement",
  "device": {
    "identifiers": ["${device_identifier}"],
    "name": "${device_name}",
    "manufacturer": "Dell",
    "model": "${device_model}"
  }
}
JSON
    )"
  else
    payload="$(
      cat <<JSON
{
  "name": "${friendly_name}",
  "unique_id": "${device_identifier}_${object_id}",
  "state_topic": "${state_topic}",
  "availability_topic": "${topic_prefix}/availability",
  "payload_available": "online",
  "payload_not_available": "offline",
  "unit_of_measurement": "${unit}",
  "state_class": "measurement",
  "device": {
    "identifiers": ["${device_identifier}"],
    "name": "${device_name}",
    "manufacturer": "Dell",
    "model": "${device_model}"
  }
}
JSON
    )"
  fi

  mqtt_pub "${discovery_topic}" "${payload}" true || log "Failed to publish discovery for ${device_identifier}/${object_id}"
}

publish_discovery_for_server() {
  local device_identifier="$1"
  local device_name="$2"
  local device_model="$3"
  local topic_prefix="$4"

  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "server_inlet_temp" "${device_name} Inlet Temp" "${topic_prefix}/server_inlet_temp" "°C" "temperature"
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "temperature_1" "${device_name} Temperature 1" "${topic_prefix}/temperature_1" "°C" "temperature"
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "server_fan1_speed" "${device_name} Fan 1 Speed" "${topic_prefix}/server_fan1_speed" "RPM" ""
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "server_fan2_speed" "${device_name} Fan 2 Speed" "${topic_prefix}/server_fan2_speed" "RPM" ""
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "power_consumption" "${device_name} Power Consumption" "${topic_prefix}/power_consumption" "W" "power"
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "current_1" "${device_name} Current 1" "${topic_prefix}/current_1" "A" "current"
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "voltage_1" "${device_name} Voltage 1" "${topic_prefix}/voltage_1" "V" "voltage"
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "cpu_usage" "${device_name} CPU Usage" "${topic_prefix}/cpu_usage" "%" ""
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "io_usage" "${device_name} IO Usage" "${topic_prefix}/io_usage" "%" ""
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "mem_usage" "${device_name} Memory Usage" "${topic_prefix}/mem_usage" "%" ""
  publish_discovery_sensor "${device_identifier}" "${device_name}" "${device_model}" "${topic_prefix}" "sys_usage" "${device_name} System Usage" "${topic_prefix}/sys_usage" "%" ""
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
  local topic_prefix="$1"
  local ipmi_name="$2"
  local mqtt_name="$3"

  local value
  value="$(get_sensor_value_by_name "${ipmi_name}")"

  if [ -n "${value}" ]; then
    mqtt_pub "${topic_prefix}/${mqtt_name}" "${value}" false && log "Published ${topic_prefix}/${mqtt_name}=${value}"
  else
    log "Sensor unavailable for ${topic_prefix}: ${ipmi_name}"
  fi
}

read_servers() {
  if [ ! -f "${CONFIG_PATH}" ]; then
    return 1
  fi

  jq -c '.servers[]?' "${CONFIG_PATH}" 2>/dev/null
}

SERVER_COUNT="$(read_servers | wc -l | tr -d ' ')"

if [ "${SERVER_COUNT}" = "0" ]; then
  log "No servers configured under servers:"
  exit 1
fi

log "Starting PowerEdge IPMI MQTT add-on"
log "MQTT host: ${MQTT_HOST}:${MQTT_PORT}"

if [ -n "${MQTT_USER}" ]; then
  log "MQTT user: ${MQTT_USER}"
else
  log "MQTT user: none"
fi

log "Discovery prefix: ${DISCOVERY_PREFIX}"
log "Poll interval: ${POLL_INTERVAL}"
log "Configured servers: ${SERVER_COUNT}"

while IFS= read -r SERVER_JSON; do
  SERVER_NAME="$(get_server_value "${SERVER_JSON}" "name" "Dell PowerEdge")"
  DEVICE_MODEL="$(get_server_value "${SERVER_JSON}" "device_model" "PowerEdge")"
  DEVICE_IDENTIFIER="$(sanitize_identifier "$(get_server_value "${SERVER_JSON}" "device_identifier" "")")"
  TOPIC_PREFIX="$(get_server_value "${SERVER_JSON}" "topic_prefix" "")"

  if ! require_value "servers[].device_identifier" "${DEVICE_IDENTIFIER}"; then
    continue
  fi

  if ! require_value "servers[].topic_prefix" "${TOPIC_PREFIX}"; then
    continue
  fi

  publish_discovery_for_server "${DEVICE_IDENTIFIER}" "${SERVER_NAME}" "${DEVICE_MODEL}" "${TOPIC_PREFIX}"
done < <(read_servers)

while true; do
  while IFS= read -r SERVER_JSON; do
    SERVER_NAME="$(get_server_value "${SERVER_JSON}" "name" "Dell PowerEdge")"
    IDRAC_HOST="$(get_server_value "${SERVER_JSON}" "idrac_host" "")"
    IDRAC_USER="$(get_server_value "${SERVER_JSON}" "idrac_user" "root")"
    IDRAC_PASSWORD="$(get_server_value "${SERVER_JSON}" "idrac_password" "")"
    TOPIC_PREFIX="$(get_server_value "${SERVER_JSON}" "topic_prefix" "")"
    DEVICE_IDENTIFIER="$(sanitize_identifier "$(get_server_value "${SERVER_JSON}" "device_identifier" "")")"

    SENSOR_INLET_TEMP_NAME="$(get_server_value "${SERVER_JSON}" "sensor_inlet_temp_name" "Inlet Temp")"
    SENSOR_TEMPERATURE_1_NAME="$(get_server_value "${SERVER_JSON}" "sensor_temperature_1_name" "Temp")"
    SENSOR_FAN1_NAME="$(get_server_value "${SERVER_JSON}" "sensor_fan1_name" "Fan1")"
    SENSOR_FAN2_NAME="$(get_server_value "${SERVER_JSON}" "sensor_fan2_name" "Fan2")"
    SENSOR_POWER_CONSUMPTION_NAME="$(get_server_value "${SERVER_JSON}" "sensor_power_consumption_name" "Pwr Consumption")"
    SENSOR_CURRENT_1_NAME="$(get_server_value "${SERVER_JSON}" "sensor_current_1_name" "Current 1")"
    SENSOR_VOLTAGE_1_NAME="$(get_server_value "${SERVER_JSON}" "sensor_voltage_1_name" "Voltage 1")"
    SENSOR_CPU_USAGE_NAME="$(get_server_value "${SERVER_JSON}" "sensor_cpu_usage_name" "CPU Usage")"
    SENSOR_IO_USAGE_NAME="$(get_server_value "${SERVER_JSON}" "sensor_io_usage_name" "IO Usage")"
    SENSOR_MEM_USAGE_NAME="$(get_server_value "${SERVER_JSON}" "sensor_mem_usage_name" "MEM Usage")"
    SENSOR_SYS_USAGE_NAME="$(get_server_value "${SERVER_JSON}" "sensor_sys_usage_name" "SYS Usage")"

    if ! require_value "${SERVER_NAME} idrac_host" "${IDRAC_HOST}"; then
      continue
    fi

    if ! require_value "${SERVER_NAME} idrac_user" "${IDRAC_USER}"; then
      continue
    fi

    if ! require_value "${SERVER_NAME} idrac_password" "${IDRAC_PASSWORD}"; then
      continue
    fi

    if ! require_value "${SERVER_NAME} topic_prefix" "${TOPIC_PREFIX}"; then
      continue
    fi

    if ! require_value "${SERVER_NAME} device_identifier" "${DEVICE_IDENTIFIER}"; then
      continue
    fi

    log "Polling ${SERVER_NAME} at ${IDRAC_HOST}"

    SENSOR_OUTPUT="$(ipmi_sensor "${IDRAC_HOST}" "${IDRAC_USER}" "${IDRAC_PASSWORD}")"

    if ! echo "${SENSOR_OUTPUT}" | grep -q '|'; then
      log "IPMI returned no parseable sensor table for ${SERVER_NAME}"
      log "${SENSOR_OUTPUT}"
      mqtt_pub "${TOPIC_PREFIX}/availability" "offline" true || true
      continue
    fi

    mqtt_pub "${TOPIC_PREFIX}/availability" "online" true || log "Failed to publish availability for ${SERVER_NAME}"

    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_INLET_TEMP_NAME}" "server_inlet_temp"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_TEMPERATURE_1_NAME}" "temperature_1"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_FAN1_NAME}" "server_fan1_speed"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_FAN2_NAME}" "server_fan2_speed"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_POWER_CONSUMPTION_NAME}" "power_consumption"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_CURRENT_1_NAME}" "current_1"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_VOLTAGE_1_NAME}" "voltage_1"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_CPU_USAGE_NAME}" "cpu_usage"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_IO_USAGE_NAME}" "io_usage"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_MEM_USAGE_NAME}" "mem_usage"
    publish_known_sensor_if_present "${TOPIC_PREFIX}" "${SENSOR_SYS_USAGE_NAME}" "sys_usage"
  done < <(read_servers)

  sleep "${POLL_INTERVAL}"
done
