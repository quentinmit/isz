{ python3
, piscsi
}:
python3.pkgs.buildPythonApplication {
  pname = "piscsi-web";
  inherit (piscsi) src version;
  sourceRoot = "source/python/web";

  # Upstream doesn't ship a proper pyproject.toml.
  format = "pyproject";
  postPatch = ''
    cat >>pyproject.toml <<EOF

    [project]
    name = "piscsi-web"
    version = "${piscsi.version}"
    dependencies = [
      "Babel",
      "bjoern",
      "blinker",
      "charset-normalizer",
      "click",
      "Flask",
      "flask-babel",
      "itsdangerous",
      "Jinja2",
      "MarkupSafe",
      "piscsi-common",
      "protobuf",
      "pytz",
      "requests",
      "simplepam",
      "ua-parser",
      "vcgencmd",
      "Werkzeug",
    ]
    [project.scripts]
    piscsi-web = "web:main"
    EOF

    substituteInPlace src/web.py \
      --replace-fail 'if __name__ == "__main__"' 'def main()'
  '';

  propagatedBuildInputs = with python3.pkgs; [
    setuptools
    babel
    bjoern
    blinker
    charset-normalizer
    click
    flask
    flask-babel
    itsdangerous
    jinja2
    piscsi-common
    protobuf
    pytz
    requests
    simplepam
    ua-parser
    vcgencmd
  ];
}
