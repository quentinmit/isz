#!/usr/bin/env python3

import argparse
from datetime import datetime, date, time, timedelta
import io
from itertools import chain
import json
import logging
from pathlib import Path
import os
import sys
import time
from zoneinfo import ZoneInfo

from astropy import units as u
from astropy.table import QTable
from astropy.time import Time
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.font_manager import FontProperties
import matplotlib.text as mtext
import matplotlib.ticker as mticker
import matplotlib.quiver as mquiver
from matplotlib.transforms import Bbox
from matplotlib.tight_layout import get_renderer
import matplotlib.units as munits
import matplotlib.backend_bases
from more_itertools import bucket
import mpl_toolkits.axisartist as axisartist
from mpl_toolkits.axes_grid1.parasite_axes import host_axes
from mpl_toolkits.axes_grid1.axes_divider import make_axes_locatable
from mpl_toolkits.axes_grid1.axes_size import Fixed, SizeFromFunc
import numpy as np
from dozer import Dozer
import cherrypy

from influxdb_client import InfluxDBClient, Point, Dialect
import paho.mqtt.client as mqtt

from .backend_pil import FigureCanvasPIL

logging.basicConfig(level=logging.INFO)

_log = logging.getLogger(__name__)

mpl.use("module://dashboard.backend_pil")
mpl.rc("axes", unicode_minus=False)

u.imperial.enable()
u.set_enabled_equivalencies(u.temperature())

TZ = ZoneInfo('America/New_York')

def inside(a, b):
    ax1, ay1, ax2, ay2 = a.extents
    bx1, by1, bx2, by2 = b.extents
    if ax2 < ax1:
        ax2, ax1 = ax1, ax2
    if ay2 < ay1:
        ay2, ay1 = ay1, ay2
    if bx2 < bx1:
        bx2, bx1 = bx1, bx2
    if by2 < by1:
        by2, by1 = by1, by2
    return ax1 >= bx1 and ax2 <= bx2 and ay1 >= by1 and ay2 <= by2

class AutoAnnotation(mtext.Annotation):
    def __init__(self, *args, horizontalalignment='center', verticalalignment='bottom', **kwargs):
        self.default_horizontalalignment = horizontalalignment
        self.default_verticalalignment = verticalalignment
        super().__init__(*args, horizontalalignment=horizontalalignment, verticalalignment=verticalalignment, **kwargs)

    def _adjust_alignment(self, bbox, axbbox):
        ax1, ay1, ax2, ay2 = bbox.extents
        bx1, by1, bx2, by2 = axbbox.extents
        if ax2 < ax1:
            ax2, ax1 = ax1, ax2
        if ay2 < ay1:
            ay2, ay1 = ay1, ay2
        if bx2 < bx1:
            bx2, bx1 = bx1, bx2
        if by2 < by1:
            by2, by1 = by1, by2

        if ax1 < bx1:
            self.set_horizontalalignment('left')
        elif ax2 > bx2:
            self.set_horizontalalignment('right')

        if ay1 < by1:
            self.set_verticalalignment('bottom')
        elif ay2 > by2:
            self.set_verticalalignment('top')

    def update_positions(self, renderer):
        self.set_horizontalalignment(self.default_horizontalalignment)
        self.set_verticalalignment(self.default_verticalalignment)
        super().update_positions(renderer)

        bbox = mtext.Text.get_window_extent(self, renderer)
        axbbox = self.axes.get_window_extent(self, renderer)
        if not inside(bbox, axbbox):
            self._adjust_alignment(bbox, axbbox)
            super().update_positions(renderer)

class OverlapAnnotations(mtext.Annotation):
    def __init__(self, positions, labels, *args, **kwargs):
        self.positions = positions
        self.labels = labels
        super().__init__("", (0,0), *args, **kwargs)

    def draw(self, renderer):
        bboxes = []
        renderer.open_group(__name__, gid=self.get_gid())
        for (x, y), text in zip(self.positions, self.labels):
            self.xyann = (x, y)
            self.set_text(text)
            bbox = super().get_window_extent(renderer)
            if bbox.count_overlaps(bboxes) > 0:
                _log.debug("Skipping %s at (%s) due to overlap", self.get_text(), self.xyann)
                continue
            _log.debug("Drawing %s at (%s)", self.get_text(), self.xyann)
            super().draw(renderer)
            bboxes.append(bbox)
        renderer.close_group(__name__)

class OverlapBarbs(mquiver.Barbs):
    def _prepare_points(self):
        transform, offset_trf, offsets, paths = super()._prepare_points()
        toffsets = offset_trf.transform(offsets)
        trans = self.get_transforms()
        bboxes = []
        keep = []
        for i, (p, t) in enumerate(matplotlib.backend_bases.RendererBase._iter_collection_raw_paths(None, transform.frozen(), paths, trans)):
            bbox = p.get_extents(t.frozen().translate(*toffsets[i]))
            if bbox.count_overlaps(bboxes) > 0:
                _log.debug("Skipping path at (%s) due to overlap", bbox)
                continue
            keep.append(i)
            bboxes.append(bbox)
        return transform, offset_trf, offsets[keep], [paths[i] for i in keep]

class MplQuantityConverter(munits.ConversionInterface):
    @staticmethod
    def rad_fn(x, pos=None):
        n = int((x / np.pi) * 2.0 + 0.25)
        if n == 0:
            return '0'
        elif n == 1:
            return 'π/2'
        elif n == 2:
            return 'π'
        elif n % 2 == 0:
            return f'{n // 2}π'
        else:
            return f'{n}π/2'

    @staticmethod
    def axisinfo(unit, axis):
        if unit == u.radian:
            return munits.AxisInfo(
                majloc=mticker.MultipleLocator(base=np.pi/2),
                majfmt=mticker.FuncFormatter(self.rad_fn),
                label=unit.to_string(),
            )
        elif unit == u.degree:
            return munits.AxisInfo(
                majloc=mticker.AutoLocator(),
                majfmt=mticker.FormatStrFormatter('%i°'),
                label=unit.to_string(),
            )
        elif unit is not None:
            fmt = '%.0f' + (unit.to_string('unicode').replace("%", "%%"))
            return munits.AxisInfo(
                majfmt=mticker.FormatStrFormatter(fmt),
            )
        return None

    @staticmethod
    def convert(val, unit, axis):
        if isinstance(val, u.Quantity):
            return val.to_value(unit)
        elif isinstance(val, list) and val and isinstance(val[0], u.Quantity):
            return [v.to_value(unit) for v in val]
        else:
            return val

    @staticmethod
    def default_units(x, axis):
        if hasattr(x, 'unit'):
            return x.unit
        return None
munits.registry[u.Quantity] = MplQuantityConverter()


class QuantityTickFormatter(mticker.Formatter):
    def __call__(self, x, pos=None):
        logging.debug("tick formatter called for %r", x)
        return str(x)

_ICON_GLYPHS = {
    "cloudy": "\U000F0590",
    "cloudy-alert": "\U000F0F2F",
    "cloudy-arrow-right": "\U000F0E6E",
    "fog": "\U000F0591",
    "hail": "\U000F0592",
    "hazy": "\U000F0F30",
    "hurricane": "\U000F0898",
    "lightning": "\U000F0593",
    "lightning-rainy": "\U000F067E",
    "night": "\U000F0594",
    "night-partly-cloudy": "\U000F0F31",
    "partly-cloudy": "\U000F0595",
    "partly-lightning": "\U000F0F32",
    "partly-rainy": "\U000F0F33",
    "partly-snowy": "\U000F0F34",
    "partly-snowy-rainy": "\U000F0F35",
    "pouring": "\U000F0596",
    "rainy": "\U000F0597",
    "snowy": "\U000F0598",
    "snowy-heavy": "\U000F0F36",
    "snowy-rainy": "\U000F067F",
    "sunny": "\U000F0599",
    "sunny-alert": "\U000F0F37",
    "sunny-off": "\U000F14E4",
    "sunset": "\U000F059A",
    "sunset-down": "\U000F059B",
    "sunset-up": "\U000F059C",
    "tornado": "\U000F0F38",
    "windy": "\U000F059D",
    "windy-variant": "\U000F059E",
}

_CONDITION_ICON_TO_MDI_ICON = {
    # Consider using condition codes instead
    "01d": "sunny",
    "01n": "night",
    "02d": "partly-cloudy", # 11-25% clouds
    "02n": "night-partly-cloudy",
    "03d": "partly-cloudy", # 25-50% clouds
    "03n": "night-partly-cloudy",
    "04d": "cloudy", # 51%+
    "04n": "cloudy", # 51%+
    "09d": "rainy",
    "09n": "rainy",
    "10d": "partly-rainy",
    "10n": "rainy",
    "11d": "lightning",
    "11n": "lightning",
    "13d": "snowy",
    "13n": "snowy",
    "50d": "fog",
    "50n": "fog",
}

_MATERIAL_ICON_FONT = os.getenv(
    "MATERIAL_ICON_FONT",
    "../esphome/fonts/materialdesignicons-webfont.ttf"
)


class Grapher:
    def __init__(self):
        self.influx_client = InfluxDBClient(url="https://influx.isz.wtf", token=os.getenv("INFLUX_TOKEN"), org="icestationzebra")

        self.query_api = self.influx_client.query_api()

        self.width = 1024
        self.height = 100

    def fetch_weathergram(self, days=4):
        tables = self.query_api.query(
            """
import "experimental"
import "strings"
import "dict"

field_units = ["temp": "deg_C", "temperature": "deg_C", "humidity": "%", "wind_degrees": "deg", "wind_speed": "m/s"]

from(bucket: defaultBucket)
  |> range(start: timeRangeStart, stop: timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "temperature" or r["_field"] == "humidity" or r["_field"] == "condition_icon" or r._field == "wind_degrees" or r._field == "wind_speed")
  |> filter(fn: (r) => r["city"] == "Cambridge")
  |> filter(fn: (r) => r["city_id"] == "4931972")
  |> group(columns: ["_measurement", "_field", "_time"], mode:"by")
//  |> aggregateWindow(every: windowPeriod, fn: mean, createEmpty: false)
  |> filter(fn: (r) => r.forecast == "*" or r._time > now())
  |> map(fn: (r) => ({r with age: if r.forecast == "*" then 0 else int(v: duration(v: r.forecast))}))
  |> sort(columns: ["age"], desc: false)
  |> first()
  |> group(columns: ["_measurement", "_field"])
  |> keep(columns: ["_measurement", "_field", "_time", "_value"])
  |> map(fn: (r) => ({r with _measurement: r._field, _unit: dict.get(dict: field_units, key: r._field, default: "")}))
  |> yield(name: "forecast")

from(bucket: defaultBucket)
  |> range(start: timeRangeStart, stop: timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "temp")
  |> filter(fn: (r) => r["chip"] == "w1")
  |> filter(fn: (r) => r.sensor == "0120541bbaa7")
  |> aggregateWindow(every: windowPeriod, fn: mean, createEmpty: false)
  //|> map(fn: (r) => ({r with _value: r._value * 9./5. + 32.}))
  |> keep(columns: ["_start", "_stop", "_time", "_value", "sensor", "_measurement", "_field"])
  //|> map(fn: (r) => ({r with run_name: "local"}))
  //|> group(columns: ["_start", "_stop", "_measurement", "_field"])
  //|> drop(columns: ["sensor", "name", "host"])
  |> map(fn: (r) => ({r with _unit: dict.get(dict: field_units, key: r._field, default: "")}))
  |> yield(name: "local")
""",
            params={
                "defaultBucket": "icestationzebra",
                "windowPeriod": timedelta(minutes=10),
                "timeRangeStart": timedelta(hours=-30),
                "timeRangeStop": timedelta(days=days),
            })

        # First, group tables by the "result" column:
        results = bucket(tables, lambda t: t.records[0]['result'])

        out = {}

        for result in results:
            tables = results[result]
            measurements = bucket(
                chain.from_iterable(t.records for t in tables),
                lambda r: r["_time"],
            )
            rows = []
            for t in measurements:
                row = {"_time": Time(t)}
                for r in measurements[t]:
                    value = r["_value"]
                    if unit := r.values.get("_unit"):
                        value *= u.Unit(unit)
                    row[r["_field"]] = value
                rows.append(row)
            out[result] = QTable(rows)
        return out

    def plot_meteogram(self, days=4, humidity=False):
        tables = self.fetch_weathergram(days)

        xmin = datetime.now() - timedelta(hours=24)
        xmax = max(np.max(t["_time"]).plot_date for t in tables.values())

        fig = mpl.figure.Figure(subplotpars=mpl.figure.SubplotParams(0,0,1,1))
        FigureCanvasPIL(fig)
        ax = host_axes((0,0,1,1), axes_class=axisartist.Axes, figure=fig)
        divider = make_axes_locatable(ax)
        ax.set_xlim(left=xmin, right=xmax)
        ax.xaxis.set_major_locator(mdates.DayLocator(tz=TZ))
        ax.xaxis.set_minor_locator(mdates.HourLocator(byhour=range(0,24,6), tz=TZ))
        ax.xaxis.set_major_formatter(mdates.DateFormatter(' %A'))
        ax.yaxis.set_units(u.imperial.deg_F)
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
        #ax.axis["left"].major_ticklabels.set_fontfamily("clean")
        ax.axis["left"].major_ticklabels.set_fontfamily("lucida")
        ax.axis["left"].major_ticklabels.set_fontsize(11)

        if humidity and "humidity" in tables["forecast"].colnames:
            ax2 = ax.twinx()
            # Units don't work until https://github.com/matplotlib/matplotlib/issues/22714 is fixed
            ax2.axis["right"].major_ticklabels.set_visible(True)
            ax2.axis["right"].invert_ticklabel_direction()
            ax2.plot(tables["forecast"]["_time"].plot_date, tables["forecast"]["humidity"], linewidth=0.8)
        ax.plot(tables["local"]["_time"].plot_date, tables["local"]["temp"], linewidth=1.5)

        ax.grid(axis='x', linestyle='dotted')

        if forecast := tables.get("forecast"):
            ax.plot(forecast["_time"].plot_date, forecast["temperature"], linewidth=0.8)

            # Plot min and max temperature
            forecast.sort("temperature")
            majorticks = ax.xaxis.get_ticklocs()
            tickindices = np.searchsorted(majorticks, forecast["_time"].plot_date)
            logging.debug("tick indices = %s", tickindices)
            tg = forecast.group_by(tickindices)
            for i, day in enumerate(tg.groups):
                if i == 0:
                    continue
                for index, align in ((0, "top"), (-1, "bottom")):
                    temp = day["temperature"][index]
                    text = ax.yaxis.get_major_formatter().format_data_short(ax.yaxis.convert_units(temp))
                    ann = ax.add_artist(
                        AutoAnnotation(
                            text,
                            (day["_time"][index].plot_date, temp),
                            fontfamily='lucida', fontsize=12,
                            verticalalignment=align,
                        ),
                    )

            # Plot wind barbs
            if "wind_speed" in forecast.columns and "wind_degrees" in forecast.columns:
                ax2 = divider.append_axes(
                    'bottom',
                    Fixed(20/72.),
                    pad=0,
                    sharex=ax)
                ax2.axis[:].major_ticks.set_visible(False)
                ax2.axis[:].minor_ticks.set_visible(False)
                ax2.axis[:].major_ticklabels.set_visible(False)
                ax2.axis[:].minor_ticklabels.set_visible(False)
                ax2.axis[:].set_visible(False)
                ax2.axis("off")
                wind_speed = forecast["wind_speed"].to(u.imperial.mile/u.hour).value
                # wind_angle is direction wind is blowing FROM, clockwise from north
                wind_angle = ((450-180)*u.degree-forecast["wind_degrees"]).to(u.radian).value
                # barbs takes the direction the shaft should point, so we subtract 180 degrees.
                wind_u = wind_speed * np.cos(wind_angle)
                wind_v = wind_speed * np.sin(wind_angle)

                args = (
                    forecast["_time"].plot_date, np.zeros(forecast["_time"].shape),
                    wind_u, wind_v
                )
                kwargs = dict(
                    length=6,
                    pivot="middle",
                )
                b = OverlapBarbs(
                    ax2,
                    *ax2._quiver_units(args, kwargs),
                    **kwargs
                )
                ax2.add_collection(b, autolim=True)
                ax2._request_autoscale_view()
            # Plot condition icons
            forecast.sort("_time")
            iconfont = FontProperties(size=24, fname=Path(_MATERIAL_ICON_FONT))
            ax2 = divider.append_axes(
                'bottom',
                SizeFromFunc(
                    lambda r: r.get_text_width_height_descent(_ICON_GLYPHS["night-partly-cloudy"], iconfont, False)[1]*1.2
                ),
                pad=0,
                sharex=ax)
            ax2.axis[:].major_ticks.set_visible(False)
            ax2.axis[:].minor_ticks.set_visible(False)
            ax2.axis[:].major_ticklabels.set_visible(False)
            ax2.axis[:].minor_ticklabels.set_visible(False)
            ax2.axis[:].set_visible(False)
            ax2.axis("off")
            ax2.add_artist(
                OverlapAnnotations(
                    [(x,0.5) for x in forecast["_time"].plot_date],
                    [_ICON_GLYPHS[_CONDITION_ICON_TO_MDI_ICON.get(icon)] for icon in forecast["condition_icon"]],
                    xycoords=("data", "axes fraction"),
                    verticalalignment="center",
                    horizontalalignment="center",
                    fontproperties=iconfont,
                )
            )
            # for row in forecast:
            #     icon = row["condition_icon"]
            #     time = row["_time"].plot_date
            #     icon = _CONDITION_ICON_TO_MDI_ICON.get(icon)
            #     ann = ax2.annotate(
            #         _ICON_GLYPHS[icon],
            #         xy=(time, 0.5),
            #         xycoords=("data", "axes fraction"),
            #         verticalalignment="center",
            #         horizontalalignment="center",
            #         fontproperties=iconfont,
            #     )
        return fig

    def _connect_mqtt(self):
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.connect("mqtt.isz.wtf")
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.loop_start()

    def run_mqtt(self):
        self._connect_mqtt()
        self.subscribe()
        while True:
            try:
                self.send_graphs()
            except KeyboardInterrupt:
                raise
            except:
                logging.exception("Failed to generate graphs")
            time.sleep(60)

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
        fig = self.plot_meteogram()
        fig.set_size_inches((self.width/fig.dpi, self.height/fig.dpi))
        b = io.BytesIO()
        fig.savefig(b, format='png')
        self.mqtt_client.publish("livingroom/inkplate/meteogram/image", b.getvalue(), retain=True).wait_for_publish()

class App:
    def __init__(self, grapher):
        self.grapher = grapher

    @cherrypy.expose
    def index(self):
        return "Hello world!"

    @cherrypy.expose
    @cherrypy.tools.params()
    def meteogram(self, width: int = 640, height: int = 480, days: int = 4, humidity: bool = False, image_mode: str = '1'):
        fig = self.grapher.plot_meteogram(days, humidity=humidity)
        fig.set_size_inches((width/fig.dpi, height/fig.dpi))
        b = io.BytesIO()
        fig.savefig(b, format='png', image_mode=image_mode)
        cherrypy.response.headers['Content-Type'] = 'image/png'
        return b.getvalue()

def main():
    parser = argparse.ArgumentParser(description='Graph generator')
    parser.add_argument('--test', action='store_true', help='generate one image to out.png and exit')
    parser.add_argument('--mqtt', action='store_true', help='generate images on mqtt')
    parser.add_argument('--verbose', action='store_true', help='emit debug logs')
    parser.add_argument('--host', default='127.0.0.1', help='host to listen on')
    args = parser.parse_args()
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        logging.getLogger("matplotlib").setLevel(logging.DEBUG)
        logging.getLogger("backend_pil").setLevel(logging.DEBUG)
        logging.getLogger("matplotlib.font_manager").setLevel(logging.INFO)
    g = Grapher()
    if args.test:
        fig = g.plot_meteogram()
        fig.set_size_inches((1024/fig.dpi, 200/fig.dpi))
        plt.savefig("out.png", format='png')
        return
    config = {
        'environment': 'embedded',
        'global': {
            'server.socket_host': args.host,
            'server.socket_port': 8080,
            'request.show_tracebacks': True
        },
    }
    cherrypy.tree.mount(App(g), config={
        '/': {
            'wsgi.pipeline': [('Dozer', Dozer)]
        },
    })
    cherrypy.config.update(config)
    cherrypy.engine.start()
    if args.mqtt:
        try:
            g.run_mqtt()
        finally:
            cherrypy.engine.exit()
    else:
        cherrypy.engine.block()
if __name__ == '__main__':
    main()
