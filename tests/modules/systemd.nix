{ ... }:
{
  modules = [
    {
      caliga.core.systemd.enable = true;

      systemd.services.caliga-test = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "touch /run/caliga-test";
      };
    }
  ];
  bats = {
    "systemd - service ran" = ''
      systemctl is-active caliga-test
      [ -e /run/caliga-test ]
    '';
  };
}
