{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  hatchling,
  mcp,
  mysql-connector,
  pyyaml,
  aiohttp,
  jinja2,
  pytestCheckHook,
  pytest-asyncio,
}:
buildPythonApplication (finalAttrs: {
  pname = "greptimedb-mcp-server";
  version = "0.6.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "GreptimeTeam";
    repo = "greptimedb-mcp-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Pcb+1QOXDaHSHgoI4q3hZOVvobGoHMtbOWjfygd/7PE=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    mcp
    mysql-connector
    pyyaml
    aiohttp
    jinja2
  ];

  pythonImportsCheck = [
    "greptimedb_mcp_server"
    "greptimedb_mcp_server.server"
  ];

  nativeCheckInputs = [
    pytestCheckHook
    pytest-asyncio
  ];

  meta = {
    description = "MCP server for GreptimeDB with SQL/TQL/PromQL support, sensitive data masking, and prompt templates for observability data analysis";
    homepage = "https://github.com/GreptimeTeam/greptimedb-mcp-server";
    changelog = "https://github.com/GreptimeTeam/greptimedb-mcp-server/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.quentin ];
    mainProgram = "greptimedb-mcp-server";
  };
})
