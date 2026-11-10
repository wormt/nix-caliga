{ ... }:
{
  modules = [
    {
      nix.enable = true;
      caliga.core.etc-usr.enable = true;
      caliga.core.systemd.enable = true;
      caliga.core.tmpfiles.enable = true;
      caliga.core.users.enable = true;
    }
  ];
  bats = {
    "nix_daemon - socket" = "systemctl is-active nix-daemon.socket";
    "nix_daemon - overlay" = ''
      [ "$(findmnt -no FSTYPE /nix)" = overlay ]
      [ -w /nix/store ]
    '';
    "nix_daemon - image store paths" = ''nix path-info --store daemon "$(command -v nix)"'';
    "nix_daemon - add to upper store" = ''
      echo hi > "$BATS_TEST_TMPDIR/f"
      grep -x hi "$(nix-store --store daemon --add "$BATS_TEST_TMPDIR/f")"
    '';
  };
}
