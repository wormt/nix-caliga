{ ... }:
{
  modules = [
    {
      caliga.core.users.enable = true;
      caliga.core.systemd.enable = true;
      caliga.core.etc-usr.enable = true;

      users.groups.caliga-group = { };
      users.users.caliga-test = {
        isNormalUser = true;
        uid = 1500;
        extraGroups = [ "caliga-group" ];
      };
    }
  ];
  bats = {
    "users - uid" = ''[ "$(id -u caliga-test)" = 1500 ]'';
    "users - group" = "id -nG caliga-test | grep -w caliga-group";
    "users - home dir" = "[ -d ~caliga-test ]";
  };
}
