# base images for running tests on at legacyPackages.x86_64-linux.<image>.<test> (nix run .#<image>.<test>)
{
  fedora-bootc =
    { pkgs, ... }:
    {
      layeredImage.fromImage = pkgs.dockerTools.pullImage {
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:15fad9bc79d341f63d51af6d901749c0b0878148aeb1227267a473b05cbc1c2e";
        hash = "sha256-/SDGIr38iZzxvFEyANDQZS25TOr1rQhBcHLrBcxUhlc=";
        finalImageName = "quay.io/fedora/fedora-bootc";
        finalImageTag = "44";
      };

      caliga.os = "fedora";
      environment.systemPackages = [ pkgs.bats ];
      system.stateVersion = "25.11";
    };

  # dakota isn't working for me in bcvk right now, I'll check it later, just here as an example
  bluefin-dakota =
    { pkgs, ... }:
    {
      layeredImage.maxLayers = 130;
      layeredImage.fromImage = pkgs.dockerTools.pullImage {
        imageName = "ghcr.io/projectbluefin/dakota";
        imageDigest = "sha256:c10a8b189c34e53cf213f4b03342ac89c322b7e6a4eb0eb19012c6a59d7e4378";
        hash = "sha256-MaSC5rOfuzPTtrfdsCcc+dVVdFCQk5+ZcyI9pNWjJfA=";
        finalImageName = "ghcr.io/projectbluefin/dakota";
        finalImageTag = "stable";
      };

      caliga.os = "gnomeOS";
      environment.systemPackages = [ pkgs.bats ];
      system.stateVersion = "25.11";
    };
}
