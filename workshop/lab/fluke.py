#!/usr/bin/python3

import asyncio
import enum
import serial_asyncio
import pint
import logging

class CommandError(ValueError):
    def __str__(self):
        return "Invalid command"
class ExecutionError(Exception):
    def __str__(self):
        return "Command failed"

ureg = pint.UnitRegistry()
_UNITS = {
    b"VDC": ureg.volt, # VDC and diode drop
    b"VAC": ureg.volt,
    b"VACDC": ureg.volt,
    b"ADC": ureg.amp,
    b"AAC": ureg.amp,
    b"AACDC": ureg.amp,
    b"OHMS": ureg.ohm,
    b"HZ": ureg.Hz,
    b"DB": ureg.dBm,
    b"W": ureg.watt
}

ConnectionState = enum.Enum('ConnectionState', 'DISCONNECTED CONNECTING INITIALIZING READY')

class Fluke45Protocol(asyncio.Protocol):
    def __init__(self):
        self.logger = logging.getLogger("fluke")
        self.transport = None
        self._state = ConnectionState.DISCONNECTED
        self._run_task = None
        self._cond = asyncio.Condition()
        self._pending_response = None
        self._buf = bytearray()

    # State machine:
    # DISCONNECTED
    # connection_made() -> CONNECTING
    # first attempted interaction -> INITIALIZING
    # connect() finishes -> READY

    async def _run(self):
        try:
            async with self._cond:
                self._state = ConnectionState.CONNECTING
                self._cond.notify_all()
            await self._ask(b'\x03')
            await self._ask(b"FORMAT 2\n")
            async with self._cond:
                self._state = ConnectionState.READY
                self._cond.notify_all()
        except asyncio.CancelledError:
            self._state = ConnectionState.DISCONNECTED
            raise

    async def connect(self):
        async with self._cond:
            while self._state != ConnectionState.READY:
                await self._cond.wait()

    def connection_made(self, transport):
        self.transport = transport
        self._run_task = asyncio.create_task(self._run())

    def data_received(self, data):
        #self.logger.debug("data received: %r", data)
        #print('data received', repr(data))
        self._buf.extend(data)
        while True:
            resp, found, rest = self._buf.partition(b'>\r\n')
            if not found:
                return
            self._buf = rest
            self.logger.debug('response received: %r', resp)
            lines = resp.split(b'\r\n')
            if len(lines) > 2:
                self.logger.warning('multi-line response: %r', lines)
            if self._pending_response:
                if lines[-1] == b'?':
                    self._pending_response.set_exception(CommandError())
                elif lines[-1] == b'!':
                    self._pending_response.set_exception(ExecutionError())
                elif lines[-1] == b'=':
                    if len(lines) > 1:
                        self._pending_response.set_result(bytes(lines[0]))
                    else:
                        self._pending_response.set_result(None)
                else:
                    self.logger.warn('unexpected prompt format: %r', resp)
                    self._pending_response.set_exception(ValueError())
                self._pending_response = None
            else:
                self.logger.warn('unexpected prompt: %r', resp)

    def connection_lost(self, exc):
        self.logger.info('port closed')
        self._run_task.cancel("connection_lost")
        self.transport.loop.stop()

    def pause_writing(self):
        self.logger.info('pause writing (buffer size %d)', self.transport.get_write_buffer_size())

    def resume_writing(self):
        self.logger.info('resume writing (buffer size %d', self.transport.get_write_buffer_size())

    async def ask(self, command):
        await self.connect()
        return await self._ask(command+b"\n")

    async def _ask(self, command):
        async with self._cond:
            while self._pending_response is not None:
                await self._cond.wait()
            self._pending_response = asyncio.get_running_loop().create_future()
        self.logger.debug('write %r', command)
        self.transport.write(command)
        try:
            return await asyncio.shield(self._pending_response)
        except asyncio.CancelledError:
            # Send a ^C to get back to a happy place
            self.transport.write(b'\x03')
            # The prompt will trigger cleanup
            await self._pending_response
            raise

    # *CLS Clear Status
    # *ESE <value> Event Status Enable
    # *ESE? Event Status Enable Query
    # *ESR? Event Status Register Query
    # *IDN Identification Query
    # *OPC Operation Complete Command
    # *OPC? Operation Complete Query
    # *RST Reset
    # *SRE <value> Service Request Enable
    # *SRE? Service Request Enable Query
    # *STB? Read Status Byte
    # *TRG Trigger
    # *TST Self-Test Query
    # *WAI Wait-to-continue (noop)

    # AAC, AAC2 AC Current
    # AACDC AC + DC rms current
    # ADC, ADC2 DC Current
    # , CLR2 Clear secondary display
    # CONT Continuity test
    # DIODE, DIODE2 Diode test
    # FREQ, FREQ2 Frequency
    # FUNC1?, FUNC2? Function query
    # OHMS, OHMS2 Resistance
    # VAC, VAC2 AC volts
    # VACDC AC + DC rms volts
    # VDC, VDC2 DC volts

    class Function(enum.Enum):
        AmpsAC = b"AAC"
        AmpsACDC = b"AACDC"
        AmpsDC = b"ADC"
        Continuity = b"CONT"
        Diode = b"DIODE"
        Frequency = b"FREQ"
        Ohms = b"OHMS"
        VoltsAC = b"VAC"
        VoltsACDC = b"VACDC"
        VoltsDC = b"VDC"
        Clear = b"CLR"

    async def get_function(self, display=1):
        try:
            return self.Function(await self.ask(b'FUNC%d?' % (display,)))
        except ExecutionError:
            return self.Function.Clear

    async def set_function(self, function, display=1):
        cmd = function.value
        if display != 1:
            cmd += b"%d" % (display,)
        await self.ask(cmd)

    # DB Primary display decibels
    # DBCLR Clear DB, DBPOWER, REL, MIN, MAX
    # DBPOWER Primary display dB power
    # DBREF <value> Set dB reference impedance
    _DB_REF_IMPEDANCES = [
        2, # = 1
        4,
        8,
        16,
        50,
        75,
        93,
        110,
        124,
        125,
        135,
        150,
        250,
        300,
        500,
        600,
        800,
        900,
        1000,
        1200,
        8000, # = 21
    ]
    # DBREF? Query dB reference impedance
    async def get_db_reference(self):
        return self._DB_REF_IMPEDANCES[int(await self.ask(b'DBREF?'))-1] * ureg.ohm
    async def set_db_reference(self, value, loose=True):
        m = value.m_as(ureg.ohm)
        _, i = min((abs(x-m), i) for i,x in enumerate(self._DB_REF_IMPEDANCES))
        await self.ask(b'DBREF %d' % (i+1))

    # HOLD Touch hold
    # HOLDCLR Clear touch hold
    # HOLDTHRESH <value> (1 = very stable, 2 = stable, 3 = noisy)
    # HOLDTHRESH? Query hold threshold

    # MAX
    # MAXSET <value>
    # MIN
    # MINSET
    # MMCLR

    # MOD? Query modifiers
    class Modifiers(enum.IntFlag):
        MN = 1
        MX = 2
        HOLD = 4
        dB = 8
        dB_POWER = 16
        REL = 32
        COMP = 64

    async def get_modifiers(self):
        return self.Modifiers(int(await self.ask(b'MOD?')))

    # REL
    # RELCLR
    # RELSET <value>
    # RELSET?

    # AUTO Auto-ranging
    async def set_auto_range(self, auto):
        await self.ask(b'AUTO' if auto else b'FIXED')

    # AUTO? Query auto-ranging
    async def get_auto_range(self):
        return await self.ask(b'AUTO?') == b'1'
    # FIXED Fixed range
    # RANGE <range>
    _RANGE_VOLTS = [
        300*ureg.millivolt,
        3*ureg.volt,
        30*ureg.volt,
        300*ureg.volt,
        1000*ureg.volt,
    ]
    _RANGE_OHMS = [
        300*ureg.ohm,
        3*ureg.kiloohm,
        30*ureg.kiloohm,
        300*ureg.kiloohm,
        3*ureg.megaohm,
        30*ureg.megaohm,
        300*ureg.megaohm,
    ]
    _RANGE_AMPS = [
        30*ureg.milliamp,
        100*ureg.milliamp,
        10*ureg.amp,
    ]
    _RANGE_FREQ = [
        1000*ureg.Hz,
        10*ureg.kiloHz,
        100*ureg.kiloHz,
        1000*ureg.kiloHz,
        10*ureg.megaHz,
    ]
    # RANGE1?
    # RANGE2?
    async def get_range(self, display=1):
        parts = await self.ask(b'FUNC%d?;RATE?;RANGE%d?' % (display, display))
        func, rate, range = parts.split(b';')
        if func in (b'CONT', b'DIODE'):
            return {
                b'S': 999.99*ureg.millivolt,
                b'M': 2.5*ureg.volt,
                b'F': 2.5*ureg.volt,
            }[rate]
        raw = {
            b'AAC': self._RANGE_AMPS,
            b'AACDC': self._RANGE_AMPS,
            b'ADC': self._RANGE_AMPS,
            b'CONT': self._RANGE_VOLTS,
            b'DIODE': self._RANGE_VOLTS,
            b'FREQ': self._RANGE_FREQ,
            b'OHMS': self._RANGE_OHMS,
            b'VAC': self._RANGE_VOLTS,
            b'VACDC': self._RANGE_VOLTS,
            b'VDC': self._RANGE_VOLTS,
        }[func][int(range)-1]
        if rate == b'S' and str(raw)[0] == '3':
            raw = (raw.magnitude//3)*raw.units
        return raw
    # RATE <speed>
    class Rate(enum.Enum):
        Slow = b"S" # 2.5 Hz
        Medium = b"M" # 5 Hz
        Fast = b"F" # 20 Hz
    # RATE?
    async def get_rate(self):
        return self.Rate(await self.ask(b'RATE?'))

    # MEAS1?
    # MEAS2?
    # MEAS? Both measurements (comma-separated if secondary display is active)
    async def _get_value(self, command, display=None):
        if display:
            command += b'%d?' % (display,)
        else:
            command += b'?'
        res = await self.ask(command)
        parts = tuple(self._parse_value(v) for v in res.split(b', '))
        if len(parts) == 1:
            return parts[0]
        return parts
    def _parse_value(self, res):
        n, unit = res.split(b' ')
        if n == b'+1E+9':
            n = float('inf')
        else:
            n = float(n)
        return pint.Quantity(n, _UNITS[unit])

    async def get_next_value(self, display=None):
        return await self._get_value(b'MEAS', display)
    # VAL1?
    # VAL2?
    # VAL?
    async def get_last_value(self, display=None):
        return await self._get_value(b'VAL')

    async def measure(self, display=None):
        return await self._get_value(b'*TRG;VAL')

    # COMP Compare + touch hold
    # COMP? Query compare results
    class Comparison(enum.Enum):
        Low = b'LO'
        High = b'HI'
        Pass = b'PASS'
        Unknown = b'---'
    # COMPCLR
    # COMPHI <value>
    # COMPLO <value>
    # HOLDCLR

    # TRIGGER <value>
    class TriggerMode(enum.Enum):
        Internal = 1
        External = 2
        ExternalSettling = 3
        ExternalRear = 4
        ExternalRearSettling = 5
    # TRIGGER?
    async def get_trigger_mode(self):
        return self.TriggerMode(int(await self.ask(b'TRIGGER?')))
    async def set_trigger_mode(self, mode):
        await self.ask(b'TRIGGER %d' % mode.value)

    # FORMAT <fmt> (1 = no units, 2 = units)
    # FORMAT?
    # SERIAL? Query serial number

    # REMS Remote operating mode
    # RWLS Remote operating mode with front panel lockout
    # LOCS Local operating mode
    # LWLS Local operating mode with front panel lockout

async def main():
    logging.basicConfig(level=logging.DEBUG)
    transport, protocol = await serial_asyncio.create_serial_connection(
        asyncio.get_running_loop(),
        Fluke45Protocol,
        '/dev/ttyFluke45',
        baudrate=9600)
    for cmd in b"*IDN? *ESE? *ESR? *STB? *MEAS? MEASS?".split():
        try:
            print(cmd, await protocol.ask(cmd))
        except Exception as e:
            logging.exception("command %r", cmd)
    for name in "get_function get_auto_range get_range get_rate get_db_reference get_modifiers".split():
        try:
            logging.info("%s: %s", name, await getattr(protocol, name)())
        except Exception as e:
            logging.exception("failed to %s", name)
    print("display 2 function", await protocol.get_function(display=2))
    await protocol.set_function(protocol.Function.VoltsDC)
    #await protocol.set_function(protocol.Function.Clear, display=2)
    #await protocol.ask(b'VDC')
    #await protocol.set_db_reference(16*ureg.ohm)
    #await protocol.ask(b'DBPOWER;MAX')
    print('value', await protocol.measure())

async def test_trigger(self):
    await protocol.ask(b"OHMS")
    await protocol.set_trigger_mode(protocol.TriggerMode.External)
    #print("both", await protocol.ask(b"*IDN?;VAL?"))
    try:
        print("value", await asyncio.wait_for(protocol.get_last_value(), timeout=1.0))
    except asyncio.TimeoutError:
        print("timeout")
    for i in range(10):
        try:
            print("value", await asyncio.wait_for(protocol.measure(), timeout=1.0))
        except asyncio.TimeoutError:
            print("timeout")
    await protocol.set_trigger_mode(protocol.TriggerMode.Internal)
if __name__ == "__main__":
    asyncio.run(main())
