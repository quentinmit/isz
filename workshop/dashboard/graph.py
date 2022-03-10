#!/usr/bin/env python3

from datetime import datetime, date, time, timedelta
import io
import logging
import os
import sys

import delorean
from influxdb_client import InfluxDBClient, Point, Dialect

logging.basicConfig(level=logging.DEBUG)

client = InfluxDBClient(url="https://influx.isz.wtf", token=os.getenv("INFLUX_TOKEN"), org="icestationzebra")

query_api = client.query_api()

p = {
    "defaultBucket": "icestationzebra",
    "windowPeriod": timedelta(minutes=10),
    "timeRangeStart": timedelta(hours=-30),
    "timeRangeStop": timedelta(days=3),
}
tables = query_api.query("""
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
""", params=p)

gp = io.StringIO()

for table in tables:
    result = table.records[0]['result']
    if result == "local":
        name = "localtemp"
    elif result == "accuweather":
        name = "aw"+table.records[0]['_field']
    print(f"${name} << EOD", file=gp)
    for record in table.records:
        print(record["_time"].timestamp(), record["_value"], file=gp)
    print("EOD", file=gp)

#set format x2 "%A" timedate


timestamps = [record["_time"] for table in tables for record in table]
start = min(timestamps).astimezone().date()
stop = max(timestamps).astimezone().date()

tics = []
mtics = []
while start <= stop:
    tics.append((start.strftime("%A %m/%d"), start.strftime("%s")))
    for hour in (0, 6, 12, 18):
        tics.append(("", datetime.combine(start, time(hour=hour)).strftime("%s 1")))
        mtics.append((f"{hour}", datetime.combine(start, time(hour=hour)).strftime("%s 0")))
    start = start + timedelta(days=1)

#start = delorean.Delorean(min(timestamps)).shift('US/Eastern')
#stop = delorean.Delorean(max(timestamps)).shift('US/Eastern')
logging.debug("time = %s - %s", start, stop)

#tics = delorean.stops(freq=delorean.DAILY, start=start.naive, stop=stop.naive, timezone='US/Eastern')
#tics = ", ".join('"%s" %d' % (d.format_datetime(""), d.start_of_day.timestamp()) for d in tics)
mtics = ", ".join('"%s" %s' % d for d in mtics)
tics = ", ".join('"%s" %s' % d for d in tics)
logging.debug("tics = %s", tics)

xmin = datetime.now() - timedelta(hours=24)

gp.write(f"""
set xdata time
set timefmt "%s"
unset xtics
set ytics format "%.0fF" border in offset character 2, 0 left
set xtics ({mtics}) border in offset character 1,character 1.6 left
set x2tics ({tics}) border in offset character 0.5,character -2 left mirror
set xrange [{xmin:%s}:*]
set grid x2tics
set margins 0, 0, 0, 0
unset key
plot $awtemperature using 1:2 with lines, $localtemp using 1:2 with lines linetype 1 linewidth 2
""")

print(gp.getvalue())
#     print(table)
#     for record in table.records:
#         print(record.values)
