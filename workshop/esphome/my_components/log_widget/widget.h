#pragma once

#include <bits/stdc++.h>

#include "esphome/core/component.h"
#include "esphome/core/defines.h"

#include "esphome/components/display/display_buffer.h"
#include "esphome/components/display/widgets.h"

#include <PNGdec.h>

namespace isz {
  class LogWidget : public esphome::display::Widget, public esphome::Component {
  public:
    void set_font(esphome::display::Font* font) { font_ = font; }

    void setup() override;
    float get_setup_priority() const override;

    virtual void invalidate_layout();
    virtual void draw(esphome::display::DisplayBuffer* it, int x1, int y1, int width, int height);

  protected:
    esphome::display::Font* font_;
    std::deque<std::string> lines_;
    int max_lines_ = 10;
  };
}
