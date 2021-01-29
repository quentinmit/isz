package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/itchyny/gojq"
)

func main() {
	if err := do(); err != nil {
		log.Fatal(err)
	}
}

type Response struct {
	StatusCode string      `json:"statusCode"`
	Data       interface{} `json:"responseData"`
}

func MustParse(query string) *gojq.Query {
	q, err := gojq.Parse(query)
	if err != nil {
		panic(err)
	}
	return q
}

func fetchAPI(c *http.Client, method string, params url.Values) (*Response, error) {
	eb := &backoff.ExponentialBackOff{
		InitialInterval:     30 * time.Second,
		RandomizationFactor: backoff.DefaultRandomizationFactor,
		Multiplier:          backoff.DefaultMultiplier,
		MaxInterval:         10 * time.Minute,
		MaxElapsedTime:      60 * time.Minute,
		Stop:                backoff.Stop,
		Clock:               backoff.SystemClock,
	}
	eb.Reset()
	for {
		resp, err := c.Get(fmt.Sprintf("https://api.cellmapper.net/v6/%s?%s", method, params.Encode()))
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()
		if resp.StatusCode != 200 {
			return nil, fmt.Errorf("unexpected status %s", resp.Status)
		}
		var body Response
		d := json.NewDecoder(resp.Body)
		if err := d.Decode(&body); err != nil {
			return nil, err
		}
		if body.StatusCode == "NEED_RECAPTCHA" {
			b := eb.NextBackOff()
			if b != backoff.Stop {
				log.Printf("rate limited; waiting %v", b)
				time.Sleep(b)
				continue
			}
		}
		if body.StatusCode != "OKAY" {
			return nil, fmt.Errorf("unexpected status code %s", body.StatusCode)
		}
		return &body, nil
	}
}

func mapToValues(in map[string]interface{}) url.Values {
	values := url.Values{}
	for k, v := range in {
		values[k] = []string{fmt.Sprintf("%v", v)}
	}
	return values
}

func fetchSite(c *http.Client, id string) {

}

var siteIDs = MustParse(`.[] | {MCC: $mcc, MNC: $mnc, RAT: .RAT, Region: .regionID, Site: .siteID}`)

const mcc = 310
const mnc = 120

func do() error {
	c := &http.Client{}
	args, _ := url.ParseQuery("MCC=310&MNC=120&RAT=LTE&boundsNELatitude=42.379882135199665&boundsNELongitude=-71.0525078738161&boundsSWLatitude=42.35413909110068&boundsSWLongitude=-71.15162583988901&filterFrequency=false&showOnlyMine=false&showUnverifiedOnly=false&showENDCOnly=false")
	resp, err := fetchAPI(c, "getTowers", args)
	if err != nil {
		return err
	}
	code, err := gojq.Compile(siteIDs, gojq.WithVariables([]string{
		"$mcc",
		"$mnc",
	}))
	if err != nil {
		return err
	}
	iter := code.Run(resp.Data, mcc, mnc)
	for {
		v, ok := iter.Next()
		if !ok {
			break
		}
		if err, ok := v.(error); ok {
			return err
		}
		if m, ok := v.(map[string]interface{}); ok {
			values := mapToValues(m)
			log.Printf("fetching: %v", values)
			resp, err := fetchAPI(c, "getTowerInformation", values)
			if err != nil {
				return err
			}
			log.Printf("site: %#v", resp)
			time.Sleep(1 * time.Second)
		} else {
			log.Printf("unexpected data: %#v", v)
		}

	}
	return nil
}
