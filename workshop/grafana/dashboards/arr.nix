{ config, pkgs, lib, ... }:
{
  config.isz.grafana.dashboardsV2.arr = {
    title = "Arr";
    #layout = {
    #};
    panels.prowlarr-status-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.options.colorMode = "background";
        spec.fieldConfig.defaults = {
          mappings = [{
            type = "value";
            options."0" = {
              text = "Down";
              color = "red";
              index = 1;
            };
            options."1" = {
              text = "Up";
              color = "green";
              index = 0;
            };
          }];
        };
      };
      prometheus = {
        expr = "prowlarr_system_status";
        legendFormat = "Status";
      };
    };
    #panels.prowlarr-uptime-stat = {
      # TODO
    #};
    panels.prowlarr-health-stat = {
      spec.vizConfig = {
        group = "stat";
      };
      prometheus = [
        {
          expr = "max(prowlarr_system_health_issues)";
          legendFormat = "Health Issues";
          options.color.mode = "thresholds";
          options.thresholds = {
            mode = "absolute";
            steps = [
              { value = null; color = "green"; }
              { value = 1; color = "yellow"; }
              { value = 2; color = "red"; }
            ];
          };
        }
        {
          expr = "max(prowlarr_indexer_enabled_total)";
          legendFormat = "Enabled Indexers";
        }
        {
          expr = "max(prowlarr_indexer_total - prowlarr_indexer_enabled_total)";
          legendFormat = "Disabled Indexers";
          options.color.mode = "thresholds";
          options.thresholds = {
            mode = "absolute";
            steps = [
              { value = null; color = "green"; }
              { value = 1; color = "red"; }
            ];
          };
        }
      ];
    };
    panels.prowlarr-queries-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.fieldConfig.defaults.color.mode = "continuous-BlPu";
      };
      prometheus = [
        {
          expr = "sum(increase(prowlarr_indexer_queries_total[$__range]))";
          legendFormat = "Queries";
        }
        {
          expr = "sum(increase(prowlarr_indexer_grabs_total[$__range]))";
          legendFormat = "Grabs";
        }
        {
          expr = "sum(increase(prowlarr_indexer_failed_queries_total[$__range]))";
          legendFormat = "Query Failures";
          options.color.mode = "thresholds";
          options.thresholds = {
            mode = "absolute";
            steps = [
              { value = null; color = "green"; }
              { value = 15; color = "yellow"; }
              { value = 100; color = "red"; }
            ];
          };
        }
      ];
    };
    panels.prowlarr-latency-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.fieldConfig.defaults.color.mode = "continuous-BlPu";
      };
      prometheus = [
        {
          # N.B. This isn't the average latency!
          # The metric contains the average latency for each indexer for requests since the last exportarr scrape of prowlarr.
          expr = "avg(prowlarr_indexer_average_response_time_ms)";
          legendFormat = "Response Time";
          options.unit = "ms";
        }
        {
          expr = "sum(increase(prowlarr_indexer_failed_queries_total[$__range])) / sum(increase(prowlarr_indexer_queries_total[$__range]))";
          legendFormat = "Failed Queries";
          options.unit = "percentunit";
          options.color.mode = "thresholds";
          options.thresholds = {
            mode = "absolute";
            steps = [
              { value = null; color = "green"; }
              { value = 0.1; color = "yellow"; }
              { value = 0.2; color = "red"; }
            ];
          };
        }
      ];
    };
    panels.prowlarr-vip-stat = {
      spec.vizConfig = {
        group = "stat";
      };
      prometheus = {
        expr = "min(prowlarr_indexer_vip_expires_in_seconds)";
        legendFormat = "Nearest VIP Expiration";
        options.color.mode = "thresholds";
        options.thresholds = {
          mode = "absolute";
          steps = [
            { value = null; color = "red"; }
            { value = 604800; color = "yellow"; }
            { value = 2592000; color = "green"; }
          ];
        };
      };
    };
    panels.prowlarr-indexer-latency = {
      spec.title = "Indexer Latency";
      prometheus.expr = "max(prowlarr_indexer_average_response_time_ms) by (indexer)";
      spec.vizConfig.spec.fieldConfig.defaults.unit = "ms";
    };
    panels.prowlarr-user-agent-queries = {
      spec.title = "User Agent Queries";
      prometheus.expr = "sum(rate(prowlarr_user_agent_queries_total[$__rate_interval])) by (user_agent)";
      spec.vizConfig.spec.fieldConfig.defaults.unit = "reqps";
    };
    panels.prowlarr-queries-by-indexer = {
      spec.title = "Queries by Indexer";
      spec.vizConfig.group = "piechart";
      spec.vizConfig.spec.options = {
        pieType = "donut";
        legend.displayMode = "table";
        legend.placement = "right";
        legend.values = ["percent"];
      };
      prometheus.expr = "sum(increase(prowlarr_indexer_queries_total[$__range])) by (indexer)";
    };
    panels.prowlarr-grabs-by-indexer = {
      spec.title = "Grabs by Indexer";
      spec.vizConfig.group = "piechart";
      spec.vizConfig.spec.options = {
        pieType = "donut";
        legend.displayMode = "table";
        legend.placement = "right";
        legend.values = ["percent"];
      };
      prometheus.expr = "sum(increase(prowlarr_indexer_grabs_total[$__range])) by (indexer)";
    };
    panels.prowlarr-queries-by-user-agent = {
      spec.title = "Queries by User Agent";
      spec.vizConfig.group = "piechart";
      spec.vizConfig.spec.options = {
        pieType = "donut";
        legend.displayMode = "table";
        legend.placement = "right";
        legend.values = ["percent"];
      };
      prometheus.expr = "sum(increase(prowlarr_user_agent_queries_total[$__range])) by (user_agent)";
    };
    panels.prowlarr-grabs-by-user-agent = {
      spec.title = "Grabs by User Agent";
      spec.vizConfig.group = "piechart";
      spec.vizConfig.spec.options = {
        pieType = "donut";
        legend.displayMode = "table";
        legend.placement = "right";
        legend.values = ["percent"];
      };
      prometheus.expr = "sum(increase(prowlarr_user_agent_grabs_total[$__range])) by (user_agent)";
    };
    panels.prowlarr-system-health-issues = {
      spec.title = "System Health Issues";
      spec.vizConfig = {
        group = "table";
        spec.fieldConfig.defaults.links = [{
          title = "Details";
          url = "\${__data.fields.wikiurl}";
          targetBlank = true;
        }];
      };
      prometheus.expr = "max(prowlarr_system_health_issues) by (message, wikiurl)";
      fields.Time.custom."hideFrom.viz" = true;
      fields.Value.custom."hideFrom.viz" = true;
      fields.wikiurl.custom."hideFrom.viz" = true;
    };
    panels.radarr-status-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.options.colorMode = "background";
        spec.fieldConfig.defaults = {
          mappings = [{
            type = "value";
            options."0" = {
              text = "Down";
              color = "red";
              index = 1;
            };
            options."1" = {
              text = "Up";
              color = "green";
              index = 0;
            };
          }];
        };
      };
      prometheus = {
        expr = "radarr_system_status";
        legendFormat = "Status";
      };
    };
    # panels.radarr-uptime-stat = {};
    panels.radarr-movies-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.fieldConfig.defaults.color.mode = "continuous-BlPu";
      };
      prometheus = [
        {
          expr = "radarr_movie_downloaded_total";
          legendFormat = "Downloaded";
        }
        {
          expr = "radarr_movie_monitored_total";
          legendFormat = "Monitored";
        }
        {
          expr = "radarr_movie_wanted_total";
          legendFormat = "Wanted";
        }
      ];
    };
    panels.radarr-downloads-stat = {
      spec.vizConfig = {
        group = "stat";
        spec.fieldConfig.defaults.color.mode = "continuous-BlPu";
      };
      prometheus = [
        {
          expr = "radarr_queue_total";
          legendFormat = "Queued";
        }
        {
          expr = "radarr_movie_downloaded_total";
          legendFormat = "Downloaded";
        }
        {
          expr = "radarr_history_total";
          legendFormat = "History";
        }
        {
          expr = "radarr_movie_filesize_total";
          legendFormat = "Disk Used";
          options.unit = "bytes";
        }
        {
          expr = "radarr_rootfolder_freespace_bytes";
          legendFormat = "Disk Free";
          options.unit = "bytes";
          options.color.mode = "thresholds";
          options.thresholds = {
            mode = "absolute";
            steps = [
              { value = null; color = "red"; }
              { value = 500000000; color = "#EAB839"; }
              { value = 5000000000; color = "green"; }
            ];
          };
        }
      ];
    };
    panels.radarr-qualities = {
      spec.title = "Qualities";
      spec.vizConfig = {
        group = "bargauge";
        spec.fieldConfig.defaults.color.mode = "continuous-BlPu";
        spec.options.orientation = "horizontal";
        spec.options.displayMode = "lcd";
      };
      prometheus.expr = "sum(radarr_movie_quality_total) by (quality)";
      prometheus.legendFormat = "{{quality}}";
    };
    # panels.radarr-network = {};
    panels.radarr-disk = {
      spec.title = "Disk";
      prometheus.expr = "sum(radarr_movie_filesize_total)";
      prometheus.legendFormat = "Used";
      spec.vizConfig.spec.fieldConfig.defaults.unit = "bytes";
    };
    panels.radarr-system-health-issues = {
      spec.title = "System Health Issues";
      spec.vizConfig = {
        group = "table";
        spec.fieldConfig.defaults.links = [{
          title = "Details";
          url = "\${__data.fields.wikiurl}";
          targetBlank = true;
        }];
      };
      prometheus.expr = "max(radarr_system_health_issues) by (message, wikiurl)";
      fields.Time.custom."hideFrom.viz" = true;
      fields.Value.custom."hideFrom.viz" = true;
      fields.wikiurl.custom."hideFrom.viz" = true;
    };
  };
}
