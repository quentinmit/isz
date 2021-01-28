package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/rpc"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
)

var (
	address = flag.String("addr", "192.168.0.1", "address of the linkzone")
)

func main() {
	flag.Parse()
	// Create client
	server := os.Getenv("INFLUX_SERVER")
	if server == "" {
		server = "http://localhost:9999"
	}
	client := influxdb2.NewClient(server, os.Getenv("INFLUX_TOKEN"))
	defer client.Close()
	// Get non-blocking write client
	writeApi := client.WriteAPI("icestationzebra", "icestationzebra")
	// Get errors channel
	errorsCh := writeApi.Errors()
	// Create go proc for reading and logging errors
	go func() {
		for err := range errorsCh {
			log.Printf("write error: %v", err)
		}
	}()
	for {
		if err := loop(writeApi); err != nil {
			log.Fatal(err)
		}
	}
}
func loop(writeApi api.WriteAPI) error {
	defer writeApi.Flush()
	c, err := rpc.DialHTTP(fmt.Sprintf("http://%s/jrd/webapi", *address))
	if err != nil {
		return err
	}
	c.SetHeader("_TclRequestVerificationKey", "KSDHSDFOGQ5WERYTUIQWERTYUISDFG1HJZXCVCXBN2GDSMNDHKVKFsVBNf")
	c.SetHeader("Referer", fmt.Sprintf("http://%s/", *address))
	t := time.NewTicker(30 * time.Second)
	for {
		select {
		case <-t.C:
			result := map[string]interface{}{}
			if err := c.Call(&result, "GetNetworkInfo", nil); err != nil {
				return err
			}
			report(writeApi, "networkinfo", result)
		}
	}
	return nil
}

func report(writeApi api.WriteAPI, name string, result map[string]interface{}) {
	fields := make(map[string]interface{})
	for k, v := range result {
		switch v := v.(type) {
		case string:
			i, err := strconv.Atoi(v)
			if err == nil {
				// TODO: What if the value is hex? ("CGI")
				fields[k] = i
			} else {
				fields[k] = v
			}
		case int:
			fields[k] = v
		}
	}
	p := influxdb2.NewPoint(fmt.Sprintf("linkzone.%s", name),
		map[string]string{
			"host": hostname,
		},
		fields,
		time.Now(),
	)
	writeApi.WritePoint(p)
}

var hostname string

func init() {
	hostname, _ = os.Hostname()
}
