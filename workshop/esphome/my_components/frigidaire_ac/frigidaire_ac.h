#pragma once

#include "esphome/components/climate_ir_power/climate_ir_power.h"

namespace esphome {
namespace frigidaire_ac {

static const char *const TAG = "climate.frigidaire_ac";

class FrigidaireACClimate : public climate_ir_power::ClimateIRPower {
 private:
  enum IR : uint8_t {
    FAN_DOWN = 4,
      FAN_UP = 1,
      FAN_AUTO = 15,

      MODE_ESAVE = 2,
      MODE_FAN = 7,
      MODE_COOL = 9,

      TEMP_DOWN = 13,
      TEMP_UP = 14,

      POWER = 17,
      };
 public:
 FrigidaireACClimate() : ClimateIRPower(0xF508, 60, 90) {};
  //FrigidaireACClimate() : ir_address_(0xF508), tempf_min_(60), tempf_max_(90) {};
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
        climate::CLIMATE_FAN_AUTO,
        climate::CLIMATE_FAN_LOW,
        climate::CLIMATE_FAN_MEDIUM,
        climate::CLIMATE_FAN_HIGH,
      });
    return traits;
  }
};
}  // namespace frigidaire_ac
}  // namespace esphome
