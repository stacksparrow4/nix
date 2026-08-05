{ self', ... }:

{
  home.packages = [
    self'.packages.windows-yaml
    self'.packages.mkpythonenv
    self'.packages.mkwindowsenv
  ];
}
