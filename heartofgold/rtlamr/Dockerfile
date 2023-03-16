FROM docker.io/golang

RUN go install -v github.com/bemasher/rtlamr@latest && go install -v github.com/bemasher/rtlamr-collect@latest

ENV RTLAMR_FORMAT=json

CMD rtlamr | rtlamr-collect
