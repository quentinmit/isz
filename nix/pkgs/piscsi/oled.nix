{
  piscsi,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "piscsi-oled";
  inherit (piscsi) src version;
  sourceRoot = "source/python/oled";

  # Upstream doesn't ship a proper pyproject.toml.
  format = "pyproject";
  postPatch = ''
    cat >>pyproject.toml <<EOF

    [project]
    name = "piscsi-oled"
    version = "${piscsi.version}"
    dependencies = [
      "Adafruit-Blinka",
      "adafruit-circuitpython-busdevice",
      "adafruit-circuitpython-framebuf",
      "adafruit-circuitpython-requests",
      "adafruit-circuitpython-ssd1306",
      "adafruit-circuitpython-typing",
      "Adafruit-PlatformDetect",
      "Adafruit-PureIO",
      "Pillow",
      "protobuf",
      "pyftdi",
      "pyserial",
      "pyusb",
      "typing_extensions",
      "Unidecode",
    ]
    [tool.setuptools]
    script-files = ["src/piscsi_oled_monitor.py"]
    EOF

    sed -i '1i#!/usr/bin/env python3' src/piscsi_oled_monitor.py
  '';

  build-system = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    pillow
    protobuf
    pyftdi
    pyserial
    pyusb
    typing-extensions
    unidecode
  ];

  meta.mainProgram = "piscsi_oled_monitor.py";
}
