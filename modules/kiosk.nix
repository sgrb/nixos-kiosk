{ config, lib, pkgs, ... }:

let
  cfg = config.kiosk;

  qtile = lib.getExe pkgs.python3Packages.qtile;
  bwrap = lib.getExe pkgs.bubblewrap;

  builtinQtileConfig = ./qtileconf.py;

  effectiveQtileConfig = if cfg.qtileConfig == null
    then builtinQtileConfig
    else cfg.qtileConfig;

  unshareScript = pkgs.writeShellScript "bwrap-sandbox" ''
    if [ $$ -ne 1 ]; then
        sandbox=$(mktemp -d)
        mkdir "$sandbox"/{tmp,home}
        ${bwrap} --unshare-user --unshare-pid --die-with-parent --as-pid-1 \
             --proc /proc \
             --dev-bind /dev /dev \
             --bind /etc /etc \
             --bind /nix /nix \
             --bind /run /run \
             --bind /sys /sys \
             --bind "$sandbox"/tmp /tmp \
             --bind "$sandbox"/home "$HOME" \
             --bind-try /tmp/.X11-unix/X"$DISPLAY"{,} \
             --bind-try "''${XAUTHORITY:-/nothing}"{,} \
             -- "$0" "$@"
        ret=$?
        rm -rf "$sandbox"
        exit $ret
    fi
    exec "$@"
  '';

  appWrapped = pkgs.writeShellScript "app-wrapped" ''
    exec ${unshareScript} ${cfg.command}
  '';

  appRestarting = pkgs.writeShellScript "app-restarter" ''
    while true; do
        ${appWrapped}
        sleep 1
    done
  '';

  launcher = pkgs.writeShellScriptBin "kiosk-launcher" ''
    CMD=${appRestarting} exec ${unshareScript} ${qtile} start -c ${effectiveQtileConfig} -b wayland "$@"
  '';
in
{
  options.kiosk = {
    enable = lib.mkEnableOption "kiosk mode with greetd + qtile + bwrap sandbox";

    user = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = "User for auto-login and app execution";
    };

    command = lib.mkOption {
      type = lib.types.str;
      description = "Shell command to run inside qtile (passed through /bin/sh)";
    };

    qtileConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Custom qtile config; uses builtin Stack-based config if null";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = "users";
      extraGroups = [ "video" ];
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = lib.getExe launcher;
          user = cfg.user;
        };
        restart = true;
      };
    };

    services.dbus.enable = true;
    security.polkit.enable = true;

    hardware = {
      enableRedistributableFirmware = true;
      firmware = [ pkgs.linux-firmware ];
      wirelessRegulatoryDatabase = true;
    };
  };
}
