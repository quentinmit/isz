#!/usr/bin/env python3

import argparse
from datetime import datetime, date, time, timedelta
import io
from itertools import chain
import json
import logging
import os
import sys
import time
from zoneinfo import ZoneInfo

import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import mpl_toolkits.axisartist as axisartist
import numpy as mp

from influxdb_client import InfluxDBClient, Point, Dialect
import paho.mqtt.client as mqtt

logging.basicConfig(level=logging.DEBUG)

mpl.use("module://backend_pil")
mpl.rc("axes", unicode_minus=False)

TZ = ZoneInfo('America/New_York')

class Grapher:
    def __init__(self):
        self.influx_client = InfluxDBClient(url="https://influx.isz.wtf", token=os.getenv("INFLUX_TOKEN"), org="icestationzebra")
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.connect("mqtt.isz.wtf")
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.loop_start()

        self.query_api = self.influx_client.query_api()

        self.width = 1024
        self.height = 100

        self.p = {
            "defaultBucket": "icestationzebra",
            "windowPeriod": timedelta(minutes=10),
            "timeRangeStart": timedelta(hours=-30),
            "timeRangeStop": timedelta(days=3),
        }

    def fetch_weathergram(self):
        tables = self.query_api.query("""
import "experimental"
import "strings"

from(bucket: defaultBucket)
  |> range(start: timeRangeStart, stop: timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "temperature")// or r["_field"] == "humidity")
  |> filter(fn: (r) => r["city"] == "Cambridge")
  |> filter(fn: (r) => r["city_id"] == "4931972")
  |> group(columns: ["host", "_measurement", "_field", "_time"], mode:"by")
//  |> aggregateWindow(every: windowPeriod, fn: mean, createEmpty: false)
  |> filter(fn: (r) => r.forecast == "*" or r._time > now())
  |> map(fn: (r) => ({r with age: if r.forecast == "*" then 0 else int(v: duration(v: r.forecast))}))
  |> sort(columns: ["age"], desc: false)
  |> first()
  |> group(columns: ["host", "_measurement", "_field"])
  |> keep(columns: ["_measurement", "_field", "_time", "_value"])
  |> map(fn: (r) => ({r with _measurement: r._field}))
  |> yield(name: "accuweather")

from(bucket: defaultBucket)
  |> range(start: timeRangeStart, stop: timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "temp")
  |> filter(fn: (r) => r["chip"] == "w1")
  |> filter(fn: (r) => r.sensor == "0120541bbaa7")
  |> aggregateWindow(every: windowPeriod, fn: mean, createEmpty: false)
  //|> map(fn: (r) => ({r with _value: r._value * 9./5. + 32.}))
  |> keep(columns: ["_start", "_stop", "_time", "_value", "sensor", "_measurement", "_field", "host"])
  //|> map(fn: (r) => ({r with run_name: "local"}))
  //|> group(columns: ["_start", "_stop", "_measurement", "_field"])
  //|> drop(columns: ["sensor", "name", "host"])
  |> yield(name: "local")
""", params=self.p)

        out = {}

        for table in tables:
            result = table.records[0]['result']
            if result == "local":
                name = "localtemp"
            elif result == "accuweather":
                name = "aw"+table.records[0]['_field']
            times = []
            values = []
            for record in table.records:
                times.append(record["_time"])
                values.append(record["_value"])
            out[name] = (times, values)
        return out

    def plot_weathergram(self):
        tables = self.fetch_weathergram()
        timestamps = list(chain.from_iterable(times for times,_ in tables.values()))
        logging.debug("time = %s - %s", min(timestamps), max(timestamps))

        xmin = datetime.now() - timedelta(hours=24)

        fig = plt.figure(subplotpars=mpl.figure.SubplotParams(0,0,1,1))
        ax = fig.add_axes((0,0,1,1), axes_class=axisartist.Axes)
        ax.set_xlim(left=xmin, right=max(timestamps))
        ax.xaxis.set_major_locator(mdates.DayLocator(tz=TZ))
        ax.xaxis.set_minor_locator(mdates.HourLocator(interval=6, tz=TZ))
        ax.xaxis.set_major_formatter(mdates.DateFormatter(' %A'))
        ax.yaxis.set_major_formatter("{x:.0f}°C")
        ax.axis[:].invert_ticklabel_direction()
        ax.axis[:].major_ticks.set_tick_out(True)
        ax.axis[:].minor_ticks.set_tick_out(True)
        ax.axis[:].major_ticks.set_ticksize(8)
        ax.axis[:].minor_ticks.set_ticksize(6)
        ax.axis["top"].major_ticklabels.set_visible(True)
        ax.axis["top"].major_ticklabels.set_ha("left")
        ax.axis["top"].major_ticklabels.set_pad(0)
        ax.axis["bottom"].major_ticklabels.set_visible(False)
        ax.axis["top"].major_ticklabels.set_fontfamily("knxt")
        ax.axis["left"].major_ticklabels.set_fontfamily("clean")

        for name, (times, values) in tables.items():
            ax.plot(times, values, linewidth=1.5 if name == "localtemp" else 0.8)
        ax.grid(axis='x', linestyle='dotted')

        return fig

    def subscribe(self):
        self.mqtt_client.subscribe("livingroom/inkplate/meteogram/size", 0)

    def on_message(self, client, userdata, msg):
        topic = msg.topic
        if not topic.endswith("/size"):
            return
        topic = topic[:-len("/size")]
        logging.debug("Received message for %s: %s", topic, msg.payload)
        payload = json.loads(msg.payload)
        if "width" in payload:
            self.width = int(payload["width"])
        if "height" in payload:
            self.height = int(payload["height"])

    def send_graphs(self):
        fig = self.plot_weathergram()
        fig.set_size_inches(self.width/fig.dpi, self.height/fig.dpi)
        b = io.BytesIO()
        fig.savefig(b, format='png')
        self.mqtt_client.publish("livingroom/inkplate/meteogram/image", b.getvalue(), retain=True).wait_for_publish()

def main():
    parser = argparse.ArgumentParser(description='Graph generator')
    parser.add_argument('--test', action='store_true', help='generate one image to out.png and exit')
    args = parser.parse_args()
    g = Grapher()
    if args.test:
        fig = g.plot_weathergram()
        fig.set_size_inches(1024/fig.dpi, 100/fig.dpi)
        plt.savefig("out.png", format='png')
        return
    g.subscribe()
    while True:
        g.send_graphs()
        time.sleep(60)


if __name__ == '__main__':
    main()
