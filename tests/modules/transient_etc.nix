{ ... }:
{
  modules = [
    {
      bootc.ostree-prepare-root.transientEtc = true;
      caliga.core.containerfile.enable = true;
      caliga.core.systemd.enable = true;
      caliga.core.etc-usr.enable = true;
    }
  ];
  bats = {
    "transient_etc - conf" = "grep -x 'transient = true' /usr/lib/ostree/prepare-root.conf";
    "transient_etc - etc is an overlay" = ''[ "$(findmnt -no FSTYPE /etc)" = overlay ]'';
  };
}
