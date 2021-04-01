package main

import (
	"bufio"
	"context"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/goburrow/serial"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
	"golang.org/x/sync/errgroup"
)

func main() {
	ctx := context.Background()
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
		if err := logData(ctx, writeApi); err != nil {
			log.Print(err)
		}
		time.Sleep(1 * time.Second)
	}
}

var valueRE = regexp.MustCompile(`([0-9.]+)([A-Za-z]*)`)

func logData(ctx context.Context, writeApi api.WriteAPI) error {
	defer writeApi.Flush()

	port, err := serial.Open(&serial.Config{Address: "/dev/ttyACM0"})
	if err != nil {
		return err
	}
	pingCh := make(chan struct{})
	eg, ctx := errgroup.WithContext(ctx)
	eg.Go(func() error {
		<-ctx.Done()
		return port.Close()
	})
	eg.Go(func() error {
		for {
			select {
			case <-pingCh:
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(10 * time.Second):
				if _, err := port.Write([]byte("\r")); err != nil {
					return err
				}
			}
		}
	})
	eg.Go(func() error {
		r := bufio.NewScanner(port)
		for r.Scan() {
			line := r.Text()
			if line == "" {
				continue
			}
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
			if len(fields) != 0 {
				pingCh <- struct{}{}
			}
			p := influxdb2.NewPoint("epicpwrgate.status",
				nil,
				fields,
				time.Now(),
			)
			// write asynchronously
			writeApi.WritePoint(p)
		}
		return r.Err()
	})
	return eg.Wait()
}
