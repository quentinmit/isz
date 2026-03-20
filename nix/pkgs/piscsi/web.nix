{
  piscsi,
  python3Packages,
}:
python3Packages.buildPythonApplication {
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
      "idna",
      "itsdangerous",
      "Jinja2",
      "MarkupSafe",
      "piscsi-common",
      "protobuf",
      "python-pam",
      "pytz",
      "requests",
      "ua-parser",
      "vcgencmd",
      "Werkzeug",
    ]
    [tool.setuptools]
    script-files = ["src/web.py"]
    EOF

    cat >MANIFEST.in <<EOF
    graft src
    EOF

    sed -i '1i#!/usr/bin/env python3' src/web.py
    substituteInPlace src/web.py \
      --replace-fail "Flask(__name__)" 'Flask("web_utils")'
  '';

  build-system = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    babel
    bjoern
    blinker
    charset-normalizer
    click
    flask
    flask-babel
    idna
    itsdangerous
    jinja2
    markupsafe
    piscsi-common
    protobuf
    python-pam
    pytz
    requests
    ua-parser
    vcgencmd
  ];

  meta.mainProgram = "web.py";
}
