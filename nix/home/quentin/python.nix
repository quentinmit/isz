{ config, pkgs, lib, ... }:
{
  options = with lib; {
    isz.quentin.python.enable = mkOption {
      type = types.bool;
      default = config.isz.quentin.enable;
    };
  };
  config.home.packages = with pkgs; lib.mkIf config.isz.quentin.python.enable [
    #ihaskell
    iruby
    (let
      pyenv = python3.withPackages (ps: let
        definitions = {
          # python3 = {
          #   displayName = "Python 3";
          #   argv = [
          #     pyenv.interpreter
          #     "-m"
          #     "ipykernel_launcher"
          #     "-f"
          #     "{connection_file}"
          #   ];
          #   language = "python";
          #   logo32 = "${pyenv}/${pyenv.sitePackages}/ipykernel/resources/logo-32x32.png";
          #   logo64 = "${pyenv}/${pyenv.sitePackages}/ipykernel/resources/logo-64x64.png";
          # };
          c = {
            displayName = "C";
            argv = [
              "python"
              "-m"
              "jupyter_c_kernel"
              "-f"
              "{connection_file}"
            ];
            language = "c";
            codemirrorMode = "clike";
            logo32 = null;
            logo64 = null;
          };
          # TODO: Switch to https://github.com/janpfeifer/gonb
          # go = {
          #   displayName = "Go";
          #   argv = [
          #     "${gophernotes}/bin/gophernotes" # broken
          #     "{connection_file}"
          #   ];
          #   language = "go";
          #   logo32 = "${gophernotes.src}/kernel/logo-32x32.png";
          #   logo64 = "${gophernotes.src}/kernel/logo-64x64.png";
          # };
          #sage = sage.kernelspec;
          #octave = octave-kernel.definition;
#           pyscript = let
#             secrets = builtins.fromTOML (builtins.readFile ./hass-secrets.env);
#             env = python3.withPackages (ps: with ps; [ hass-pyscript-kernel ]);
#           in {
#             displayName = "hass pyscript";
#             language = "python";
#             argv = [
#               env.interpreter
#               "-m"
#               "hass_pyscript_kernel"
#               "-f"
#               "{connection_file}"
#             ];
#             logo32 = "${env}/lib/${env.libPrefix}/site-packages/hass_pyscript_kernel/kernel_files/logo-32x32.png";
#             logo64 = "${env}/lib/${env.libPrefix}/site-packages/hass_pyscript_kernel/kernel_files/logo-64x64.png";
#             extraPaths = {
#               "pyscript.conf" = pkgs.writeText "pyscript.conf" ''
#                 [homeassistant]
#                 hass_host = homeassistant.isz.wtf
#                 hass_url = https://homeassistant.isz.wtf
#                 hass_token = ${secrets.HASS_TOKEN}
#                 verify_ssl = True
#               '';
#             };
#           };
        };
        jupyterPath = jupyter-kernel.create { inherit definitions; };
        opa = oldAttrs: {
          makeWrapperArgs = (oldAttrs.makeWrapperArgs or []) ++ ["--set JUPYTER_PATH ${jupyterPath}"];
          doCheck = false;
        };
        ps2 = ps.override {
          overrides = self: super: lib.attrsets.genAttrs [
            "notebook"
            "jupyterlab"
            "jupyter_core"
            # Remaining is just to disable tests
            "jupyter-server"
            "ipywidgets"
            "nbconvert"
            "nbdime"
          ] (name: super.${name}.overridePythonAttrs opa);
        };
      in with ps2; [
        pillow
        aioesphomeapi
        aiohttp
        alabaster
        ansible
        ansible-core
        aocd
        #argparse-manpage
        #astroplan
        astropy
        atomicwrites
        awscli
        babel
        #insecure beaker
        beautifulsoup4
        bidict
        bitarray
        bokeh
        build
        cached-property
        cachetools
        cairosvg
        chardet
        cheetah3
        click
        clint
        colorama
        configargparse
        configobj
        configparser
        cryptography
        cssselect
        debugpy
        defusedxml
        deprecation
        dnspython
        docutils
        ecdsa
        epc
        ephem
        flake8
        pep8-naming
        fonttools
        funcsigs
        gitpython
        gmpy2
        gnupg
        gnureadline
        gspread
        pygobject3
        google-api-python-client
        google-auth
        google-auth-oauthlib
        graphviz
        h11
        h5py
        #hesiod
        httpx
        imageio
        imagesize
        importlib-metadata
        importmagic
        #removed ipaddress
        ipympl
        ipynbname
        ipython
        ipywidgets
        isodate
        jmespath
        ipykernel
        notebook
        jedi-language-server
        jsonlines
        jupyter-c-kernel
        jupyter-lsp
        jupyter-packaging
        jupyter-sphinx
        jupyter-server
        jupyterlab
        jupyterlab-git
        jupyterlab-lsp
        jupyterlab-widgets
        ihaskell
        iruby
        #broken gophernotes
        kaitaistruct
        keyring
        ldap3
        #unsupported leveldb
        #lib389
        #lightblue
        lxml
        mako
        markdown
        markupsafe
        matplotlib
        basemap
        matplotlib-inline
        more-itertools
        netaddr
        networkx
        nltk
        oauthlib
        pyopengl
        #opengl-accelerate
        openssl
        pyotp
        packaging
        pandas
        pdfrw
        phonenumbers
        pint
        pip
        pluggy
        plyvel
        psycopg2
        pulp
        py
        pybind11
        #pybonjour
        pycryptodome
        pydot
        pyelftools
        pygit2
        #unsupported pyglet
        pygments
        pykerberos
        pylint
        #pyobjc
        pypdf2
        pyperclip
        pytest
        pyusb
        pywinrm
        pyx
        re2
        reedsolo
        regex
        reportlab
        requests
        #requests-gssapi
        requests-oauthlib
        requests-toolbelt
        rfc3986
        roman
        rsa
        ruamel-yaml
        scapy
        scikit-image
        scipy
        selenium
        semver
        pyserial
        shapely
        snakeviz
        sniffio
        snowballstemmer
        sphinx
        sphinxcontrib-applehelp
        sphinxcontrib-devhelp
        sphinxcontrib-htmlhelp
        sphinxcontrib-jsmath
        sphinxcontrib-qthelp
        sphinxcontrib-serializinghtml
        sqlalchemy
        structlog
        #suds
        #broken suds-jurko
        sympy
        tables
        tabulate
        termcolor
        tifffile
        toml
        tomlkit
        tqdm
        twisted
        #unsupported on py310 uncompyle6
        unicodedata2
        unidecode
        #upnp-inspector
        websocket-client
        websockets
        wheel
        #broken build xdis
        xmldiff
        z3-solver
        zipp
        zopfli
      ] ++ lib.optionals config.isz.graphical [
        pyqt5
        pyqtgraph
      ] ++ lib.optionals config.isz.quentin.radio.enable [
        soapysdr-with-plugins
      ] ++ lib.optional mip.meta.available mip
      ); in pyenv)
  ];
}
