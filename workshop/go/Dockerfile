FROM golang AS base

WORKDIR /go/src/app
COPY . .

RUN go install -v ./...

FROM base AS pwrgate-logger

CMD ["pwrgate-logger"]

FROM base AS linkzone-logger

CMD ["linkzone-logger"]
