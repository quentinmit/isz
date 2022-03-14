#pragma once

#include <bits/stdc++.h>

#include "esphome/core/component.h"
#include "esphome/core/defines.h"

#include "esphome/components/display/display_buffer.h"
#include "esphome/components/display/widgets.h"
#include "esphome/components/mqtt/mqtt_client.h"

#include <PNGdec.h>

namespace isz {
  class MQTTImage : public esphome::display::Widget, public esphome::Component {
  public:
    void set_size_topic(const std::string &size_topic) { size_topic_ = size_topic; }
    void set_image_topic(const std::string &image_topic) { image_topic_ = image_topic; }

    void setup() override;
    float get_setup_priority() const override;

    virtual void invalidate_layout();
    virtual void draw(esphome::display::DisplayBuffer* it, int x1, int y1, int width, int height);

  protected:
    std::string size_topic_{};
    std::string image_topic_{};

    std::string image_data_{};
    PNG png_;
    void update_image_(const std::string &topic, const std::string &payload);

    void send_size_request_(int width, int height);
  private:
    int last_width_ = 0, last_height_ = 0;
  };
}
