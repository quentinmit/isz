import esphome.codegen as cg
import esphome.config_validation as cv
from esphome.components import (
    climate_ir_power,
)
from esphome.const import CONF_ID

AUTO_LOAD = ["climate_ir_power"]

frigidaire_ac_ns = cg.esphome_ns.namespace("frigidaire_ac")
FrigidaireACClimate = frigidaire_ac_ns.class_("FrigidaireACClimate", climate_ir_power.ClimateIRPower)

CONFIG_SCHEMA = climate_ir_power.CLIMATE_IR_POWER_SCHEMA.extend(
    {
        cv.GenerateID(): cv.declare_id(FrigidaireACClimate),
    }
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await climate_ir_power.register_climate_ir_power(var, config)
