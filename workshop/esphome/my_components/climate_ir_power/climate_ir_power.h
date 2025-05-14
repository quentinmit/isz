#pragma once

#include "esphome/components/climate/climate.h"
#include "esphome/components/sensor/sensor.h"
#include "esphome/components/remote_base/remote_base.h"
#include "esphome/components/remote_transmitter/remote_transmitter.h"
#include "esphome/components/remote_base/nec_protocol.h"

namespace esphome {
namespace climate_ir_power {

static const char *const TAG = "climate.climate_ir_power";

class ClimateIRPower : public Component, public climate::Climate {
 protected:
  const uint16_t ir_address_;
  const uint8_t tempf_min_;
  const uint8_t tempf_max_;
 ClimateIRPower(uint16_t ir_address, uint8_t tempf_min, uint8_t tempf_max) : ir_address_(ir_address), tempf_min_(tempf_min), tempf_max_(tempf_max) {};
 public:
  void setup() override {
    if (this->temperature_sensor_) {
      this->temperature_sensor_->add_on_state_callback([this](float state) {
          this->current_temperature = state;
          // current temperature changed, publish state
          this->publish_state();
        });
      this->current_temperature = this->temperature_sensor_->state;
    } else {
      this->current_temperature = NAN;
    }
    this->mode = climate::CLIMATE_MODE_OFF;
    this->preset = climate::CLIMATE_PRESET_NONE;
  }
  void control(const climate::ClimateCall &call) override;

  climate::ClimateTraits traits() override {
    // The capabilities of the climate device
    auto traits = climate::ClimateTraits();
    traits.set_visual_min_temperature(fahrenheit_to_celsius(tempf_min_));
    traits.set_visual_max_temperature(fahrenheit_to_celsius(tempf_max_));
    traits.set_visual_temperature_step(1);
    if (this->temperature_sensor_) {
      traits.set_supports_current_temperature(true);
    }
    if (this->power_sensor_) {
      traits.set_supports_action(true);
    }
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

  void send_ir_(uint8_t cmd, uint8_t count = 1, uint32_t send_wait = 10000) {
    if (this->transmitter_ == NULL) {
      ESP_LOGW(TAG, "missing IR transmitter");
      return;
    }
    auto call = this->transmitter_->transmit();
    remote_base::NECData data{};
    data.address = ir_address_;
    data.command = cmd | (~cmd)<<8;
    data.command_repeats = 1;
    remote_base::NECProtocol().encode(call.get_data(), data);
    call.set_send_times(count);
    call.set_send_wait(send_wait); // ms
    call.perform();
  }
};
}  // namespace climate_ir_power
}  // namespace esphome
