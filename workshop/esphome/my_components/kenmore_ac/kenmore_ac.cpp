#include "kenmore_ac.h"

namespace esphome {
namespace kenmore_ac {

void KenmoreACClimate::setup() {
  ClimateIRPower::setup();
  if (this->power_sensor_) {
    this->power_sensor_->add_on_state_callback([this](float power) {
      climate::ClimateAction old_action = this->action;
      climate::ClimateMode old_mode = this->mode;
      bool update_mode = millis() > (last_change_time_ + power_settling_time_);
      // Off = 1.5 W
      // ESave = 2.1 W
      // Fan 1 = ~37 W
      // Fan 2 = ~53 W
      // Cool = ~290 W
      if (power > 150) {
        this->action = climate::CLIMATE_ACTION_COOLING;
        if (update_mode) {
          this->mode = climate::CLIMATE_MODE_COOL;
        }
      } else if (power > 25) {
        this->action = climate::CLIMATE_ACTION_FAN;
        if (update_mode && this->mode == climate::CLIMATE_MODE_OFF) {
          this->mode = climate::CLIMATE_MODE_FAN_ONLY;
        }
        if (update_mode && this->preset != climate::CLIMATE_PRESET_ECO) {
          this->fan_mode = (power > 45) ? climate::CLIMATE_FAN_HIGH : climate::CLIMATE_FAN_LOW;
        }
      } else if (power < 2) {
         this->action = climate::CLIMATE_ACTION_OFF;
        if (update_mode) {
          this->mode = climate::CLIMATE_MODE_OFF;
          this->preset = climate::CLIMATE_PRESET_NONE;
        }
      } else if (power < 5) {
        this->action = climate::CLIMATE_ACTION_IDLE;
        if (update_mode) {
          this->mode = climate::CLIMATE_MODE_COOL;
          this->preset = climate::CLIMATE_PRESET_ECO;
        }
      }
      if (mode != old_mode || action != old_action) {
        this->publish_state();
      }
    });
  }
  auto restore = this->restore_state_();
  if (restore.has_value()) {
    restore->apply(this);
  }
}
void KenmoreACClimate::control(const climate::ClimateCall &call) {
  bool changed = false;
  climate::ClimateMode new_mode = this->mode;
  climate::ClimatePreset new_preset = *this->preset;
  if (call.get_mode().has_value()) {
    new_mode = *call.get_mode();
    new_preset = climate::CLIMATE_PRESET_NONE;
  }
  if (call.get_preset().has_value()) {
    switch (*call.get_preset()) {
    case climate::CLIMATE_PRESET_ECO:
      new_mode = climate::CLIMATE_MODE_COOL;
      new_preset = climate::CLIMATE_PRESET_ECO;
      break;
    case climate::CLIMATE_PRESET_NONE:
      new_preset = climate::CLIMATE_PRESET_NONE;
      break;
    default:
      ESP_LOGW(TAG, "Unsupported preset");
      break;
    }
  }
  if (new_mode != this->mode || new_preset != this->preset) {
    // Send mode to hardware
    if (this->mode == climate::CLIMATE_MODE_OFF) {
      send_ir_(IR::POWER);
      this->target_temperature_f = 0;
      // Restores to previous fan/cool state, but eco is turned off.
      this->preset = climate::CLIMATE_PRESET_NONE;
      // Assume it was in cool before.
      this->mode = climate::CLIMATE_MODE_COOL;
    }
    if (new_preset == climate::CLIMATE_PRESET_ECO) {
      if (this->mode != climate::CLIMATE_MODE_COOL) {
        send_ir_(IR::MODE);
      }
      if (this->preset != climate::CLIMATE_PRESET_ECO) {
        send_ir_(IR::ESAVE);
      }
    } else {
      switch (new_mode) {
      case climate::CLIMATE_MODE_COOL:
        if (this->mode != climate::CLIMATE_MODE_COOL) {
          send_ir_(IR::MODE);
        }
        if (this->preset == climate::CLIMATE_PRESET_ECO) {
          send_ir_(IR::ESAVE);
        }
        break;
      case climate::CLIMATE_MODE_FAN_ONLY:
        if (this->mode != climate::CLIMATE_MODE_FAN_ONLY) {
          send_ir_(IR::MODE);
        }
        this->target_temperature_f = 0;
        break;
      case climate::CLIMATE_MODE_OFF:
        this->target_temperature_f = 0;
        if (this->mode == climate::CLIMATE_MODE_FAN_ONLY) {
          // Switch to cool before powering off.
          send_ir_(IR::MODE);
        }
        send_ir_(IR::POWER);
        break;
      default:
        ESP_LOGW(TAG, "Unsupported mode %d", new_mode);
      }
    }

    // Publish updated state
    this->mode = new_mode;
    this->preset = new_preset;
    changed = true;
  }
  if (call.get_target_temperature().has_value()) {
    // User requested target temperature change
    float temp = *call.get_target_temperature();
    this->target_temperature = fahrenheit_to_celsius((uint8_t)celsius_to_fahrenheit(temp));
    changed = true;
  }
  int8_t tempf = celsius_to_fahrenheit(this->target_temperature);
  if (this->mode == climate::CLIMATE_MODE_COOL && tempf != this->target_temperature_f) {
    // Send target temp to climate
    if (this->target_temperature_f > 0) {
      // Send delta
      int32_t tempf_delta = tempf - this->target_temperature_f;
      if (tempf_delta > 0) {
        ESP_LOGD(TAG, "temp up %d steps", tempf_delta);
        send_ir_(IR::TEMP_UP, tempf_delta, 50000);
      } else if (tempf_delta < 0) {
        ESP_LOGD(TAG, "temp down %d steps", -tempf_delta);
        send_ir_(IR::TEMP_DOWN, -tempf_delta, 50000);
      }
    } else {
      if (this->action == climate::CLIMATE_ACTION_COOLING) {
        // If we're already cooling, start by lowering the temperature so we
        // don't interrupt the cooling.
        send_ir_(IR::TEMP_DOWN, tempf_max_-tempf_min_, 50000);
        uint8_t up_steps = tempf-tempf_min_;
        ESP_LOGD(TAG, "sending %d UP steps", up_steps);
        send_ir_(IR::TEMP_UP, up_steps, 50000);
      } else {
        // If we're not cooling, start by raising the temperature so we don't
        // accidentally start cooling.
        send_ir_(IR::TEMP_UP, tempf_max_-tempf_min_, 50000);
        uint8_t down_steps = tempf_max_-tempf;
        ESP_LOGD(TAG, "sending %d DOWN steps", down_steps);
        send_ir_(IR::TEMP_DOWN, down_steps, 50000);
      }
    }
    this->target_temperature = fahrenheit_to_celsius(tempf);
    this->target_temperature_f = tempf;
    changed = true;
  }
  if (call.get_fan_mode().has_value()) {
    climate::ClimateFanMode new_fan_mode = *call.get_fan_mode();
    ESP_LOGD(TAG, "fan_mode before: 0x%02X new: 0x%02X", *this->fan_mode, fan_mode);
    if (new_fan_mode != *fan_mode) {
      send_ir_(IR::FAN_SPEED);
    }
    this->fan_mode = new_fan_mode;
    changed = true;
  }
  if (changed) {
    this->last_change_time_ = millis();
    this->publish_state();
  }
}

};
};
