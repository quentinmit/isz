#include "frigidaire_ac.h"

namespace esphome {
namespace frigidaire_ac {

void FrigidaireACClimate::setup() {
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
  if (this->power_sensor_) {
    this->power_sensor_->add_on_state_callback([this](float power) {
      climate::ClimateAction old_action = this->action;
      climate::ClimateMode old_mode = this->mode;
      bool update_mode = millis() > (last_change_time_ + power_settling_time_);
      if (power > 150) {
        this->action = climate::CLIMATE_ACTION_COOLING;
        if (update_mode) {
          this->mode = climate::CLIMATE_MODE_COOL;
        }
      } else if (power > 50) {
        this->action = climate::CLIMATE_ACTION_FAN;
        if (update_mode && this->mode == climate::CLIMATE_MODE_OFF) {
          this->mode = climate::CLIMATE_MODE_FAN_ONLY;
        }
      } else {
        this->action = climate::CLIMATE_ACTION_IDLE;
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
  // This will be called by App.setup()
}
void FrigidaireACClimate::control(const climate::ClimateCall &call) {
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
    }
    if (new_preset == climate::CLIMATE_PRESET_ECO) {
      send_ir_(IR::MODE_ESAVE);
    } else {
      switch (new_mode) {
      case climate::CLIMATE_MODE_COOL:
        send_ir_(IR::MODE_COOL);
        break;
      case climate::CLIMATE_MODE_FAN_ONLY:
        send_ir_(IR::MODE_FAN);
        this->target_temperature_f = 0;
        break;
      case climate::CLIMATE_MODE_OFF:
        this->target_temperature_f = 0;
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
      send_ir_(IR::TEMP_DOWN, TEMPF_MAX-TEMPF_MIN, 50000);
      uint8_t up_steps = tempf-TEMPF_MIN;
      ESP_LOGD(TAG, "sending %d UP steps", up_steps);
      send_ir_(IR::TEMP_UP, up_steps, 50000);
    }
    this->target_temperature = fahrenheit_to_celsius(tempf);
    this->target_temperature_f = tempf;
    changed = true;
  }
  if (call.get_fan_mode().has_value()) {
    climate::ClimateFanMode fan_mode = *call.get_fan_mode();
    ESP_LOGD(TAG, "fan_mode before: 0x%02X new: 0x%02X", *this->fan_mode, fan_mode);
    switch (fan_mode) {
    case climate::CLIMATE_FAN_AUTO:
      send_ir_(IR::FAN_DOWN, 1);
      send_ir_(IR::FAN_AUTO);
      break;
    case climate::CLIMATE_FAN_HIGH:
      send_ir_(IR::FAN_UP, 3);
      break;
    case climate::CLIMATE_FAN_MEDIUM:
      send_ir_(IR::FAN_DOWN, 3);
      send_ir_(IR::FAN_UP);
      break;
    case climate::CLIMATE_FAN_LOW:
      send_ir_(IR::FAN_DOWN, 3);
      break;
    default:
      // Unsupported fan modes
      break;
    };
    this->fan_mode = fan_mode;
    changed = true;
  }
  if (changed) {
    this->last_change_time_ = millis();
    this->publish_state();
  }
}

};
};
