{ config, lib, pkgs, ... }:

let
  cfg = config.kiosk;

  builtinQtileConfig = ./qtileconf.py;
  effectiveQtileConfig = if cfg.qtileConfig == null
    then builtinQtileConfig
    else cfg.qtileConfig;

  scripts = import ./scripts.nix {
    inherit pkgs lib;
    command = cfg.command;
    qtileConfigPath = effectiveQtileConfig;
    rotate = cfg.rotate;
  };
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

    rotate = lib.mkOption {
      type = lib.types.enum [ 0 90 180 270 ];
      default = 0;
      description = "Screen rotation in degrees";
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
          command = lib.getExe scripts.launcher;
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
