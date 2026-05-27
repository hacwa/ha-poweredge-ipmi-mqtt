#!/usr/bin/env bash

set -euo pipefail

CONFIG_PATH="/data/options.json"

log() {
  echo "[poweredge-ipmi-mqtt] $*"
}

fail() {
  echo "[poweredge-ipmi-mqtt] ERROR: $*" >&2
  exit 1
}

get_config() {
  jq -r "$1" "$CONFIG_PATH"
}

require_config() {
  local value="$1"
  local name="$2"

  if [ -z "$value" ] || [ "$value" = "null" ]; then
    fail "Missing required option: ${name}"
  fi
}

sanitize_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g'
}

mqtt_publish() {
  local topic="$1"
  local payload="$2"
  local retain="${3:-false}"

  local args=(
    -h "$MQTT_HOST"
    -p "$MQTT_PORT"
    -t "$topic"
    -m "$payload"
  )

  if [ "$retain" = "true" ]; then
    args+=( -r )
  fi

  if [ -n "$MQTT_USER" ]; then
    args+=( -u "$MQTT_USER" )
  fi

  if [ -n "$MQTT_PASSWORD" ]; then
    args+=( -P "$MQTT_PASSWORD" )
  fi

  mosquitto_pub "${args[@]}"
}

ipmi_sensor_output() {
  ipmitool \
    -I lanplus \
    -H "$IDRAC_HOST" \
    -U "$IDRAC_USER" \
    -P "$IDRAC_PASSWORD" \
    sensor
}

normalise_sensor_name() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[[:space:]]\+/_/g' \
    | sed 's/[^a-z0-9_]/_/g' \
    | sed 's/__*/_/g' \
    | sed 's/^_//' \
    | sed 's/_$//'
}

sensor_device_class() {
  local unit="$1"

  case "$unit" in
    degrees_C)
      echo "temperature"
      ;;
    Watts)
      echo "power"
      ;;
    Volts)
      echo "voltage"
      ;;
    RPM)
      echo ""
      ;;
    percent)
      echo ""
      ;;
    *)
      echo ""
      ;;
  esac
}

sensor_unit() {
  local unit="$1"

  case "$unit" in
    degrees_C)
      echo "°C"
      ;;
    Watts)
      echo "W"
      ;;
    Volts)
      echo "V"
      ;;
    RPM)
      echo "RPM"
      ;;
    percent)
      echo "%"
      ;;
    *)
      echo "$unit"
      ;;
  esac
}

publish_discovery() {
  local sensor_key="$1"
  local friendly_name="$2"
  local raw_unit="$3"

  local unique_id="${DEVICE_IDENTIFIER}_${sensor_key}"
  local state_topic="${TOPIC_PREFIX}/${sensor_key}"
  local config_topic="${DISCOVERY_PREFIX}/sensor/${DEVICE_IDENTIFIER}/${sensor_key}/config"

  local unit
  unit="$(sensor_unit "$raw_unit")"

  local device_class
  device_class="$(sensor_device_class "$raw_unit")"

  local payload
  if [ -n "$device_class" ]; then
    payload="$(jq -cn \
      --arg name "${DEVICE_NAME} ${friendly_name}" \
      --arg unique_id "$unique_id" \
      --arg state_topic "$state_topic" \
      --arg unit "$unit" \
      --arg device_class "$device_class" \
      --arg device_identifier "$DEVICE_IDENTIFIER" \
      --arg device_name "$DEVICE_NAME" \
      '{
        name: $name,
        unique_id: $unique_id,
        state_topic: $state_topic,
        unit_of_measurement: $unit,
        device_class: $device_class,
        state_class: "measurement",
        device: {
          identifiers: [$device_identifier],
          name: $device_name,
          manufacturer: "Dell",
          model: "PowerEdge"
        }
      }'
    )"
  else
    payload="$(jq -cn \
      --arg name "${DEVICE_NAME} ${friendly_name}" \
      --arg unique_id "$unique_id" \
      --arg state_topic "$state_topic" \
      --arg unit "$unit" \
      --arg device_identifier "$DEVICE_IDENTIFIER" \
      --arg device_name "$DEVICE_NAME" \
      '{
        name: $name,
        unique_id: $unique_id,
        state_topic: $state_topic,
        unit_of_measurement: $unit,
        state_class: "measurement",
        device: {
          identifiers: [$device_identifier],
          name: $device_name,
          manufacturer: "Dell",
          model: "PowerEdge"
        }
      }'
    )"
  fi

  mqtt_publish "$config_topic" "$payload" true
}

publish_availability() {
  mqtt_publish "${TOPIC_PREFIX}/availability" "$1" true
}

IDRAC_HOST="$(get_config '.idrac_host')"
IDRAC_USER="$(get_config '.idrac_user')"
IDRAC_PASSWORD="$(get_config '.idrac_password')"
MQTT_HOST="$(get_config '.mqtt_host')"
MQTT_PORT="$(get_config '.mqtt_port')"
MQTT_USER="$(get_config '.mqtt_user // ""')"
MQTT_PASSWORD="$(get_config '.mqtt_password // ""')"
TOPIC_PREFIX="$(get_config '.topic_prefix')"
DISCOVERY_PREFIX="$(get_config '.discovery_prefix')"
DEVICE_NAME="$(get_config '.device_name')"
DEVICE_IDENTIFIER="$(sanitize_id "$(get_config '.device_identifier')")"
POLL_INTERVAL="$(get_config '.poll_interval')"

require_config "$IDRAC_HOST" "idrac_host"
require_config "$IDRAC_USER" "idrac_user"
require_config "$IDRAC_PASSWORD" "idrac_password"
require_config "$MQTT_HOST" "mqtt_host"
require_config "$MQTT_PORT" "mqtt_port"
require_config "$TOPIC_PREFIX" "topic_prefix"
require_config "$DISCOVERY_PREFIX" "discovery_prefix"
require_config "$DEVICE_NAME" "device_name"
require_config "$DEVICE_IDENTIFIER" "device_identifier"
require_config "$POLL_INTERVAL" "poll_interval"

log "Starting PowerEdge IPMI MQTT publisher"
log "iDRAC host: ${IDRAC_HOST}"
log "MQTT host: ${MQTT_HOST}:${MQTT_PORT}"
log "Topic prefix: ${TOPIC_PREFIX}"
log "Discovery prefix: ${DISCOVERY_PREFIX}"
log "Device name: ${DEVICE_NAME}"
log "Poll interval: ${POLL_INTERVAL}s"

trap 'publish_availability offline || true' EXIT

publish_availability "online"

DISCOVERY_PUBLISHED="false"

while true; do
  if ! SENSOR_OUTPUT="$(ipmi_sensor_output 2>&1)"; then
    log "Failed to read IPMI sensors"
    log "$SENSOR_OUTPUT"
    publish_availability "offline" || true
    sleep "$POLL_INTERVAL"
    continue
  fi

  publish_availability "online"

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    IFS='|' read -r raw_name raw_value raw_unit _ <<< "$line"

    name="$(echo "$raw_name" | xargs)"
    value="$(echo "$raw_value" | xargs)"
    unit="$(echo "$raw_unit" | xargs)"

    [ -z "$name" ] && continue
    [ -z "$value" ] && continue
    [ "$value" = "na" ] && continue
    [ "$value" = "N/A" ] && continue
    [ -z "$unit" ] && unit="raw"

    sensor_key="$(normalise_sensor_name "$name")"

    if [ -z "$sensor_key" ]; then
      continue
    fi

    if [ "$DISCOVERY_PUBLISHED" = "false" ]; then
      publish_discovery "$sensor_key" "$name" "$unit" || true
    fi

    mqtt_publish "${TOPIC_PREFIX}/${sensor_key}" "$value" false || true
  done <<< "$SENSOR_OUTPUT"

  DISCOVERY_PUBLISHED="true"

  sleep "$POLL_INTERVAL"
done
