package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/AdamSLevy/jsonrpc2/v14"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
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
	c := &jsonrpc2.Client{
		Header: http.Header{
			"_TclRequestVerificationKey": []string{"KSDHSDFOGQ5WERYTUIQWERTYUISDFG1HJZXCVCXBN2GDSMNDHKVKFsVBNf"},
			"Referer":                    []string{fmt.Sprintf("http://%s/", *address)},
		},
	}
	t := time.NewTicker(*interval)
	for {
		result := map[string]interface{}{}
		if err := request(c, ctx, fmt.Sprintf("http://%s/jrd/webapi", *address), "GetNetworkInfo", nil, &result); err != nil {
			return err
		}
		report(writeApi, "networkinfo", result)
		result = map[string]interface{}{}
		if err := request(c, ctx, fmt.Sprintf("http://%s/jrd/webapi", *address), "GetConnectionState", nil, &result); err != nil {
			return err
		}
		report(writeApi, "connectionstate", result)
		select {
		case <-t.C:
		}
	}
	return nil
}

func request(c *jsonrpc2.Client, ctx context.Context, url, method string,
	params, result interface{}) error {

	// Generate a psuedo random ID for this request.
	reqID := strconv.Itoa(rand.Int()%5000 + 1)

	// Marshal the JSON RPC Request.
	req := jsonrpc2.Request{ID: reqID, Method: method, Params: params}
	reqData, err := req.MarshalJSON()
	if err != nil {
		return err
	}

	// Compose the HTTP request.
	httpReq, err := http.NewRequest(http.MethodPost, url, bytes.NewBuffer(reqData))
	if err != nil {
		return err
	}
	if ctx != nil {
		httpReq = httpReq.WithContext(ctx)
	}
	httpReq.Header.Add(http.CanonicalHeaderKey("Content-Type"), "application/json")
	for k, v := range c.Header {
		httpReq.Header[http.CanonicalHeaderKey(k)] = v
	}
	if c.BasicAuth {
		httpReq.SetBasicAuth(c.User, c.Password)
	}

	// Make the request.
	httpRes, err := c.Do(httpReq)
	if err != nil {
		return err
	}
	defer httpRes.Body.Close()

	// Unmarshal the HTTP response into a JSON RPC response.
	var resID string
	var raw json.RawMessage
	res := jsonrpc2.Response{Result: &raw, ID: &resID}
	d := json.NewDecoder(httpRes.Body)
	if err := d.Decode(&res); err != nil {
		return err
	}
	d = json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	if err := d.Decode(result); err != nil {
		return err
	}
	if res.HasError() {
		return res.Error
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
