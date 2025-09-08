{ pkgs, inputs, ... }:

{
  home.packages = [(
    import ./shellnixcreator.nix {
      inherit pkgs;
      inherit inputs;
      scriptName = "mkpythonenv";
      mkShellCmd = ''
        pkgs.mkShellNoCC {
          packages = (with pkgs; [
            python312
          ]) ++ (with pkgs.python312Packages; [
          ]);
        }
      '';
    }
  )];
}
