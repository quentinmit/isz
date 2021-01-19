package main

import (
	"bufio"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/goburrow/serial"
)

var (
	device = flag.String("d", "", "device node to connect to")
	file   = flag.String("f", "", "file to read packets from")
)

type Packet struct {
	// Packet format is:
	// Header: ((0xE4 [\x21\x23\x25])|(0x55 0xAA 0xE5 [\x1\x11\x12] 0x03)
	// Size < 0x5a
	// Fields
	// If bytes[2] == 0xE5: checksum that makes xor=0
	// Magic is always 55 AA E5 01 03 1B
	// Magic is always 55 AA
	Magic [2]byte
	// DeviceID is E5 01
	DeviceID [2]byte
	Unknown  byte
	// Size is 1B (code checks <5A)
	// This counts the following data bytes not including checksum
	Size byte
	// always 0
	Header0         byte
	OutputMilliAmps int16
	// always 1
	Header1          byte
	ChargeCentiVolts int16
	// always 2
	Header2         byte
	BufferMilliAmps int16
	// always 3
	Header3                        byte
	TemperatureCentiDegreesCelsius int16
	// always 4
	Header4          byte
	OutputCentiVolts int16
	// always 5
	Header5 byte
	// centivolts?
	Unknown5 int16
	// always 6
	Header6         byte
	ChargeMilliAmps int16
	// always 7
	Header7 byte
	// flags?
	Status uint16
	// always 8
	Header8 byte
	// always 00 03?
	SwitchPosition uint16
	// official software also handles 0x0a as bitfield
	Checksum byte
}

func (p *Packet) String() string {
	return fmt.Sprintf("Output: %0.2fV %0.2fA Battery: %0.2fV %0.2fA Charge: %0.2fV %0.2fA Temperature: %0.2f°C Status: %04x SwitchPosition: %04x 5: %x",
		float64(p.OutputCentiVolts)/100, float64(p.OutputMilliAmps)/1000,
		float64(p.ChargeCentiVolts)/100, float64(p.BufferMilliAmps)/1000,
		float64(p.ChargeCentiVolts)/100, float64(p.ChargeMilliAmps)/1000,
		float64(p.TemperatureCentiDegreesCelsius)/100, p.Status, p.SwitchPosition, p.Unknown5,
	)
}

func (p *Packet) Validate() error {
	if p.Magic != [2]byte{0x55, 0xAA} {
		return fmt.Errorf("unexpected magic %v", p.Magic)
	}
	if p.DeviceID != [2]byte{0xE5, 0x01} {
		return fmt.Errorf("unexpected device ID %v", p.DeviceID)
	}
	// Unknown 0x03
	if p.Size != 0x1B { // < 0x5A
		return fmt.Errorf("unexpected size: %x", p.Size)
	}
	if p.Header0 != 0 {
		return fmt.Errorf("unexpected header0: %x", p.Header0)
	}
	if p.Header1 != 1 {
		return fmt.Errorf("unexpected header1: %x", p.Header1)
	}
	if p.Header2 != 2 {
		return fmt.Errorf("unexpected header2: %x", p.Header2)
	}
	if p.Header3 != 3 {
		return fmt.Errorf("unexpected header3: %x", p.Header3)
	}
	if p.Header4 != 4 {
		return fmt.Errorf("unexpected header4: %x", p.Header4)
	}
	if p.Header5 != 5 {
		return fmt.Errorf("unexpected header5: %x", p.Header5)
	}
	if p.Header6 != 6 {
		return fmt.Errorf("unexpected header6: %x", p.Header6)
	}
	if p.Header7 != 7 {
		return fmt.Errorf("unexpected header7: %x", p.Header7)
	}
	if p.Header8 != 8 {
		return fmt.Errorf("unexpected header8: %x", p.Header8)
	}
	return nil
}

// wago-4 has battery voltage ~26.44 charge current ~0.02 output voltage ~23.97 output current ~0.13

func main() {
	flag.Parse()
	if got := binary.Size(Packet{}); got != 34 {
		panic(fmt.Sprintf("Packet has %d bytes, wanted 34", got))
	}
	if err := loop(); err != nil {
		log.Fatal(err)
	}
}
func loop() error {
	var f io.ReadCloser
	var err error
	if *file != "" {
		f, err = os.Open(*file)
		defer f.Close()
		if err != nil {
			log.Fatal(err)
		}
	} else if *device != "" {
		f, err = serial.Open(&serial.Config{Address: *device})
		if err != nil {
			return err
		}
		defer f.Close()
	} else {
		log.Fatal("device or file must be specified")
	}
	return logData(f)
}

func logData(f io.Reader) error {
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
			magic, err := r.Peek(2)
			switch err {
			case io.EOF:
				return nil
			case nil:
			default:
				return err
			}
			if magic[0] != 0x55 || magic[1] != 0xAA {
				r.ReadByte()
				// Look for next 0x55
				continue
			}
			var packet Packet
			if err := binary.Read(r, binary.BigEndian, &packet); err != nil {
				return err
			}
			if err := packet.Validate(); err != nil {
				log.Printf("failed validation: %v", err)
				log.Printf("packet: %+v", packet)
			}
			log.Printf("%s", &packet)
		}
	}
	return nil
}
