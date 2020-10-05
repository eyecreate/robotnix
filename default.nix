{ configuration,
  pkgs ? (import ./pkgs {}),
  lib ? pkgs.stdenv.lib
}:

with lib;
let
  eval = (evalModules {
    modules = [
      ({ config, ... }: {
        options.nixpkgs.overlays = mkOption {
          default = [];
          type = types.listOf types.unspecified;
        };

        config = {
          _module.args = let
            finalPkgs = pkgs.appendOverlays config.nixpkgs.overlays;
            apks = import ./apks { pkgs = finalPkgs; };
            robotnixlib = import ./lib lib;
          in {
            inherit apks lib robotnixlib;
            pkgs = finalPkgs;
          };
        };
      })
      configuration
      ./flavors/grapheneos
      ./flavors/lineageos
      ./flavors/vanilla
      ./modules/10
      ./modules/11
      ./modules/9
      ./modules/apps/auditor.nix
      ./modules/apps/chromium.nix
      ./modules/apps/fdroid.nix
      ./modules/apps/prebuilt.nix
      ./modules/apps/seedvault.nix
      ./modules/apps/updater.nix
      ./modules/apv.nix
      ./modules/assertions.nix
      ./modules/base.nix
      ./modules/emulator.nix
      ./modules/emulator.nix
      ./modules/envpackages.nix
      ./modules/etc.nix
      ./modules/framework.nix
      ./modules/google.nix
      ./modules/hosts.nix
      ./modules/kernel.nix
      ./modules/microg.nix
      ./modules/pixel
      ./modules/release.nix
      ./modules/resources.nix
      ./modules/signing.nix
      ./modules/source.nix
      ./modules/webview.nix
    ];
  });

  # From nixpkgs/nixos/modules/system/activation/top-level.nix
  failedAssertions = map (x: x.message) (lib.filter (x: !x.assertion) eval.config.assertions);

  config = if failedAssertions != []
    then throw "\nFailed assertions:\n${lib.concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}"
    else lib.showWarnings eval.config.warnings eval.config;

in config
