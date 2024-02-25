package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"strconv"
	"strings"
	"time"

	"github.com/goburrow/serial"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
)

var (
	device  = flag.String("d", "", "device node to connect to")
	file    = flag.String("f", "", "file to read packets from")
	verbose = flag.Bool("v", false, "log individual packets")
)

const (
	// 1880 = normal
	// 1980 = "hardware fault" (yellow light on solid; manual says is charging)
	// 0084 = buffer mode
	// Normal buffer->happy sequence
	// 0180 - load on PSU, not charging
	// 0880 - load on PSU, charging
	// 1880 - load on PSU, charging
	// 1980 - load on PSU, charging, yellow light on ("charging <85%")
	// 1880 - load on PSU, charged
	BufferMode = 0x0004
	Charging   = 0x0100
)

type Status struct {
	DeviceID [2]byte
	// PSUMilliAmps is the power output from the internal PSU.
	// Subtract BatteryInAmps to get the current drawn by the load.
	PSUAmps float64 `wago:"0,1000"`
	// BatteryVolts is the battery voltage
	BatteryVolts float64 `wago:"1,100"`
	// BatteryOutAmps is the amperage being drawn from the battery (in buffer mode)
	BatteryOutAmps            float64 `wago:"2,1000"`
	TemperatureDegreesCelsius float64 `wago:"3,100"`
	OutputVolts               float64 `wago:"4,100"`
	PSUVolts                  float64 `wago:"5,100"`
	BatteryInAmps             float64 `wago:"6,1000"`
	Status                    uint16  `wago:"7"`
	// 3 = infinite, 2 = PC mode, 4 = custom
	SwitchPosition uint16 `wago:"8"`
}

func (s *Status) LoadAmps() float64 {
	return s.PSUAmps - s.BatteryInAmps + s.BatteryOutAmps
}

func (s *Status) String() string {
	return fmt.Sprintf("PSU: %0.2fV %0.2fA Output: %0.2fV %0.2fA Battery: %0.2fV %+0.2fA %+0.2fA Temperature: %0.2f°C Status: %04x SwitchPosition: %04x",
		s.PSUVolts, s.PSUAmps,
		s.OutputVolts, s.LoadAmps(),
		s.BatteryVolts, -s.BatteryOutAmps, s.BatteryInAmps,
		s.TemperatureDegreesCelsius, s.Status, s.SwitchPosition,
	)
}

func parseFields(r io.Reader, out interface{}) error {
	outV := reflect.Indirect(reflect.ValueOf(out))
	t := outV.Type()
	type Field struct {
		Field   int
		Divisor int
	}
	tagToField := make(map[int]Field)
	for i := 0; i < t.NumField(); i++ {
		sf := t.Field(i)
		if tag := sf.Tag.Get("wago"); tag != "" {
			parts := strings.Split(tag, ",")
			field := Field{
				Field: i,
			}
			if len(parts) > 1 {
				divisor, err := strconv.Atoi(parts[1])
				if err == nil {
					field.Divisor = divisor
				}
			}
			wagoTag, err := strconv.Atoi(parts[0])
			if err == nil {
				tagToField[wagoTag] = field
			}
		}
	}
	for {
		var tag byte
		if err := binary.Read(r, binary.BigEndian, &tag); err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}
		if f, ok := tagToField[int(tag)]; ok {
			field := outV.Field(f.Field)
			if f.Divisor != 0 {
				var ival int16
				if err := binary.Read(r, binary.BigEndian, &ival); err != nil {
					return err
				}
				field.SetFloat(float64(ival) / float64(f.Divisor))
			} else {
				if err := binary.Read(r, binary.BigEndian, field.Addr().Interface()); err != nil {
					return err
				}
			}
		} else {
			return fmt.Errorf("unknown field tag: %d", tag)
		}
	}
}

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
		if *file != "" {
			return
		}
	}
}
func loop(writeApi api.WriteAPI) error {
	defer writeApi.Flush()
	var f io.ReadCloser
	var err error
	if *file != "" {
		f, err = os.Open(*file)
		defer f.Close()
		if err != nil {
			log.Fatal(err)
		}
	} else if *device != "" {
		f, err = serial.Open(&serial.Config{Address: *device, BaudRate: 9600, Parity: "N"})
		if err != nil {
			return err
		}
		defer f.Close()
	} else {
		log.Fatal("device or file must be specified")
	}
	return logData(writeApi, f)
}

func logData(writeApi api.WriteAPI, f io.Reader) error {
	r := bufio.NewReader(f)
	for {
		b, err := r.ReadByte()
		switch err {
		case io.EOF:
			return nil
		case nil:
		default:
			return err
		}
		if b == 0x55 {
			r.UnreadByte()
			header, err := r.Peek(6)
			switch err {
			case io.EOF:
				return nil
			case nil:
			default:
				return err
			}
			if header[0] != 0x55 || header[1] != 0xAA {
				r.ReadByte()
				// Look for next 0x55
				continue
			}
			deviceID := header[2:4]
			packetType := header[4]
			size := header[5]
			packet := make([]byte, len(header)+int(size)+1)
			if _, err := io.ReadFull(r, packet); err != nil {
				return err
			}
			var checksum byte
			for _, b := range packet {
				checksum ^= b
			}
			if checksum != 0 {
				log.Printf("failed checksum: % x", packet)
				continue
			}
			switch packetType {
			case 3:
				var status Status
				if err := parseFields(bytes.NewReader(packet[6:len(packet)-1]), &status); err != nil {
					log.Printf("failed to parse packet: % x: %v", packet, err)
					continue
				}
				copy(status.DeviceID[:], deviceID)
				status.Report(writeApi)
				if *verbose {
					log.Printf("%s", &status)
				}
			}
		}
	}
	return nil
}

func (s *Status) Report(writeApi api.WriteAPI) {
	fields := make(map[string]interface{})
	v := reflect.Indirect(reflect.ValueOf(s))
	t := v.Type()
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		fields[f.Name] = v.Field(i).Interface()
	}
	p := influxdb2.NewPoint("wago.status",
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
