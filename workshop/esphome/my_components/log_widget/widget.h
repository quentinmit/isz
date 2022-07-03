#pragma once

#include <bits/stdc++.h>

#include "esphome/core/component.h"
#include "esphome/core/defines.h"

#include "esphome/components/display/display_buffer.h"
#include "esphome/components/display/widgets.h"
#include "esphome/components/time/real_time_clock.h"

namespace isz {
  class LogWidget : public esphome::display::Widget, public esphome::Component {
  public:
    void set_font(esphome::display::Font* font) { font_ = font; }
    void set_time(esphome::time::RealTimeClock *time) { time_ = time; }

    void setup() override;
    float get_setup_priority() const override;

    virtual void invalidate_layout();
    virtual void draw(esphome::display::DisplayBuffer* it, int x1, int y1, int width, int height);

  protected:
    esphome::display::Font* font_;
    esphome::time::RealTimeClock *time_;

    std::deque<std::string> lines_;
    int max_lines_ = 10;
  };
}
