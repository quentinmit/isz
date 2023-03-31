#!/usr/bin/python3
from influxdb_client import Point
import argparse
import logging
import sys
import time
from w1thermsensor import W1ThermSensor

def main():
    parser = argparse.ArgumentParser(description='Extract edgeos metrics.')
    parser.add_argument('--verbose', action='store_true')

    args = parser.parse_args()

    logging.basicConfig(level=logging.NOTSET if args.verbose else logging.INFO)

    for line in sys.stdin:
        for sensor in W1ThermSensor.get_available_sensors():
            logging.debug("Found sensor %s", sensor)
            print(Point("temp")
                  .tag("chip", "w1")
                  .tag("type_name", sensor.name)
                  .tag("type_id", sensor.type.value)
                  .tag("sensor", sensor.id)
                  .field('temp', sensor.get_temperature())
                  .time(time.time_ns())
                  .to_line_protocol())
        sys.stdout.flush()

if __name__ == "__main__":
    main()
