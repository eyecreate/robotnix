{ config, pkgs, lib, ... }:

with lib;
{
  options = {
    webview = mkOption {
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          enable = mkEnableOption "${name} webview";

          packageName = mkOption {
            type = types.str;
            default = "com.android.webview";
            description = "The Android package name of the APK.";
          };

          description = mkOption {
            type = types.str;
            default = "Android System WebView";
            description = "The name shown to the user in the developer settings menu.";
          };

          availableByDefault = mkOption {
            type = types.bool;
            default = false;
            description = ''
              If true, this provider can be automatically
              selected by the framework, if it's the first valid choice. If
              false, this provider will only be used if the user selects it
              themselves from the developer settings menu.
            '';
          };

          isFallback = mkOption {
            type = types.bool;
            default = false;
            description = ''
              If true, this provider will be automatically
              disabled by the framework, preventing it from being used or updated
              by app stores, unless there is no other valid provider available.
              Only one provider can be a fallback.
            '';
          };

          apk = mkOption {
            type = types.path;
          };
        };
      }));
    };
  };

  config = mkIf (any (m: m.enable) (attrValues config.webview)) {
    assertions = [
      { assertion = any (m: m.enable && m.availableByDefault) (attrValues config.webview);
        message = "Webview module is enabled, but no webview has availableByDefault = true";
      }
      { assertion = length (filter (m: m.enable && m.isFallback) (attrValues config.webview)) <= 1;
        message = "Multiple webview modules have isFallback = true";
      }
    ];

    apps.prebuilt = lib.mapAttrs' (name: m: nameValuePair "Webview${name}" {
      inherit (m) apk;

      # Extra stuff from the Android.mk from the example webview module in AOSP. Unsure if these are needed.
      extraConfig = ''
        LOCAL_MULTILIB := both
        LOCAL_REQUIRED_MODULES := \
          libwebviewchromium_loader \
          libwebviewchromium_plat_support
        LOCAL_MODULE_TARGET_ARCH := ${config.arch}
      '';
    }) (filterAttrs (name: m: m.enable) config.webview);

    product.extraConfig = "PRODUCT_PACKAGE_OVERLAYS += robotnix/webview-overlay";

    source.dirs."robotnix/webview-overlay".src = pkgs.writeTextFile {
      name = "config_webview_packages.xml";
      text =  ''
        <?xml version="1.0" encoding="utf-8"?>
        <webviewproviders>
      '' +
      (lib.concatMapStringsSep "\n"
        (m: lib.optionalString m.enable
          "<webviewprovider description=\"${m.description}\" packageName=\"${m.packageName}\" availableByDefault=\"${boolToString m.availableByDefault}\" isFallback=\"${boolToString m.isFallback}\"></webviewprovider>")
        (attrValues config.webview)
      ) +
      ''
        </webviewproviders>
      '';
      destination = "/frameworks/base/core/res/res/xml/config_webview_packages.xml";
    };
  };
}
