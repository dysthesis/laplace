{
  lib,
  pkgs,
}: let
  kdl = import ../../user/wrapped/niri/config/kdl.nix {inherit lib;};
  transforms = import ../../user/wrapped/niri/config/transforms.nix {inherit lib;};
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  valid = {
    binds = [{combo = "Mod+A";}];
    outputs = [{name = "eDP-1";}];
  };
  tree = [
    ((kdl.block {
        name = "parent";
        body = {
          flag = true;
          omitted = false;
          missing = null;
          nested.body.leaf = "value";
          repeat = [1 2];
          value = "body";
        };
        children = [(kdl.statement {name = "tail";})];
      })
      // {value = "extra";})
    (kdl.block {name = "empty";})
  ];
  rendered = integrated:
    import ../../user/wrapped/niri/config {
      inherit lib pkgs;
      config.laplace = {
        display.wayland.desktop.enable = integrated;
        hardware.monitors = [
          {
            name = "eDP-1";
            width = 2256;
            height = 1504;
            refreshRate = 60.0;
            scale = 1;
            primary = true;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
      };
    };
in
  assert kdl.render tree
  == ''
    parent {
      flag
      nested {
        leaf "value"
      }
      repeat 1
      repeat 2
      value "extra"
      tail
    }
    empty
  '';
  assert kdl.render [
    (kdl.statement {
      name = "escaped";
      args = ["quote\" slash\\ line\nreturn\rtab\t"];
      assign.active = true;
    })
  ]
  == "escaped \"quote\\\" slash\\\\ line\\nreturn\\rtab\\t\" active=true\n";
  assert rejects (kdl.render [
    {
      name = "inline";
      inline = true;
      children = [{name = "child";}];
    }
  ]);
  assert transforms.validateModel valid == valid;
  assert rejects (transforms.validateModel (valid // {binds = valid.binds ++ valid.binds;}));
  assert rejects (transforms.validateModel (valid // {outputs = valid.outputs ++ valid.outputs;}));
    pkgs.runCommand "niri-config-check" {} ''
      NIRI_CONFIG=${rendered false} ${lib.getExe pkgs.niri} validate
      NIRI_CONFIG=${rendered true} ${lib.getExe pkgs.niri} validate
      touch $out
    ''
