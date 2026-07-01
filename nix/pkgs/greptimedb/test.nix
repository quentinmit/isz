{ lib, ... }:
{
  name = "greptimedb-test";
  nodes.machine =
    { lib, pkgs, ... }:
    {
      services.greptimedb = {
        enable = true;
      };
      environment.systemPackages = with pkgs; [
        mariadb.client
      ];
    };
  testScript = ''
    import json
    machine.wait_for_unit("greptimedb.service")
    machine.wait_until_succeeds("""mariadb -h 127.0.0.1 -P 4002 <<EOF
    -- Metrics: gRPC call latency in milliseconds
    CREATE TABLE grpc_latencies (
      ts TIMESTAMP TIME INDEX,
      host STRING,
      method_name STRING,
      latency DOUBLE,
      PRIMARY KEY (host, method_name)
    );
    INSERT INTO grpc_latencies (ts, host, method_name, latency) VALUES
      ('2024-07-11 20:00:06', 'host1', 'GetUser', 103.0),
      ('2024-07-11 20:00:06', 'host2', 'GetUser', 113.0),
      ('2024-07-11 20:00:07', 'host1', 'GetUser', 103.5),
      ('2024-07-11 20:00:07', 'host2', 'GetUser', 107.0),
      ('2024-07-11 20:00:08', 'host1', 'GetUser', 104.0),
      ('2024-07-11 20:00:08', 'host2', 'GetUser', 96.0),
      ('2024-07-11 20:00:09', 'host1', 'GetUser', 104.5),
      ('2024-07-11 20:00:09', 'host2', 'GetUser', 114.0);
    EOF""")
    resp = json.loads(machine.succeed("curl -X POST --data-urlencode 'query=grpc_latencies' --data-urlencode 'start=2024-07-11 20:00:00Z' --data-urlencode 'end=2024-07-11 20:00:20Z' --data-urlencode 'step=15s' 'http://localhost:4000/v1/prometheus/api/v1/query_range'"))
    assert resp["status"] == "success"
  '';
}
