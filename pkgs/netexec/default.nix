{
  nixpkgs-inputs ? { },
  pkgs ? import <nixpkgs> nixpkgs-inputs,
}:

let
  python = pkgs.python313.override {
    self = python;
    packageOverrides = self: super: {
      impacket = import ../netexec-impacket { inherit pkgs; };
      # certipy-ad pins impacket~=0.13.0, but the netexec impacket fork
      # reports 0.14.0; relax the constraint so the runtime deps check passes.
      certipy-ad = super.certipy-ad.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "impacket" ];
      });
      bloodhound-ce = import ../bloodhound-ce {
        inherit pkgs;
        impacket = self.impacket;
      };
    };
  };
in
python.pkgs.buildPythonApplication {
  pname = "netexec";
  version = "1.5.1-dev";
  pyproject = true;

  src = pkgs.fetchFromGitHub {
    owner = "Pennyw0rth";
    repo = "NetExec";
    rev = "1f9ecc8f77a185125bfb48290d296c9097e57ba0";
    hash = "sha256-U+1BC7CEWZ3vzJaC7iXaFGJgEb7nH7L63PL6Lsv8rAg=";
  };

  pythonRelaxDeps = true;

  pythonRemoveDeps = [
    # Fail to detect dev version requirement
    "neo4j"
  ];

  postPatch = ''
    substituteInPlace nxc/first_run.py \
      --replace-fail "from os import mkdir" "from os import mkdir, chmod" \
      --replace-fail "shutil.copy(default_path, NXC_PATH)" $'shutil.copy(default_path, CONFIG_PATH)\n        chmod(CONFIG_PATH, 0o600)'

    substituteInPlace pyproject.toml \
      --replace-fail " @ git+https://github.com/Pennyw0rth/Certipy" "" \
      --replace-fail " @ git+https://github.com/wbond/oscrypto" "" \
      --replace-fail " @ git+https://github.com/Pennyw0rth/NfsClient" ""
  '';

  build-system = with python.pkgs; [
    poetry-core
    poetry-dynamic-versioning
  ];

  dependencies = with python.pkgs; [
    jwt
    aardwolf
    aioconsole
    aiosqlite
    argcomplete
    asyauth
    beautifulsoup4
    bloodhound-ce
    certipy-ad
    certihound
    dploot
    dsinternals
    impacket
    lsassy
    masky
    minikerberos
    msgpack
    msldap
    neo4j
    paramiko
    pefile
    pyasn1-modules
    pylnk3
    pynfsclient
    pypsrp
    pypykatz
    python-dateutil
    python-libnmap
    pywerview
    requests
    rich
    sqlalchemy
    termcolor
    terminaltables
    terminaltables3
    xmltodict
  ];

  # Upstream tests at this commit are out of sync with the implementation:
  # test_smb_signing.py calls smb._is_signing_required(..., smbv1=...) but the
  # pinned source revision does not accept that keyword argument.
  disabledTestPaths = [ "tests/test_smb_signing.py" ];

  nativeCheckInputs = with python.pkgs; [ pytestCheckHook ] ++ [ pkgs.writableTmpDirAsHomeHook ];
}
