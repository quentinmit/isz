#pragma once

#include "esphome/components/climate_ir_power/climate_ir_power.h"

namespace esphome {
namespace kenmore_ac {

static const char *const TAG = "climate.kenmore_ac";

class KenmoreACClimate : public climate_ir_power::ClimateIRPower {
 private:
  enum IR : uint8_t {
    FAN_SPEED = 153,

    MODE = 155,
    ESAVE = 130,

    TEMP_DOWN = 138,
    TEMP_UP = 133,

    POWER = 129,
  };
 public:
 KenmoreACClimate() : ClimateIRPower(0x6681, 60, 86) {};
  void setup() override;
  void control(const climate::ClimateCall &call) override;

  climate::ClimateTraits traits() override {
    auto traits = ClimateIRPower::traits();
    traits.set_supported_modes({
        climate::CLIMATE_MODE_OFF,
        climate::CLIMATE_MODE_COOL,
        climate::CLIMATE_MODE_FAN_ONLY,
      });
    traits.set_supported_presets({
        climate::CLIMATE_PRESET_NONE,
        climate::CLIMATE_PRESET_ECO,
      });
    traits.set_supported_fan_modes({
        climate::CLIMATE_FAN_LOW,
        climate::CLIMATE_FAN_HIGH,
      });
    return traits;
  }
};
}  // namespace kenmore_ac
}  // namespace esphome
