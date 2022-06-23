FROM golang:bullseye as builder
WORKDIR /usr/src/app

COPY telegraf/go.mod telegraf/go.sum ./
RUN go mod download -x && go mod verify

COPY telegraf /usr/src/app
RUN make docs include_packages="amd64.deb"
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install ruby ruby-dev rubygems build-essential && gem install --no-document fpm
RUN make package include_packages="amd64.deb"

FROM builder

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iputils-ping snmp procps lm-sensors libcap2-bin && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/build/dist/*.deb .

RUN dpkg -i telegraf_*.deb && \
    rm -f telegraf_*.deb*

EXPOSE 8125/udp 8092/udp 8094

COPY influxdata-docker/telegraf/nightly/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
