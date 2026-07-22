{ config, lib, inputs, uinstall, disko, ... }:

let
  cfg = config.kiosk;
  effectiveCommand = if lib.isDerivation cfg.command
    then "${lib.getExe cfg.command}"
    else cfg.command;
in
{
  imports = [ uinstall.flakeModules.default ];

  options.kiosk = {
    enable = lib.mkEnableOption "kiosk mode with greetd + qtile + bwrap sandbox";

    command = lib.mkOption {
      type = lib.types.either lib.types.package lib.types.str;
      description = "Application to run inside qtile (package or shell command string)";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = "NixOS hostname";
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
      default = false;
      description = "Include disko + uinstall modules for unattended NixOS installation";
    };
  };

  config = lib.mkIf cfg.enable {

    perSystem = { pkgs, ... }:
    let
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
        exec ${unshareScript} ${effectiveCommand}
      '';

      appRestarting = pkgs.writeShellScript "app-restarter" ''
        while true; do
            ${appWrapped}
            sleep 1
        done
      '';
    in
    {
      packages.default = pkgs.writeShellScriptBin "kiosk" ''
        CMD=${appRestarting} exec ${unshareScript} ${qtile} start -c ${effectiveQtileConfig} -b wayland "$@"
      '';
    };

    flake.nixosConfigurations."${cfg.hostName}" = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        lib.optionals cfg.includeInstaller [
          disko.nixosModules.default
          uinstall.nixosModules.simpleDisko
        ]
        ++ [
          ./kiosk.nix
          ({ pkgs, ... }: {
            kiosk = {
              enable = true;
              command = effectiveCommand;
              user = cfg.user;
              qtileConfig = cfg.qtileConfig;
            };

            services.openssh.settings.permitRootLogin = false;
            users.users.root.password = cfg.rootPassword;

            environment.systemPackages = with pkgs; [
              iw wirelesstools psmisc
            ];

            networking.networkmanager = lib.mkIf (cfg.wifiNetworks != {}) {
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
              }) cfg.wifiNetworks;
            };
          })
        ];
    };
  };
}
