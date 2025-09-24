{ ... }@inputs:

let
  # Bind to a specific revision of nixpkgs because these tools break often
  pkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/8a6d5427d99ec71c64f0b93d45778c889005d9c2.tar.gz";
    sha256 = "sha256-cr748nSmpfvnhqSXPiCfUPxRz2FJnvf/RjJGvFfaCsM=";
  }) {
    system = inputs.pkgs.system;
  };
  buildWindowsGccWrapper = winGcc:
  let
    winGccShellEnv = pkgs.stdenv.mkDerivation {
      name = "win-gcc-shell-env";
      buildInputs = [winGcc];

      phases = [ "buildPhase" ];

      buildPhase = ''
        export >> "$out"
      '';
    };
  in
    pkgs.runCommand "mingw-env-gcc" {} ''
      mkdir -p "$out/bin"

      for binfile in $(cd ${winGcc.out}/bin; echo *); do
        cat > "$out/bin/$binfile" <<EOF
      #!${pkgs.stdenv.shell}

      source ${winGccShellEnv}
      
      $binfile "\$@"
      EOF
        chmod +x "$out/bin/$binfile"
      done
    '';
  fixedImpacket = let
    impacketEnv = pkgs.stdenv.mkDerivation {
      name = "win-impacket-env";
      buildInputs = with pkgs.python312Packages; [
        impacket
        pycryptodome
      ];
      phases = [ "buildPhase" ];
      buildPhase = ''
        export >> "$out"
      '';
    };
  in
    pkgs.runCommand "fixed-impacket" {} ''
      mkdir -p "$out/bin"

      for binfile in $(cd ${pkgs.python312Packages.impacket}/bin; echo *); do
        cat > "$out/bin/$binfile" << EOF
      #!${pkgs.stdenv.shell}

      source ${impacketEnv}

      $binfile "\$@"
      EOF
        chmod +x "$out/bin/$binfile"
      done
    '';
in
(with pkgs; [
  rlwrap
  fixedImpacket
  evil-winrm
  samba # rpcclient

  (buildGoModule {
    pname = "kerbrute";
    version = "1.0.3";

    src = fetchFromGitHub {
      owner = "ropnop";
      repo = "kerbrute";
      tag = "v1.0.3";
      hash = "sha256-HC7iCu16iGS9/bEXfvRLG9cXns6E+jZvqbIaN9liFB4=";
    };

    vendorHash = "sha256-8/3NyKz0rLo3Js6iwzDUki6K/BrljLkl4K9tNgK59XA=";
  })

  (rustPlatform.buildRustPackage (finalAttrs: {
    name = "rusthound-ce";

    nativeBuildInputs = [
      krb5
      pkg-config
    ];

    buildInputs = with pkgs; [
      libkrb5
      pkg-config
    ];

    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.glibc.dev}/include -I${pkgs.clang}/resource-root/include";

    src = fetchFromGitHub {
      owner = "g0h4n";
      repo = "RustHound-CE";
      rev = "44b461390a095da23fc33fc1a6af5497ddf0cbc0";
      hash = "sha256-5oSmChOq5Lk8IlfJevOW3Ix02CK8uaiqPmyGQRn1lAw=";
    };

    cargoHash = "sha256-TrPkWeXwaHuA5aQgeEH8QLOnkdw9/lTpsYbgT1+m5+c=";
  }))

  (buildWindowsGccWrapper pkgsCross.mingw32.buildPackages.gcc)
  (buildWindowsGccWrapper pkgsCross.mingwW64.buildPackages.gcc)

  (let
    responderDocker = dockerTools.buildImage {
      name = "responder-docker";
      tag = "latest";
      config = {
        Cmd = [ "${responder}/bin/responder" "-I" "eth0" ];
        Env = [
          "PYTHONUNBUFFERED=1"
        ];
      };
      copyToRoot = [
        coreutils
        iproute2
      ];
    };
    forwardToResponder = writeShellScript "forward-to-responder" ''
      echo "Forwarding $1 to responder..."

      sudo socat -dd TCP4-LISTEN:$1,fork,reuseaddr TCP:$(docker inspect responder-docker | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'):$1
    '';
  in
  writeShellScriptBin "responder-docker" ''
    if ! docker image inspect responder-docker:latest &>/dev/null; then
      docker load < ${responderDocker}
    fi
    docker run --rm --name responder-docker responder-docker &
    sleep 1
    ${parallel}/bin/parallel ::: '${forwardToResponder} 135' '${forwardToResponder} 3389' '${forwardToResponder} 389' '${forwardToResponder} 445' '${forwardToResponder} 21' '${forwardToResponder} 25' '${forwardToResponder} 53' '${forwardToResponder} 80' '${forwardToResponder} 88' '${forwardToResponder} 110' '${forwardToResponder} 139' '${forwardToResponder} 143' '${forwardToResponder} 587' '${forwardToResponder} 1433' '${forwardToResponder} 1883' '${forwardToResponder} 5985' '${forwardToResponder} 49602'
    docker kill responder-docker
  '')

  certipy

  (python3Packages.buildPythonPackage rec {
    pname = "bloodhound-py";
    version = "1.8.0";
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "bloodhound_ce";
      hash = "sha256-9mPWGB4qGrjenVeUgBFmLipHiA2MrKm4U2mn767ROnA=";
    };

    nativeBuildInputs = with python3Packages; [ setuptools ];

    propagatedBuildInputs = with python3Packages; [
      dnspython
      impacket
      ldap3
      pycryptodome
    ];

    doCheck = false;
  })

  python312Packages.bloodyad

  (pkgs.stdenv.mkDerivation {
    name = "pygpoabuse";

    src = fetchFromGitHub {
      owner = "Hackndo";
      repo = "pyGPOAbuse";
      rev = "63567b8807b6c47e207e9f04071aa3f756cc27a1";
      hash = "sha256-7u4nnoHStkl2xT1Bk5jHj0L80gaERkF+Pmxh+j/o1vs=";
    };

    pythonWithPkgs = python3.withPackages(ps: with ps; [
      msldap
      impacket
    ]);

    buildPhase = ''
      mkdir -p $out/bin

      echo '#!${stdenv.shell}' > $out/bin/pygpoabuse.py
      echo "$pythonWithPkgs/bin/python3 $src/pygpoabuse.py \"\$@\"" >> $out/bin/pygpoabuse.py

      chmod +x $out/bin/pygpoabuse.py
    '';

    dontInstall = true;
  })

  (
    let
      python = python312.override {
        self = python;
        packageOverrides = self: super: {
          impacket = super.impacket.overridePythonAttrs {
            version = "0.13.0.dev0+20250527.165759.abfaea2b";
            src = fetchFromGitHub {
              owner = "Pennyw0rth";
              repo = "impacket";
              rev = "abfaea2b613cab86a94ae7e5edbf5801ef347f30";
              hash = "sha256-LUmo20bRScg1Pd4c4tqtH8pxHk9uC5sLdyjOLZC0exA=";
            };
            # Fix version to be compliant with Python packaging rules
            postPatch = ''
              substituteInPlace setup.py \
                --replace 'version="{}.{}.{}.{}{}"' 'version="{}.{}.{}"'
            '';
          };
          bloodhound-py = super.bloodhound-py.overridePythonAttrs {
            pname = "bloodhound-ce";
            version = "1.8.0";

            src = fetchPypi {
              version = "1.8.0";
              pname = "bloodhound_ce";
              hash = "sha256-9mPWGB4qGrjenVeUgBFmLipHiA2MrKm4U2mn767ROnA=";
            };
          };
        };
      };
    in
    python.pkgs.buildPythonApplication {
      pname = "netexec";
      version = "1.4.0";
      pyproject = true;

      src = fetchFromGitHub {
        owner = "Pennyw0rth";
        repo = "NetExec";
        rev = "714c44bac8959861095c6ebfc5b3695f9a025b97";
        hash = "sha256-FQ4xETy3UEN6vZ2oBKJhvc64g5MrsdxHD9mUMvrR2+A=";
      };

      pythonRelaxDeps = true;

      pythonRemoveDeps = [
        # Fail to detect dev version requirement
        "neo4j"
      ];

      postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail " @ git+https://github.com/Pennyw0rth/impacket.git" "" \
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
        bloodhound-py
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
        xmltodict
      ];

      nativeCheckInputs = with python.pkgs; [ pytestCheckHook ] ++ [ writableTmpDirAsHomeHook ];

      # Tests no longer works out-of-box with 1.3.0
      doCheck = false;
    }
  )

  (pkgs.stdenv.mkDerivation {
    name = "krbrelayx";

    src = fetchFromGitHub {
      owner = "dirkjanm";
      repo = "krbrelayx";
      rev = "aef69a7e4d2623b2db2094d9331b2b07817fc7a4";
      hash = "sha256-rcDa6g0HNjrM/XdXOF22iURA9euJbSahGKlFr5R7I/U=";
    };

    pythonWithPkgs = python311.withPackages(ps: with ps; [
      impacket
      ldap3
      dnspython
    ]);

    buildPhase = ''
      mkdir -p $out/bin

      for script in $src/*.py; do
        outpath="$out/bin/$(basename -s .py "$script")"
        echo "#!${stdenv.shell}" > "$outpath"
        echo "$pythonWithPkgs/bin/python3 $script \"\$@\"" >> "$outpath"

        chmod +x "$outpath"
      done
    '';

    dontInstall = true;
  })
])
