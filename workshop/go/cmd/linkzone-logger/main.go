package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
	"github.com/quentinmit/isz/workshop/go/linkzone"
)

var (
	address  = flag.String("addr", "192.168.0.1", "address of the linkzone")
	interval = flag.Duration("interval", 10*time.Second, "interval for writing")
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
		if err := loop(context.Background(), writeApi); err != nil {
			log.Fatal(err)
		}
	}
}
func loop(ctx context.Context, writeApi api.WriteAPI) error {
	defer writeApi.Flush()
	c := linkzone.NewClient(*address)
	t := time.NewTicker(*interval)
	for {
		result := map[string]interface{}{}
		if err := c.Request(ctx, "GetNetworkInfo", nil, &result); err != nil {
			return err
		}
		report(writeApi, "networkinfo", result)
		result = map[string]interface{}{}
		if err := c.Request(ctx, "GetSystemStatus", nil, &result); err != nil {
			return err
		}
		report(writeApi, "systemstatus", result)
		result = map[string]interface{}{}
		if err := c.Request(ctx, "GetConnectionState", nil, &result); err != nil {
			return err
		}
		report(writeApi, "connectionstate", result)
		select {
		case <-t.C:
		}
	}
	return nil
}

// Query to cast old data:
// import "experimental"
// from(bucket: "icestationzebra")
//   |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
//   |> filter(fn: (r) => r["_measurement"] == "linkzone.networkinfo" and r["host"]=="workshop-pi.isz")
//   |> pivot(
//       rowKey:["_time"],
//       columnKey: ["_field"],
//       valueColumn: "_value")
//   |> map(fn: (r) => ({ r with _measurement: "linkzone.networkinfo6", Band: int(v: r.Band),
//   Roaming: int(v: r.Roaming),
//   Domestic_Roaming: int(v: r.Domestic_Roaming),
//   LTE_state: int(v: r.LTE_state),
//   RSCP: int(v: r.RSCP), NetworkType: int(v: r.NetworkType),
//   SignalStrength: int(v: r.SignalStrength) }))
//     |> experimental.to(
//       bucket: "icestationzebra"
//   )

func report(writeApi api.WriteAPI, name string, result map[string]interface{}) {
	fields := make(map[string]interface{})
	for k, v := range result {
		switch v := v.(type) {
		case json.Number:
			if i, err := v.Int64(); err == nil {
				fields[k] = i
			} else if f, err := v.Float64(); err == nil {
				fields[k] = f
			} else {
				fields[k] = v.String()
			}
		case string:
			i, err := strconv.Atoi(v)
			// CGI is hex so sometimes looks like an int
			if k != "CGI" && err == nil {
				fields[k] = i
			} else {
				fields[k] = v
			}
		case int:
			fields[k] = v
		case float64:
			fields[k] = v
		}
	}
	log.Printf("%s: %#v", name, fields)
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
