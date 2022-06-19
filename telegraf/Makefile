confs := $(patsubst %.conf.jinja,%.conf,$(wildcard *.conf.jinja))
uploadconfs := $(patsubst %.conf,upload-%,$(confs))

upload: $(uploadconfs)

upload-%: %.conf
	influx telegrafs -c workshop update -n $* -i $(shell influx telegrafs -c workshop --json | jq -r '.[] | select(.name == "$*") | .id') -f $<

%.conf: %.conf.jinja
	ionit -c static -t .
