package main

import (
	"bufio"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/goburrow/serial"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
)

func main() {
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
		if err := logData(writeApi); err != nil {
			log.Print(err)
		}
		time.Sleep(1 * time.Second)
	}
}

var valueRE = regexp.MustCompile(`([0-9.]+)([A-Za-z]*)`)

func logData(writeApi api.WriteAPI) error {
	defer writeApi.Flush()

	port, err := serial.Open(&serial.Config{Address: "/dev/ttyACM0"})
	if err != nil {
		return err
	}
	defer port.Close()
	r := bufio.NewScanner(port)
	for r.Scan() {
		line := r.Text()
		log.Printf("read %q", line)

		fields := make(map[string]interface{})
		state := ""

		scanner := bufio.NewScanner(strings.NewReader(line))
		scanner.Split(bufio.ScanWords)
		var key string
		for scanner.Scan() {
			text := scanner.Text()
			if len(fields) == 0 {
				if strings.Contains(text, "=") {
					if len(state) > 0 {
						fields["state"] = state[1:]
					}
				} else {
					state += " " + text
					continue
				}
			}
			if strings.Contains(text, "=") {
				parts := strings.SplitN(text, "=", 2)
				key, text = parts[0], parts[1]
			}
			if parts := valueRE.FindStringSubmatch(text); parts != nil {
				value, err := strconv.ParseFloat(parts[1], 64)
				if err != nil {
					log.Printf("failed to parse %q", parts[1])
				}
				unit := parts[2]
				field := key
				if len(unit) > 0 {
					field += "." + unit
				}
				fields[field] = value
			}
		}
		log.Printf("Received data %v", fields)
		p := influxdb2.NewPoint("epicpwrgate.status",
			nil,
			fields,
			time.Now(),
		)
		// write asynchronously
		writeApi.WritePoint(p)
	}
	return r.Err()
}
