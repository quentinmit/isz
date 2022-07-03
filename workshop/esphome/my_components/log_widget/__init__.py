from esphome.components import display
import esphome.config_validation as cv
import esphome.codegen as cg

from esphome.components.display import (
    CONF_FONT,
)

CODEOWNERS = ["@quentinmit"]

DEPENDENCIES = ["display"]

isz_ns = cg.global_ns.namespace("isz")

# No global config
CONFIG_SCHEMA = {}

@display.register_widget(
    "log",
    isz_ns.class_("LogWidget", display.Widget, cg.Component),
    {
        cv.Required(CONF_FONT): display.use_font_id,
    },
)
async def log_widget(var, config):
    await cg.register_component(var, config)

    font = await cg.get_variable(config[CONF_FONT])
    cg.add(var.set_font(font))
