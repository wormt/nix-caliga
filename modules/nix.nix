# nix and nix daemon with a writable /nix overlay
{
  config,
  lib,
  pkgs,
  nixpkgs,
  utils,
  ...
}:

let
  cfg = config.nix;

  formatValue =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isList v then
      lib.concatMapStringsSep " " toString v
    else
      toString v;

  lowerStoreUrl = "/run/nix-lower?read-only=true";
  localOverlayStoreUrl = "local-overlay://?upper-layer=/var/nix/store/upper&state=/var/nix/overlay-state&lower-store=${lib.strings.escapeURL lowerStoreUrl}";
  execStartStoreUrl = lib.replaceStrings [ "%" ] [ "%%" ] localOverlayStoreUrl;

  nixEnv = {
    NIX_DAEMON_SOCKET_PATH = "/nix/var/nix/daemon-socket/socket";
    NIX_LOG_DIR = "/var/nix/var/log/nix";
    NIX_STATE_DIR = "/var/nix/overlay-state";
  };
in
{
  options.nix = {
    enable = lib.mkEnableOption "Nix package manager and daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      description = "The Nix package to use.";
    };
    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      default = 32;
      description = "Number of Nix build users to create.";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        experimental-features = [
          "nix-command"
          "flakes"
          "local-overlay-store"
          "read-only-local-store"
        ];
        nix-path = "nixpkgs=${nixpkgs}";
        store = "daemon";
      };
      description = ''
        Settings written to /etc/nix/nix.conf. Defaults to enabling
        nix-command, flakes, local-overlay-store, and
        read-only-local-store, pointing nix-path at the nixpkgs source
        baked into the image from the flake input, and configuring the
        store as a local-overlay-store layered over the image-baked
        /nix
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.caliga.core.etc-usr.enable;
        message = "nix.enable requires caliga.core.etc-usr.enable = true";
      }
      {
        assertion = config.caliga.core.systemd.enable;
        message = "nix.enable requires caliga.core.systemd.enable = true";
      }
      {
        assertion = config.caliga.core.tmpfiles.enable;
        message = "nix.enable requires caliga.core.tmpfiles.enable = true";
      }
      {
        assertion = config.caliga.core.users.enable;
        message = "nix.enable requires caliga.core.users.enable = true";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # include the nix db from the layeredImage.contents so the nix daemon can see it
    layeredImage.includeNixDB = true;

    # Pick up nix-daemon.service, nix-daemon.socket, tmpfiles
    systemd.packages = [ cfg.package ];
    systemd.tmpfiles.packages = [ cfg.package ];

    systemd.sockets.nix-daemon = {
      wantedBy = [ "sockets.target" ];
      requires = [ "nix-directory-setup.service" ];
      after = ["nix-directory-setup.service"];
    };

    systemd.services.nix-daemon = {
      serviceConfig.ExecStart = [
        ""
        "@${cfg.package}/bin/nix-daemon nix-daemon --daemon --option store ${execStartStoreUrl}"
      ];
      requires = [ "nix-directory-setup.service" ];
      after = ["nix-directory-setup.service"];
    };

    environment.variables = nixEnv;
    systemd.globalEnvironment = nixEnv;

    systemd.mounts = [
      {
        where = "/run/nix-lower/nix";
        what = "/nix";
        options = "bind,ro";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        after = [ "ostree-remount.service" ];
        wants = [ "ostree-remount.service" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/nix";
        };
      }
      {
        where = "/nix/store";
        what = "overlay";
        type = "overlay";
        options = "lowerdir=/run/nix-lower/nix/store,upperdir=/var/nix/store/upper,workdir=/var/nix/store/work";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        after = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        requires = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
          ConditionPathIsReadWrite = "!/nix/store";
        };
      }
      {
        where = "/nix/var/nix";
        what = "tmpfs";
        type = "tmpfs";
        options = "mode=0755";
        wantedBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
        unitConfig = {
          DefaultDependencies = false;
          ConditionPathIsReadWrite = "!/nix/var/nix";
        };
      }
      {
        where = "/var/nix/overlay-state/gcroots/docker";
        what = "/run/nix-lower/nix/var/nix/gcroots/docker";
        options = "bind,ro";
        wantedBy = [ "local-fs.target" ];
        before = [
          "local-fs.target"
          "nix-daemon.socket"
        ];
        after = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        requires = [ "${utils.escapeSystemdPath "/run/nix-lower/nix"}.mount" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/nix/store/upper 0755 root root -"
      "d /var/nix/store/work 0755 root root -"
      "d /var/nix/overlay-state/gcroots 0755 root root -"
      "d /var/nix/overlay-state/db 0755 root root -"
      "d /var/nix/overlay-state/profiles 0755 root root -"
      "d /var/nix/overlay-state/temproots 0755 root root -"
      "d /var/nix/overlay-state/userpool 0755 root root -"
    ];

    systemd.services.nix-directory-setup = {
      after = [
        "${utils.escapeSystemdPath "/nix/var/nix"}.mount"
        "local-fs.target"
      ];
      before = [
        "nix-store.mount"
	    "nix-daemon.socket"
	    "nix-daemon.service"
	  ];
      wantedBy = [ "sockets.target" ];
      unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/var";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -dm 0755 /nix/var/nix/daemon-socket
      '';
    };

    users.groups.nixbld.gid = 30000;
    users.users = lib.listToAttrs (
      map (i: {
        name = "nixbld${toString i}";
        value = {
          isSystemUser = true;
          uid = 30000 + i;
          group = "nixbld";
          extraGroups = [ "nixbld" ];
          description = "Nix build user ${toString i}";
        };
      }) (lib.range 1 cfg.nrBuildUsers)
    );

    environment.etc."nix/nix.conf".text =
      lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${formatValue v}") cfg.settings)
      + "\n";
  };
}
