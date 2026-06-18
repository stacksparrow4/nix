{
  pkgs ? import <nixpkgs> { },
}:

pkgs.python3Packages.buildPythonApplication {
  pname = "sandbox";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = with pkgs.python3Packages; [ setuptools ];

  pythonImportsCheck = [ "sandbox" ];
}
