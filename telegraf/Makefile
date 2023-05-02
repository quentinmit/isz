confs := $(patsubst %.conf.jinja,%.conf,$(wildcard *.conf.jinja))
uploadconfs := $(patsubst %.conf,upload-%,$(confs))

upload: $(uploadconfs)

upload-%: %.conf
	set -ex; \
	id=$$(influx telegrafs -c workshop --json | jq -r '.configurations[] | select(.name == "$*") | .id'); \
	if [ -z "$$id" ]; then \
		influx telegrafs -c workshop create -n $* -f $<; \
	else \
		influx telegrafs -c workshop update -n $* -i "$$id" -f $<; \
	fi

%.conf: %.conf.jinja base.conf.jinja static/* scripts/*
	ionit -c static -t .

static/he_lg.json: bin/generate_he_lg.py
	$< > $@
