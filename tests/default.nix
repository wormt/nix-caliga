# runner: legacyPackages.x86_64-linux.<image>.<name> (nix run .#<image>.<name>)
# base images: ./images.nix
{ pkgs, self }:
let
  lib = pkgs.lib;
  images = import ./lib/images.nix { inherit pkgs lib self; };
  runner = import ./lib/runner.nix { inherit pkgs lib; };

  # tests/modules/<name>.nix: { modules, bats, tests }
  # tests are the names of other tests to merge in
  testConfig = lib.mapAttrs' (
    file: _:
    lib.nameValuePair (lib.removeSuffix ".nix" file) (
      {
        modules = [ ];
        bats = { };
        tests = [ ];
      }
      # make lib available
      // import (./modules + "/${file}") { inherit lib; }
    )
  ) (builtins.readDir ./modules);

  mergeTests =
    t:
    let
      included = map (name: mergeTests testConfig.${name}) t.tests;
    in
    {
      modules = t.modules ++ lib.concatMap (test: test.modules) included;
      bats = lib.foldl' (merged: test: merged // test.bats) { } included // t.bats;
    };

  mkBats =
    name: bats:
    pkgs.writeText "${name}.bats" (
      "#!/usr/bin/env bats\n"
      + lib.concatStrings (
        lib.mapAttrsToList (test: body: ''

          @test "${lib.escape [ "\"" ] test}" {
          ${body}
          }
        '') bats
      )
    );

  tests = lib.mapAttrs (_: mergeTests) testConfig;
in
{
  legacyPackages = lib.mapAttrs (
    image: imageModule:
    lib.mapAttrs (
      test: t:
      runner.mkRunner {
        name = "${image}-${test}";
        image = images.mkImage {
          name = "${image}-${test}";
          modules = [ imageModule ] ++ t.modules;
        };
        bats = mkBats test t.bats;
      }
    ) tests
  ) (import ./images.nix);
}
