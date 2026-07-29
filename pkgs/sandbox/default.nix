{
  pkgs ? import <nixpkgs> { },
}:

pkgs.python3Packages.buildPythonApplication {
  pname = "sandbox";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = with pkgs.python3Packages; [ setuptools ];

  # Baked in as absolute store paths rather than prefixed onto PATH, so that
  # sandboxes don't inherit these tools in their own PATH.
  #
  # qemu is deliberately absent and looked up on PATH at runtime: substituting it
  # would put its ~1GB closure into this package's closure, and this package is
  # installed inside the sandbox VM image itself.
  postPatch = ''
    substituteInPlace sandbox/main.py \
      --subst-var-by socat ${pkgs.lib.getExe pkgs.socat} \
      --subst-var-by ssh ${pkgs.lib.getExe' pkgs.openssh "ssh"} \
      --subst-var-by sshKeygen ${pkgs.lib.getExe' pkgs.openssh "ssh-keygen"}
  '';

  pythonImportsCheck = [ "sandbox" ];
}
