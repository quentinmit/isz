{
  piscsi,
  drivers,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "piscsi-web";
  inherit (piscsi) src version;
  sourceRoot = "source/python/web";

  # Upstream doesn't ship a proper pyproject.toml.
  format = "pyproject";

  patches = [
    ./0002-web-paths.patch
  ];
  patchFlags = "-p3";
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
    script-files = ["piscsi-web"]
    EOF

    cat >MANIFEST.in <<EOF
    graft src
    EOF

    cat >piscsi-web <<EOF
    #!/usr/bin/env python3
    import runpy
    import web
    __file__ = web.__file__
    runpy.run_module('web', run_name='__main__')
    EOF

    mkdir src/data
    mv genisoimage_hfs_resource_fork_map.txt src/data/
    mv src/drive_properties.json src/data/

    substituteInPlace src/web.py \
      --replace-fail "__PISCSI__" "${piscsi.outPath}" \
      --replace-fail "__MAC_HARD_DISK_DRIVERS__" "${drivers}"
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

  meta.mainProgram = "piscsi-web";
}
