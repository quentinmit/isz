from esphome.components import display, mqtt
import esphome.config_validation as cv
import esphome.codegen as cg

from esphome.const import (
    CONF_RETAIN,
)

CODEOWNERS = ["@quentinmit"]

DEPENDENCIES = ["display"]

isz_ns = cg.global_ns.namespace("isz")

# No global config
CONFIG_SCHEMA = {}

CONF_SIZE_TOPIC = "size_topic"
CONF_IMAGE_TOPIC = "image_topic"

@display.register_widget(
    "mqtt_image",
    isz_ns.class_("MQTTImage", display.Widget, cg.Component),
    cv.All(
        cv.requires_component("mqtt"),
        {
            cv.Required(CONF_SIZE_TOPIC): cv.publish_topic,
            cv.Required(CONF_IMAGE_TOPIC): cv.subscribe_topic,
            cv.Optional(CONF_RETAIN, default=True): cv.boolean,
        },
    ),
)
async def mqtt_image_widget(var, config):
    await cg.register_component(var, config)

    # Use custom version that supports std::function
    cg.add_library(
        "PNGdec", # bitbank2/PNGdec
        "1.0.1",
        "https://github.com/quentinmit/PNGdec/archive/master.zip",
    )

    cg.add(var.set_size_topic(config[CONF_SIZE_TOPIC]))
    cg.add(var.set_image_topic(config[CONF_IMAGE_TOPIC]))
