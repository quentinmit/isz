#pragma once

#include "esphome/components/climate/climate.h"
#include "esphome/components/sensor/sensor.h"
#include "esphome/components/remote_base/remote_base.h"
#include "esphome/components/remote_transmitter/remote_transmitter.h"
#include "esphome/components/remote_base/nec_protocol.h"

namespace esphome {
namespace frigidaire_ac {

static const char *const TAG = "climate.frigidaire_ac";

class FrigidaireACClimate : public Component, public climate::Climate {
 protected:
  const uint16_t IR_ADDRESS = 0xF508;
  const uint8_t TEMPF_MIN = 60;
  const uint8_t TEMPF_MAX = 90;
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
  void setup() override;
  void control(const climate::ClimateCall &call) override;

  climate::ClimateTraits traits() override {
    // The capabilities of the climate device
    auto traits = climate::ClimateTraits();
    traits.set_visual_min_temperature(fahrenheit_to_celsius(TEMPF_MIN));
    traits.set_visual_max_temperature(fahrenheit_to_celsius(TEMPF_MAX));
    traits.set_visual_temperature_step(1);
    if (this->temperature_sensor_) {
      traits.set_supports_current_temperature(true);
    }
    if (this->power_sensor_) {
      traits.set_supports_action(true);
    }
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

  void set_temperature_sensor(sensor::Sensor *sensor) {
    temperature_sensor_ = sensor;
  }
  void set_power_sensor(sensor::Sensor *sensor) {
    power_sensor_ = sensor;
  }
  void set_transmitter(remote_transmitter::RemoteTransmitterComponent *transmitter) {
    this->transmitter_ = transmitter;
  }
  void set_power_settling_time(uint32_t ms) {
    this->power_settling_time_ = ms;
  }
 protected:
  sensor::Sensor *temperature_sensor_ = NULL;
  sensor::Sensor *power_sensor_ = NULL;
  remote_transmitter::RemoteTransmitterComponent *transmitter_;
  uint32_t last_change_time_ = 0;
  uint32_t power_settling_time_ = 0;
  uint32_t target_temperature_f = 0;

  void send_ir_(IR cmd, uint8_t count = 1, uint32_t send_wait = 10000) {
    if (this->transmitter_ == NULL) {
      ESP_LOGW(TAG, "missing IR transmitter");
      return;
    }
    auto call = this->transmitter_->transmit();
    remote_base::NECData data{};
    data.address = IR_ADDRESS;
    data.command = (uint8_t)cmd | (~(uint8_t)cmd)<<8;
    remote_base::NECProtocol().encode(call.get_data(), data);
    call.set_send_times(count);
    call.set_send_wait(send_wait); // ms
    call.perform();
    }
};
}  // namespace frigidaire_ac
}  // namespace esphome
