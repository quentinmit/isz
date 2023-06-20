#!/usr/bin/env python3

from functools import reduce
import json
import logging
import time

import paho.mqtt.client as mqtt
import pycec.const
import pycec.network

logging.basicConfig(level=logging.DEBUG)

_log = logging.getLogger(__name__)

class CEC:
    def __init__(self):
        self.last_message = {}
    def _connect_mqtt(self):
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.connect("mqtt.isz.wtf")
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.loop_start()

    def on_message(self, client, userdata, msg):
        topic = msg.topic
        if not topic.endswith("/cec/rx"):
            return
        payload = json.loads(msg.payload)
        source = payload["source"]
        destination = payload["destination"]
        data = bytes(payload["data"])
        if not data:
            return
        _log.info("%d->%d %s %s", source, destination, data.hex(":"), data)
        self.last_message[(source, data[0])] = data[1:]

    def transmit(self, destination, data, source=None):
        msg = {
            "destination": destination,
            "data": list(bytes(data)),
        }
        if source is not None:
            msg["source"] = source
        msg = json.dumps(msg)
        _log.debug("sending %s", msg)
        self.mqtt_client.publish("livingroom/cec/tx", msg)

    def subscribe(self):
        self.mqtt_client.subscribe("livingroom/cec/rx", 0)

    def run_mqtt(self):
        self._connect_mqtt()
        self.subscribe()
        #self.transmit(0xf, [0x86,0x20,0x00])
        #self.transmit(0xf, [0x85], source=5)
        #time.sleep(1)
        self.scan()

    def scan(self):
        send_commands = set()
        name_by_opcode = {}
        for k in dir(pycec.const):
            v = getattr(pycec.const, k)
            if k.startswith("CMD_"):
                if not isinstance(v, tuple):
                    continue
                if k != "CMD_PHYSICAL_ADDRESS":
                    continue
                tx, rx = v
                send_commands.add(tx)
                name_by_opcode[rx] = k[4:]
        for device in range(0, 15):
            for op in sorted(send_commands):
                self.transmit(device, [op])
                time.sleep(1.5)
        for (destination, opcode), data in sorted(self.last_message.items()):
            name = name_by_opcode.get(opcode, hex(opcode))
            if name == "PHYSICAL_ADDRESS":
                addr = pycec.network.PhysicalAddress(list(data[0:2]))
                _log.info("%d %s: %s (%s)", destination, name, addr, data)
            elif name == "VENDOR":
                vendor_id = reduce(lambda x, y: x * 0x100 + y, data)
                _log.info("%d %s: %s (%06x)", destination, name, pycec.const.VENDORS.get(vendor_id, "unknown"), vendor_id)
            else:
                _log.info("%d %s: %s", destination, name, data)

def main():
    cec = CEC()
    cec.run_mqtt()
if __name__ == "__main__":
    main()
