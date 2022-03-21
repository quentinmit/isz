#include "widget.h"
#include "esphome/components/json/json_util.h"
#include <PNGdec.h>

static const char* TAG = "isz.mqtt_image";

namespace isz {
  using namespace esphome;
  using esphome::display::COLOR_ON;
  using esphome::display::COLOR_OFF;

  float MQTTImage::get_setup_priority() const { return esphome::setup_priority::AFTER_CONNECTION; }

  void MQTTImage::setup() {
    esphome::mqtt::global_mqtt_client->subscribe(
                                                 image_topic_,
                                                 std::bind(
                                                           &MQTTImage::update_image_,
                                                           this,
                                                           std::placeholders::_1,
                                                           std::placeholders::_2),
                                                 0);
  }

  void MQTTImage::update_image_(const std::string &topic, const std::string &payload) {
    image_data_ = payload;
    int ret = png_.openRAM((uint8_t*)image_data_.data(), image_data_.size(), NULL);
    if (ret != PNG_SUCCESS) {
      image_data_.clear();
      ESP_LOGE(TAG, "[%s] Received invalid PNG: %d", image_topic_.c_str(), ret);
      return;
    }
    minimum_width_ = preferred_width_ = png_.getWidth();
    minimum_height_ = preferred_height_ = png_.getHeight();
    ESP_LOGD(TAG, "[%s] Received %dx%d image (%dbpp, pixel type %d)", image_topic_.c_str(), png_.getWidth(), png_.getHeight(), png_.getBpp(), png_.getPixelType());
  }

  void MQTTImage::invalidate_layout() {}
  void MQTTImage::draw(esphome::display::DisplayBuffer* it, int x1, int y1, int width, int height) {
    send_size_request_(width, height);
    if (image_data_.empty()) {
      return;
    }
    png_.decode([it, x1, y1](PNGDRAW *pDraw) {
      if (pDraw->iBpp == 1) {
        for (int x = 0; x < pDraw->iWidth; x++) {
          it->draw_pixel_at(x1+x, y1+pDraw->y, (pDraw->pPixels[x/8] & (0x80 >> (x%8))) ? COLOR_ON : COLOR_OFF);
        };
      } else {
        for (int x = 0; x < pDraw->iWidth; x++) {
          it->draw_pixel_at(x1+x, y1+pDraw->y, (pDraw->pPixels[x] != 0) ? COLOR_ON : COLOR_OFF);
        };
      }
    }, 0);
  }

  std::string build_json(const esphome::json::json_build_t &f) {
    DynamicJsonDocument json_document(10000);
    JsonObject root = json_document.to<JsonObject>();
    f(root);
    json_document.shrinkToFit();

    std::string output;
    serializeJson(json_document, output);
    return output;
  }

  bool publish_json(const std::string &topic, const json::json_build_t &f,
                    uint8_t qos = 0, bool retain = false) {
    std::string message = build_json(f);
    return esphome::mqtt::global_mqtt_client->publish(topic, message, qos, retain);
  }


  void MQTTImage::send_size_request_(int width, int height) {
    if (width == last_width_ && height == last_height_) {
      return;
    }
    if (publish_json(
                     size_topic_,
                     [this, width, height](JsonObject root) {
                       ESP_LOGD(TAG, "New size %dx%d", width, height);
                       root["width"] = width;
                       root["height"] = height;
                       ESP_LOGD(TAG, "Sending %d items", root.size());
                     },
                     0, true
                     )) {
      last_width_ = width;
      last_height_ = height;
    }
  }
}
