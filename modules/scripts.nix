{ pkgs, lib, command, qtileConfigPath, rotate }:

let
  qtile = lib.getExe pkgs.python3Packages.qtile;
  bwrap = lib.getExe pkgs.bubblewrap;
  wlrRandR = lib.getExe pkgs.wlr-randr;
  jq = lib.getExe pkgs.jq;

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
    exec ${unshareScript} ${command}
  '';

  appRestarting = pkgs.writeShellScript "app-restarter" ''
    while true; do
        ${appWrapped}
        sleep 1
    done
  '';

  rotateAndRun = pkgs.writeShellScript "roteae-and-run" (
    (if rotate == 0 then "" else ''
        OUTPUT=$(${wlrRandR} --json | ${jq} -r '.[0].name')
        ${wlrRandR} --output "$OUTPUT" --transform ${toString rotate}
    '') +
    # Прячет курсор мыши
    ''
    ${pkgs.unclutter-xfixes}/bin/unclutter --timeout 1 &
    exec ${appRestarting}
    '');

in
{
  launcher = pkgs.writeShellScriptBin "kiosk-launcher" ''
    CMD=${rotateAndRun} ROTATE=${toString rotate} exec ${unshareScript} ${qtile} start -c ${qtileConfigPath} -b wayland "$@"
  '';
}
