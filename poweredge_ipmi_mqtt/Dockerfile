FROM ghcr.io/home-assistant/base:latest

RUN apk add --no-cache \
    bash \
    jq \
    ipmitool \
    mosquitto-clients

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
