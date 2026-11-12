{ config, lib, pkgs, deploy-rs, ... }:
{
  options = {
    isz.quentin.vscode.install = lib.mkOption {
      type = lib.types.bool;
      default = config.isz.quentin.enable && config.isz.graphical;
    };
  };
  config = let
    available = pkg: lib.optional pkg.meta.available pkg;
    vscodeExtensions = with pkgs.vscode-extensions; [
      mkhl.direnv
      jnoortheen.nix-ide
      golang.go
      ms-python.python
      rust-lang.rust-analyzer
      ms-toolsai.jupyter
      ms-vscode.cpptools-extension-pack
      LoyieKing.smalise
      ms-playwright.playwright
      github.vscode-github-actions
      savonet.vscode-liquidsoap
      ms-vscode.cmake-tools
      ms-vscode.makefile-tools
      ms-vsliveshare.vsliveshare
      eclipse-cdt.peripheral-inspector
      eclipse-cdt.cdt-gdb-vscode
      ms-vscode.mock-debug
      cperezabo.routeros-syntax
      #marus25.cortex-debug
      #mcu-debug.debug-tracker-vscode
      #mcu-debug.memory-view
    ] ++ available pkgs.unstable.vscode-extensions.Surendrajat.apklab;
    userSettings = {
      "antigravity.enableTelemetry" = false;
      "apklab.apkSignerPath" = pkgs.fetchurl {
        url = "https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar";
        hash = "sha256-4Smf1vz02lJ91Tc1tWEn6OqSKjIRKBI7nDLWGbuh2DU=";
        meta.license = lib.licenses.asl20;
      };
      "apklab.jadxDirPath" = pkgs.jadx;
      "apklab.apktoolPath" = "${pkgs.apktool}/libexec/apktool/apktool.jar";
      "debug.javascript.autoAttachFilter" = "smart";
      "editor.autoClosingBrackets" = "beforeWhitespace";
      "editor.foldingMaximumRegions" = 50000;
      "editor.formatOnSave" = false;
      "editor.renderWhitespace" = "all";
      "go.useLanguageServer" = true;
      "jupyter.alwaysTrustNotebooks" = true;
      "jupyter.disableJupyterAutoStart" = true;
      #"jupyter.insidersChannel" = "weekly";
      "jupyter.jupyterServerType" = "remote";
      #"liveshare.allowGuestDebugControl" = true;
      #"liveshare.allowGuestTaskControl" = true;
      #"liveshare.languages.allowGuestCommandControl" = true;
      #"liveshare.notebooks.allowGuestExecuteCells" = true;
      "nix.enableLanguageServer" = true;
      "nix.formatterPath" = "";
      "nix.serverPath" = lib.getExe pkgs.nil;
      "nix.serverSettings".nil = {
        # https://github.com/oxalica/nil/blob/main/docs/configuration.md
        formatting.command = [(lib.getExe pkgs.nixfmt)];
      };
      #"python.insidersChannel" = "weekly";
      "telemetry.enableTelemetry" = false;
      "terminal.integrated.macOptionIsMeta" = true;
      "typescript.preferences.importModuleSpecifier" = "relative";
      "workbench.editorAssociations" = {
        "*.ipynb" = "jupyter-notebook";
      };
    };
    keybindings = [
      {
        # M-backspace sends ^W by default (?!)
        key = "alt+backspace";
        command = "-workbench.action.terminal.sendSequence";
        when = "terminalFocus";
      }
    ];
  in lib.mkIf (config.isz.quentin.enable && config.isz.graphical) {
    programs.vscode.package = with pkgs; if config.isz.quentin.vscode.install then
      (vscode-with-extensions.override {
        vscodeExtensions = vscodeExtensions
          ++ (with unstable.vscode-extensions; [
            Google.google-antigravity
          ]);
      })
      else null;
    programs.vscode.enable = true;
    programs.vscode.profiles.default = {
      userSettings = userSettings // {
        "python.languageServer" = "Pylance";
      };
      inherit keybindings;
    };
    programs.antigravity-ide = {
      enable = true;
      package = if config.isz.quentin.vscode.install then
        (pkgs.unstable.vscode-with-extensions.override {
          vscode = pkgs.unstable.antigravity-ide;
          inherit vscodeExtensions;
        })
        else null;
      profiles.default = {
        inherit
          userSettings
          keybindings;
      };
    };
  };
}
