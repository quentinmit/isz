FROM golang

RUN go get -v github.com/bemasher/rtlamr github.com/bemasher/rtlamr-collect

ENV RTLAMR_FORMAT=json

CMD rtlamr | rtlamr-collect
