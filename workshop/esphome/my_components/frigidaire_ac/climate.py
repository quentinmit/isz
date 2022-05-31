import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.components import (
    climate,
    remote_transmitter,
    sensor,
)
from esphome.const import CONF_ID, CONF_TEMPERATURE_SOURCE
from esphome.components.remote_base import CONF_TRANSMITTER_ID

frigidaire_ac_ns = cg.esphome_ns.namespace("frigidaire_ac")
FrigidaireACClimate = frigidaire_ac_ns.class_("FrigidaireACClimate", climate.Climate, cg.Component)

CONF_TEMPERATURE_SENSOR = "temperature_sensor"
CONF_POWER_SENSOR = "power_sensor"
CONF_POWER_SETTLING_TIME = "power_settling_time"

CONFIG_SCHEMA = climate.CLIMATE_SCHEMA.extend(
    {
        cv.GenerateID(): cv.declare_id(FrigidaireACClimate),
        cv.GenerateID(CONF_TRANSMITTER_ID): cv.use_id(
            remote_transmitter.RemoteTransmitterComponent
        ),
        cv.Optional(CONF_TEMPERATURE_SENSOR): cv.use_id(sensor.Sensor),
        cv.Optional(CONF_POWER_SENSOR): cv.use_id(sensor.Sensor),
        cv.Optional(CONF_POWER_SETTLING_TIME, default="30s"): cv.positive_time_period_milliseconds,
    }
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)
    await climate.register_climate(var, config)

    if CONF_TEMPERATURE_SENSOR in config:
        temp_sens = await cg.get_variable(config[CONF_TEMPERATURE_SENSOR])
        cg.add(var.set_temperature_sensor(temp_sens))
    if CONF_POWER_SENSOR in config:
        power_sens = await cg.get_variable(config[CONF_POWER_SENSOR])
        cg.add(var.set_power_sensor(power_sens))
        cg.add(var.set_power_settling_time(config[CONF_POWER_SETTLING_TIME]))

    transmitter = await cg.get_variable(config[CONF_TRANSMITTER_ID])
    cg.add(var.set_transmitter(transmitter))
