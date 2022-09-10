from esphome.components import light
import esphome.config_validation as cv
import esphome.codegen as cg
from esphome.const import (
    CONF_OUTPUT_ID,
    CONF_MIN_VALUE,
    CONF_MAX_VALUE,
    CONF_GAMMA_CORRECT,
    CONF_DEFAULT_TRANSITION_LENGTH,
    CONF_SWITCH_DATAPOINT,
    CONF_COLD_WHITE_COLOR_TEMPERATURE,
    CONF_WARM_WHITE_COLOR_TEMPERATURE,
    CONF_COLOR_INTERLOCK,
)
from esphome.components.tuya import CONF_TUYA_ID, Tuya

DEPENDENCIES = ["tuya"]

CONF_WORK_MODE_DATAPOINT = "work_mode_datapoint"
CONF_DIMMER_DATAPOINT = "dimmer_datapoint"
CONF_COLOR_TEMPERATURE_DATAPOINT = "color_temperature_datapoint"
CONF_COLOR_TEMPERATURE_INVERT = "color_temperature_invert"
CONF_COLOR_TEMPERATURE_MAX_VALUE = "color_temperature_max_value"
CONF_HSV_DATAPOINT = "hsv_datapoint"

hugoai_ns = cg.esphome_ns.namespace('hugoai')
HugoaiLight = hugoai_ns.class_("HugoaiLight", light.LightOutput, cg.Component)

CONFIG_SCHEMA = cv.All(
    light.BRIGHTNESS_ONLY_LIGHT_SCHEMA.extend(
        {
            cv.GenerateID(CONF_OUTPUT_ID): cv.declare_id(HugoaiLight),
            cv.GenerateID(CONF_TUYA_ID): cv.use_id(Tuya),
            cv.Optional(CONF_WORK_MODE_DATAPOINT): cv.uint8_t,
            cv.Optional(CONF_DIMMER_DATAPOINT): cv.uint8_t,
            cv.Optional(CONF_SWITCH_DATAPOINT): cv.uint8_t,
            cv.Optional(CONF_HSV_DATAPOINT): cv.uint8_t,
            cv.Optional(CONF_COLOR_INTERLOCK, default=True): cv.boolean,
            cv.Inclusive(
                CONF_COLOR_TEMPERATURE_DATAPOINT, "color_temperature"
            ): cv.uint8_t,
            cv.Optional(CONF_COLOR_TEMPERATURE_INVERT, default=True): cv.boolean,
            cv.Optional(CONF_MIN_VALUE, default=10): cv.int_,
            cv.Optional(CONF_MAX_VALUE, default=1000): cv.int_,
            cv.Optional(CONF_COLOR_TEMPERATURE_MAX_VALUE): cv.int_,
            cv.Inclusive(
                CONF_COLD_WHITE_COLOR_TEMPERATURE, "color_temperature"
            ): cv.color_temperature,
            cv.Inclusive(
                CONF_WARM_WHITE_COLOR_TEMPERATURE, "color_temperature"
            ): cv.color_temperature,
            # Change the default gamma_correct and default transition length settings.
            # The Tuya MCU handles transitions and gamma correction on its own.
            cv.Optional(CONF_GAMMA_CORRECT, default=1.0): cv.positive_float,
            cv.Optional(
                CONF_DEFAULT_TRANSITION_LENGTH, default="0s"
            ): cv.positive_time_period_milliseconds,
        }
    ).extend(cv.COMPONENT_SCHEMA),
    cv.has_at_least_one_key(
        CONF_DIMMER_DATAPOINT,
        CONF_SWITCH_DATAPOINT,
        CONF_HSV_DATAPOINT,
    ),
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_OUTPUT_ID])
    await cg.register_component(var, config)
    await light.register_light(var, config)

    if CONF_WORK_MODE_DATAPOINT in config:
        cg.add(var.set_work_mode_id(config[CONF_WORK_MODE_DATAPOINT]))
    if CONF_DIMMER_DATAPOINT in config:
        cg.add(var.set_dimmer_id(config[CONF_DIMMER_DATAPOINT]))
    if CONF_SWITCH_DATAPOINT in config:
        cg.add(var.set_switch_id(config[CONF_SWITCH_DATAPOINT]))
    if CONF_HSV_DATAPOINT in config:
        cg.add(var.set_hsv_id(config[CONF_HSV_DATAPOINT]))
    if CONF_COLOR_TEMPERATURE_DATAPOINT in config:
        cg.add(var.set_color_temperature_id(config[CONF_COLOR_TEMPERATURE_DATAPOINT]))
        cg.add(var.set_color_temperature_invert(config[CONF_COLOR_TEMPERATURE_INVERT]))

        cg.add(
            var.set_cold_white_temperature(config[CONF_COLD_WHITE_COLOR_TEMPERATURE])
        )
        cg.add(
            var.set_warm_white_temperature(config[CONF_WARM_WHITE_COLOR_TEMPERATURE])
        )
    if CONF_MIN_VALUE in config:
        cg.add(var.set_min_value(config[CONF_MIN_VALUE]))
    if CONF_MAX_VALUE in config:
        cg.add(var.set_max_value(config[CONF_MAX_VALUE]))
    if CONF_COLOR_TEMPERATURE_MAX_VALUE in config:
        cg.add(
            var.set_color_temperature_max_value(
                config[CONF_COLOR_TEMPERATURE_MAX_VALUE]
            )
        )

    cg.add(var.set_color_interlock(config[CONF_COLOR_INTERLOCK]))
    paren = await cg.get_variable(config[CONF_TUYA_ID])
    cg.add(var.set_tuya_parent(paren))
