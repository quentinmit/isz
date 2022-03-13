#!/usr/bin/env python3

from datetime import datetime, date, time, timedelta
import io
from itertools import chain
import logging
import os
import sys
from zoneinfo import ZoneInfo

import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import mpl_toolkits.axisartist as axisartist
import numpy as mp

from influxdb_client import InfluxDBClient, Point, Dialect

logging.basicConfig(level=logging.DEBUG)

mpl.use("module://backend_pil")
mpl.rc("axes", unicode_minus=False)

TZ = ZoneInfo('America/New_York')

class Grapher:
    def __init__(self):
        self.client = InfluxDBClient(url="https://influx.isz.wtf", token=os.getenv("INFLUX_TOKEN"), org="icestationzebra")

        self.query_api = self.client.query_api()

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

if __name__ == '__main__':
    g = Grapher()
    fig = g.plot_weathergram()
    fig.set_size_inches(1024/fig.dpi, 100/fig.dpi)
    plt.savefig("out.png", format='png')
#b = io.BytesIO()
#plt.savefig(b, format='pbm')
#print(b.getvalue())
