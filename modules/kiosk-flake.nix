{ config, lib, inputs, uinstall, disko, ... }:

let
  mkKiosk = name: kcfg:
    let
      effectiveCommand = if lib.isDerivation kcfg.command
        then "${lib.getExe kcfg.command}"
        else kcfg.command;
    in
    {
      packages = { pkgs, ... }:
      let
        builtinQtileConfig = ./qtileconf.py;
        effectiveQtileConfig = if kcfg.qtileConfig == null
          then builtinQtileConfig
          else kcfg.qtileConfig;

        scripts = import ./scripts.nix {
          inherit pkgs lib;
          command = effectiveCommand;
          qtileConfigPath = effectiveQtileConfig;
          rotate = kcfg.rotate;
        };
      in
      {
        "kiosk-${name}" = scripts.launcher;
      };

      nixosConfig = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules =
          lib.optionals kcfg.includeInstaller [
            disko.nixosModules.default
            uinstall.nixosModules.simpleDisko
          ]
          ++ lib.optionals (kcfg.extraModule != null) [ kcfg.extraModule ]
          ++ [
            ./kiosk.nix
            ({ pkgs, ... }: {
              kiosk = {
                enable = true;
                command = effectiveCommand;
                user = kcfg.user;
                qtileConfig = kcfg.qtileConfig;
                rotate = kcfg.rotate;
              };

              services.openssh = {
                enable = kcfg.sshKeys != [];
                settings = {
                  permitRootLogin = if kcfg.sshKeys != [] then "prohibit-password" else false;
                };
              };

              users.users.root = {
                password = kcfg.rootPassword;
                openssh.authorizedKeys.keys = kcfg.sshKeys;
              };
              users.users.${kcfg.user}.openssh.authorizedKeys.keys = kcfg.sshKeys;

              environment.systemPackages = with pkgs; [
                iw wirelesstools psmisc
              ];

              networking.networkmanager = lib.mkIf (kcfg.wifiNetworks != {}) {
                enable = true;
                ensureProfiles.profiles = lib.mapAttrs (ssid: psk: {
                  connection = {
                    id = ssid;
                    type = "wifi";
                  };
                  ipv4.method = "auto";
                  ipv6 = {
                    addr-gen-mode = "stable-privacy";
                    method = "auto";
                  };
                  wifi = {
                    mode = "infrastructure";
                    ssid = ssid;
                  };
                  wifi-security = {
                    auth-alg = "open";
                    key-mgmt = "wpa-psk";
                    psk = psk;
                  };
                }) kcfg.wifiNetworks;
              };
            })
          ];
      };
    };
in
{
  imports = [ uinstall.flakeModules.default ];

  options.kiosk = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        command = lib.mkOption {
          type = lib.types.either lib.types.package lib.types.str;
          description = "Application to run inside qtile (package or shell command string)";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "kiosk";
          description = "Auto-login user";
        };

        rootPassword = lib.mkOption {
          type = lib.types.str;
          default = "kiosk";
          description = "Root password for the NixOS VM";
        };

        wifiNetworks = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "WiFi networks: SSID -> PSK";
        };

        qtileConfig = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Custom qtile config; uses builtin if null";
        };

        includeInstaller = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Include disko + uinstall modules for unattended NixOS installation";
        };

        rotate = lib.mkOption {
          type = lib.types.enum [ 0 90 180 270 ];
          default = 0;
          description = "Screen rotation in degrees";
        };

        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "SSH public keys for root and kiosk user";
        };

        extraModule = lib.mkOption {
          type = with lib.types; unspecified;
          default = null;
          description = "Optional NixOS module (path or inline) to add to the system configuration";
        };
      };
    }));
    default = {};
  };

  config = {
    perSystem = { pkgs, ... }:
    let
      all = lib.mapAttrs (name: kcfg: mkKiosk name kcfg) config.kiosk;
      packages = lib.mapAttrs' (name: k: lib.nameValuePair "kiosk-${name}" (k.packages { inherit pkgs; })) all;
      # Flatten nested attrset: {"scroller": {"kiosk-scroller": <drv>}} -> {"kiosk-scroller": <drv>}
    in
    {
      packages = lib.foldl' (a: b: a // b) {} (lib.attrValues packages);
    };

    flake.nixosConfigurations =
      lib.mapAttrs (name: kcfg: (mkKiosk name kcfg).nixosConfig) config.kiosk;
  };
}
