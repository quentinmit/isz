#include "esphome/core/log.h"
#include "hugoai_light.h"
#include "esphome/core/helpers.h"

namespace esphome {
namespace hugoai {

using namespace esphome::tuya;
using esphome::light::ColorMode;

static const char *const TAG = "hugoai.light";

/* Datapoints:

   20: switch_led (bool)
   21: work_mode (enum - white/colour/scene/music)
   22: bright_value_v2 (int - 10-1000)
   23: temp_value_v2 (int - 0-1000)
   24: colour_data_v2 (string - hue 0-360, saturation 0-1000, value 0-1000, 4 char lowercase hex per value)
   25: scene_data_v2 (string)
   26: countdown_1 (int - 0-86400)
   28: control_data
*/

void HugoaiLight::setup() {
  if (this->work_mode_id_.has_value()) {
    this->parent_->register_listener(*this->work_mode_id_, [this](const TuyaDatapoint &datapoint) {
      if (this->state_->current_values != this->state_->remote_values) {
        ESP_LOGD(TAG, "Light is transitioning, datapoint change ignored");
        return;
      }

      auto datapoint_value = datapoint.value_enum;

      auto mode = datapoint_value > 0 ? ColorMode::RGB : ColorMode::COLOR_TEMPERATURE;

      if (this->state_->remote_values.get_color_mode() == mode) {
        return;
      }

      this->state_->current_values.set_color_mode(mode);
      this->state_->remote_values.set_color_mode(mode);
      this->state_->publish_state();
    });
  }

  if (this->color_temperature_id_.has_value()) {
    this->parent_->register_listener(*this->color_temperature_id_, [this](const TuyaDatapoint &datapoint) {
      if (this->state_->current_values != this->state_->remote_values) {
        ESP_LOGD(TAG, "Light is transitioning, datapoint change ignored");
        return;
      }

      auto datapoint_value = datapoint.value_uint;
      if (this->color_temperature_invert_) {
        datapoint_value = this->color_temperature_max_value_ - datapoint_value;
      }

      auto color_temperature = this->cold_white_temperature_ +
        (this->warm_white_temperature_ - this->cold_white_temperature_) *
        (float(datapoint_value) / this->color_temperature_max_value_);

      if (this->state_->remote_values.get_color_temperature() == color_temperature) {
        return;
      }

      this->state_->current_values.set_color_temperature(color_temperature);
      this->state_->remote_values.set_color_temperature(color_temperature);
      this->state_->publish_state();
    });
  }
  if (this->dimmer_id_.has_value()) {
    this->parent_->register_listener(*this->dimmer_id_, [this](const TuyaDatapoint &datapoint) {
      if (this->state_->current_values != this->state_->remote_values) {
        ESP_LOGD(TAG, "Light is transitioning, datapoint change ignored");
        return;
      }

      auto brightness = float(datapoint.value_uint) / this->max_value_;
      if (this->state_->remote_values.get_brightness() == brightness) {
        return;
      }

      this->state_->current_values.set_brightness(brightness);
      this->state_->remote_values.set_brightness(brightness);
      this->state_->publish_state();
    });
  }
  if (switch_id_.has_value()) {
    this->parent_->register_listener(*this->switch_id_, [this](const TuyaDatapoint &datapoint) {
      if (this->state_->current_values != this->state_->remote_values) {
        ESP_LOGD(TAG, "Light is transitioning, datapoint change ignored");
        return;
      }

      auto on = datapoint.value_bool;

      if (this->state_->remote_values.is_on() == on) {
        return;
      }

      this->state_->current_values.set_state(on);
      this->state_->remote_values.set_state(on);
      this->state_->publish_state();
    });
  }
  if (hsv_id_.has_value()) {
    this->parent_->register_listener(*this->hsv_id_, [this](const TuyaDatapoint &datapoint) {
      auto hue = parse_hex<uint16_t>(datapoint.value_string.substr(0, 4));
      auto saturation = parse_hex<uint16_t>(datapoint.value_string.substr(4, 4));
      auto value = parse_hex<uint16_t>(datapoint.value_string.substr(8, 4));
      if (hue.has_value() && saturation.has_value() && value.has_value()) {
        if (this->state_->current_values != this->state_->remote_values) {
          ESP_LOGD(TAG, "Light is transitioning, datapoint change ignored");
          return;
        }

        float red, green, blue;
        hsv_to_rgb(*hue, float(*saturation) / 1000, 1.0, red, green, blue);

        if (this->state_->remote_values.get_red() == red
            && this->state_->remote_values.get_green() == green
            && this->state_->remote_values.get_blue() == blue) {
          return;
        }
        ESP_LOGV(TAG, "received HSV: (%d, %d, %d) -> RGB (%f, %f, %f)", *hue, *saturation, *value, red, green, blue);
        this->state_->current_values.set_brightness(float(*value) / 1000);
        this->state_->current_values.set_red(red);
        this->state_->current_values.set_green(green);
        this->state_->current_values.set_blue(blue);
        this->state_->remote_values.set_brightness(float(*value) / 1000);
        this->state_->remote_values.set_red(red);
        this->state_->remote_values.set_green(green);
        this->state_->remote_values.set_blue(blue);
        this->state_->publish_state();
      }
    });
  }
}

void HugoaiLight::dump_config() {
  ESP_LOGCONFIG(TAG, "Hugoai Dimmer:");
  if (this->dimmer_id_.has_value())
    ESP_LOGCONFIG(TAG, "   Dimmer has datapoint ID %u", *this->dimmer_id_);
  if (this->switch_id_.has_value())
    ESP_LOGCONFIG(TAG, "   Switch has datapoint ID %u", *this->switch_id_);
  if (this->hsv_id_.has_value()) {
    ESP_LOGCONFIG(TAG, "   HSV has datapoint ID %u", *this->hsv_id_);
  }
}

light::LightTraits HugoaiLight::get_traits() {
  auto traits = light::LightTraits();
  if (this->color_temperature_id_.has_value() && this->dimmer_id_.has_value()) {
    if (this->hsv_id_.has_value()) {
      if (this->color_interlock_) {
        traits.set_supported_color_modes({light::ColorMode::RGB, light::ColorMode::COLOR_TEMPERATURE});
      } else {
        traits.set_supported_color_modes(
            {light::ColorMode::RGB_COLOR_TEMPERATURE, light::ColorMode::COLOR_TEMPERATURE});
      }
    } else
      traits.set_supported_color_modes({light::ColorMode::COLOR_TEMPERATURE});
    traits.set_min_mireds(this->cold_white_temperature_);
    traits.set_max_mireds(this->warm_white_temperature_);
  } else if (this->hsv_id_.has_value()) {
    if (this->dimmer_id_.has_value()) {
      if (this->color_interlock_) {
        traits.set_supported_color_modes({light::ColorMode::RGB, light::ColorMode::WHITE});
      } else {
        traits.set_supported_color_modes({light::ColorMode::RGB_WHITE});
      }
    } else
      traits.set_supported_color_modes({light::ColorMode::RGB});
  } else if (this->dimmer_id_.has_value()) {
    traits.set_supported_color_modes({light::ColorMode::BRIGHTNESS});
  } else {
    traits.set_supported_color_modes({light::ColorMode::ON_OFF});
  }
  return traits;
}

void HugoaiLight::setup_state(light::LightState *state) { state_ = state; }

void HugoaiLight::write_state(light::LightState *state) {
  float red = 0.0f, green = 0.0f, blue = 0.0f;
  float color_temperature = 0.0f, brightness = 0.0f;

  ESP_LOGV(TAG, "write_state(brightness=%f, color_brightness=%f, r=%f, g=%f, b=%f, ct=%f)", state->remote_values.get_brightness(), state->remote_values.get_color_brightness(), state->remote_values.get_red(), state->remote_values.get_green(), state->remote_values.get_blue(), state->remote_values.get_color_temperature());

  if (this->hsv_id_.has_value()) {
    if (this->color_temperature_id_.has_value()) {
      state->current_values_as_rgbct(&red, &green, &blue, &color_temperature, &brightness);
      ESP_LOGV(TAG, "write_state(r=%f, g=%f, b=%f, ct=%f, w=%f)", red, green, blue, color_temperature, brightness);
    } else if (this->dimmer_id_.has_value()) {
      state->current_values_as_rgbw(&red, &green, &blue, &brightness);
    } else {
      state->current_values_as_rgb(&red, &green, &blue);
    }
  } else if (this->color_temperature_id_.has_value()) {
    state->current_values_as_ct(&color_temperature, &brightness);
  } else {
    state->current_values_as_brightness(&brightness);
  }

  if (!state->current_values.is_on() && this->switch_id_.has_value()) {
    parent_->set_boolean_datapoint_value(*this->switch_id_, false);
    return;
  }

  auto mode = state->current_values.get_color_mode();

  if (brightness > 0.0f || !color_interlock_ || mode == ColorMode::WHITE || mode == ColorMode::COLOR_TEMPERATURE) {
    if (this->color_temperature_id_.has_value()) {
      uint32_t color_temp_int = static_cast<uint32_t>(color_temperature * this->color_temperature_max_value_);
      if (this->color_temperature_invert_) {
        color_temp_int = this->color_temperature_max_value_ - color_temp_int;
      }
      parent_->set_integer_datapoint_value(*this->color_temperature_id_, color_temp_int);
    }

    if (this->dimmer_id_.has_value()) {
      auto brightness_int = static_cast<uint32_t>(brightness * this->max_value_);
      brightness_int = std::max(brightness_int, this->min_value_);

      parent_->set_integer_datapoint_value(*this->dimmer_id_, brightness_int);
    }

    if (this->work_mode_id_.has_value()) {
      parent_->set_enum_datapoint_value(*this->work_mode_id_, 0);
    }
  }

  if (brightness == 0.0f || !color_interlock_ || mode == ColorMode::RGB) {
    if (this->hsv_id_.has_value()) {
      int hue;
      float saturation, value;
      rgb_to_hsv(red, green, blue, hue, saturation, value);
      char buffer[13];
      sprintf(buffer, "%04x%04x%04x", hue, int(saturation * 1000), int(value * 1000));
      std::string hsv_value = buffer;
      this->parent_->set_string_datapoint_value(*this->hsv_id_, hsv_value);
    }

    if (this->work_mode_id_.has_value()) {
      parent_->set_enum_datapoint_value(*this->work_mode_id_, 1);
    }
  }

  if (this->switch_id_.has_value()) {
    parent_->set_boolean_datapoint_value(*this->switch_id_, true);
  }
}

}  // namespace hugoai
}  // namespace esphome
