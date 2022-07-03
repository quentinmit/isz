#include "widget.h"

#include "esphome/components/logger/logger.h"

static const char* TAG = "isz.log_widget";

namespace isz {
  using namespace esphome;
  using esphome::display::COLOR_OFF;

  float LogWidget::get_setup_priority() const { return esphome::setup_priority::BUS; }

  void LogWidget::setup() {
    if (esphome::logger::global_logger != nullptr) {
      esphome::logger::global_logger->add_on_log_callback([this](int level, const char *tag, const char *message) {
        if (lines_.size() >= max_lines_) {
          lines_.resize(max_lines_-1);
        }
        std::string s;
        esphome::time::ESPTime now;
        if (time_ && (now = time_->now()).is_valid()) {
          s = now.strftime("[%H:%M:%S]");
        } else {
          char buf[128];
          uint32_t m = millis();
          snprintf(buf, 128, "[%d.%03ds]", m / 1000, m % 1000);
          s = buf;
        }
        while (char c = *(message++)) {
          if (c == 0x1B) {
            // Strip escape sequences
            if (*(message++) == '[') {
              while (*message && (*message < 0x40 || *message > 0x7E)) {
                message++;
              }
              if (*message) message++;
            }
            continue;
          }
          s.push_back(c);
          if (s.size() >= 200) {
            break;
          }
        }
        lines_.emplace_front(s);
      });
    }
  }

  void LogWidget::invalidate_layout() {}
  void LogWidget::draw(esphome::display::DisplayBuffer* it, int x1, int y1, int width, int height) {
    int unused1, unused2, unused3, line_height;
    this->font_->measure("", &unused1, &unused2, &unused3, &line_height);
    max_lines_ = height / line_height;
    int y_at = y1;
    for (std::string &line: lines_) {
      if (y_at > y1 + height) {
        return;
      }
      it->print(x1, y_at, font_, COLOR_OFF, line.c_str());
      y_at += line_height;
    }
  }
}
