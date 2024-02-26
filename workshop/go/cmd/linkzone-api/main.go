package main

import (
	"context"
	"flag"
	"log"

	"github.com/quentinmit/isz/workshop/go/linkzone"
)

var (
	address  = flag.String("addr", "192.168.0.1", "address of the linkzone")
	username = flag.String("user", "admin", "username")
	password = flag.String("password", "", "password")
	reboot   = flag.Bool("reboot", false, "reboot the device")
)

func main() {
	ctx := context.Background()
	flag.Parse()
	c := linkzone.NewClient(*address)
	if err := c.Login(ctx, *username, *password); err != nil {
		log.Panic(err)
	}
	loginstate, err := c.GetLoginState(ctx)
	if err != nil {
		log.Panic(err)
	}
	log.Printf("Login state: %+v", loginstate)
	if *reboot {
		res := map[string]interface{}{}
		if err := c.Request(ctx, "SetDeviceReboot", nil, &res); err != nil {
			log.Panic(err)
		}
		log.Printf("reboot response: %+v", res)
	}
}
