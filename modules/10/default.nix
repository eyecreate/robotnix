{ config, pkgs, lib, ... }:

with lib;
let
  # Some mostly-unique data used as input for filesystem UUIDs, hash_seeds, and AVB salt.
  # TODO: Maybe include all source hashes except from build/make to avoid infinite recursion?
  hash = builtins.hashString "sha256" "${config.buildNumber} ${builtins.toString config.buildDateTime}";
in
mkIf (config.androidVersion >= 10) {
  source.dirs."build/make" = {
    patches = [
      ./build_make/0001-Readonly-source-fix.patch
      (pkgs.substituteAll {
        src = ./build_make/0002-Partition-size-fix.patch;
        inherit (pkgs) coreutils;
      })
      ./build_make/0003-Make-vendor_manifest.xml-reproducible.patch
      (pkgs.substituteAll {
        src = ./build_make/0004-Set-uuid-and-hash_seed-for-userdata-and-cache.patch;
        inherit hash;
      })
      ./build_make/0005-Add-marker-to-insert-AVB-salt-flags.patch
    ];

    postPatch = let
      # Make salt based on combination of partition name and hash. Needed for reproducibility.
      salt = partition: builtins.hashString "sha256" "${partition} ${hash}";
      avbSaltFlags = pkgs.writeText "avb_salt_flags" ''
        BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += --salt ${salt "boot"}
        BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS += --salt ${salt "dtbo"}
        BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "system"}
        BOARD_AVB_SYSTEM_OTHER_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "system_other"}
        BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "vendor"}
        BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS += --salt ${salt "recovery"}
        BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "product"}
        BOARD_AVB_PRODUCT_SERVICES_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "product_services"}
        BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS += --salt ${salt "odm"}
      '';
    in ''
      sed -i -e '/### AVB SALT MARKER ###/r ${avbSaltFlags}' core/Makefile
    '';
  };

  # This one script needs python2. Used by sdk builds
  source.dirs."development".postPatch = ''
    substituteInPlace build/tools/mk_sources_zip.py \
      --replace "#!/usr/bin/python" "#!${pkgs.python2.interpreter}"
  '';

  apex.enable = mkDefault true;

  kernel.clangVersion = mkDefault "r349610";
}
