#!/usr/bin/python3

import asyncio
import serial_asyncio
import pint

class CommandError(ValueError): pass
class ExecutionError(Exception): pass

ureg = pint.UnitRegistry()
_UNITS = {
    b"VDC": ureg.volt, # VDC and diode drop
    b"VAC": ureg.volt,
    b"ADC": ureg.amp,
    b"AAC": ureg.amp,
    b"OHMS": ureg.ohm,
    b"HZ": ureg.Hz,
}

class Fluke45Protocol(asyncio.Protocol):
    def __init__(self):
        self.transport = None
        self._connected = asyncio.Event()
        self._cond = asyncio.Condition()
        self._pending_response = None
        self._buf = bytearray()
        self._initialized = False

    async def connect(self):
        await self._connected.wait()
        if not self._initialized:
            await self._ask(b"FORMAT 2")
            self._initialized = True

    def connection_made(self, transport):
        self.transport = transport
        self.transport.write(b'\x03')

    def data_received(self, data):
        print('data received', repr(data))
        self._buf.extend(data)
        if b'\n' in data:
            lines = self._buf.split(b'\r\n')
            #print('lines', repr(lines))
            for i, line in enumerate(lines):
                if len(line) == 2 and line[1:] == b'>':
                    if self._pending_response:
                        if line == b'?>':
                            self._pending_response.set_exception(CommandError())
                        elif line == b'!>':
                            self._pending_response.set_exception(ExecutionError())
                        elif i > 0:
                            self._pending_response.set_result(bytes(lines[i-1]))
                        else:
                            self._pending_response.set_result(None)
                    else:
                        self._connected.set()
                    self._buf[:] = b'\r\n'.join(lines[i+1:])
            

    def connection_lost(self, exc):
        print('port closed')
        self.connected.clear()
        self._initialized = False
        self.transport.loop.stop()

    def pause_writing(self):
        print('pause writing')
        print(self.transport.get_write_buffer_size())

    def resume_writing(self):
        print(self.transport.get_write_buffer_size())
        print('resume writing')

    async def ask(self, command):
        await self.connect()
        return await self._ask(command)

    async def _ask(self, command):
        async with self._cond:
            while self._pending_response is not None:
                await self._cond.wait()
            self._pending_response = asyncio.get_running_loop().create_future()
        #print("asking %s" % (command,))
        self.transport.write(command+b"\n")
        try:
            return await self._pending_response
        finally:
            async with self._cond:
                self._pending_response = None
                self._cond.notify()

    async def get_value(self):
        res = await self.ask(b"MEAS?")
        n, unit = res.split(b' ')
        return float(n) * _UNITS[unit]

async def main():
    transport, protocol = await serial_asyncio.create_serial_connection(
        asyncio.get_running_loop(),
        Fluke45Protocol,
        '/dev/ttyFluke45',
        baudrate=9600)
    for cmd in b"*IDN? VAL? RATE? *ESE? *ESR? *STB? FUNC1? FUNC2?".split():
        try:
            print(cmd, await protocol.ask(cmd))
        except Exception as e:
            print(cmd, e)
    await protocol.ask(b"RATE M")
    print("both", await protocol.ask(b"*IDN?;VAL?"))
    for i in range(10):
        print("value", await protocol.get_value())
if __name__ == "__main__":
    asyncio.run(main())
