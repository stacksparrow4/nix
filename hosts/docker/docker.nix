{
  # Core dependencies
  pkgs,
  lib,
  runCommand,
  buildPackages,
  # Image configuration
  name ? "stacksparrow4/dev",
  tag ? "latest",
  bundleNixpkgs ? true,
  channelName ? "nixpkgs",
  channelURL ? "https://nixos.org/channels/nixpkgs-unstable",
  extraPkgs ? [ ],
  maxLayers ? 70,
  nixConf ? {
    experimental-features = [ "nix-command" "flakes" ];
  },
  uid ? 1000,
  gid ? 100,
  uname ? "sprrw",
  gname ? "users",
  # Default Packages
  nix,
  bashInteractive,
  coreutils-full,
  gnutar,
  gzip,
  gnugrep,
  which,
  curl,
  less,
  wget,
  man,
  cacert,
  findutils,
  iana-etc,
  openssh,
  # Other dependencies
  shadow,
  # Home manager
  home-manager,
  inputs
}:
let
  defaultPkgs = [
    nix
    bashInteractive
    coreutils-full
    gnutar
    gzip
    gnugrep
    which
    curl
    less
    wget
    man
    cacert.out
    findutils
    iana-etc
    openssh
  ] ++ extraPkgs;

  users =
    {

      root = {
        uid = 0;
        shell = lib.getExe bashInteractive;
        home = "/root";
        gid = 0;
        groups = [ "root" ];
        description = "System administrator";
      };

      nobody = {
        uid = 65534;
        shell = lib.getExe' shadow "nologin";
        home = "/var/empty";
        gid = 65534;
        groups = [ "nobody" ];
        description = "Unprivileged account (don't use!)";
      };

    }
    // lib.optionalAttrs (uid != 0) {
      "${uname}" = {
        uid = uid;
        shell = lib.getExe bashInteractive;
        home = "/home/${uname}";
        gid = gid;
        groups = [ "${gname}" ];
        description = "Nix user";
      };
    }
    // lib.listToAttrs (
      map (n: {
        name = "nixbld${toString n}";
        value = {
          uid = 30000 + n;
          gid = 30000;
          groups = [ "nixbld" ];
          description = "Nix build user ${toString n}";
        };
      }) (lib.lists.range 1 32)
    );

  groups =
    {
      root.gid = 0;
      nixbld.gid = 30000;
      nobody.gid = 65534;
    };

  userToPasswd = (
    k:
    {
      uid,
      gid ? 65534,
      home ? "/var/empty",
      description ? "",
      shell ? "/bin/false",
      groups ? [ ],
    }:
    "${k}:x:${toString uid}:${toString gid}:${description}:${home}:${shell}"
  );
  passwdContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs userToPasswd users)));

  userToShadow = k: { ... }: "${k}:!:1::::::";
  shadowContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs userToShadow users)));

  # Map groups to members
  # {
  #   group = [ "user1" "user2" ];
  # }
  groupMemberMap = (
    let
      # Create a flat list of user/group mappings
      mappings = (
        builtins.foldl' (
          acc: user:
          let
            groups = users.${user}.groups or [ ];
          in
          acc
          ++ map (group: {
            inherit user group;
          }) groups
        ) [ ] (lib.attrNames users)
      );
    in
    (builtins.foldl' (
      acc: v:
      acc
      // {
        ${v.group} = acc.${v.group} or [ ] ++ [ v.user ];
      }
    ) { } mappings)
  );

  groupToGroup =
    k:
    { gid }:
    let
      members = groupMemberMap.${k} or [ ];
    in
    "${k}:x:${toString gid}:${lib.concatStringsSep "," members}";
  groupContents = (lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs groupToGroup groups)));

  defaultNixConf = {
    sandbox = "false";
    build-users-group = "nixbld";
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };

  nixConfContents =
    (lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        n: v:
        let
          vStr = if builtins.isList v then lib.concatStringsSep " " v else v;
        in
        "${n} = ${vStr}"
      ) (defaultNixConf // nixConf)
    ))
    + "\n";

  userHome = if uid == 0 then "/root" else "/home/${uname}";

  homeManagerGeneration = (home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs;
    modules = [ ./home/default.nix ];
    extraSpecialArgs = { inputs = inputs; };
  }).activationPackage;

  homeManagerProfile = runCommand "home-manager-profile" {} ''
    cp -r ${homeManagerGeneration}/home-path $out 
  '';

  nixLdLibraries = pkgs.buildEnv {
    name = "lb-library-path";
    pathsToLink = [ "/lib" ];
    paths = map lib.getLib (with pkgs; [
        zlib
        zstd
        stdenv.cc.cc
        curl
        openssl
        attr
        libssh
        bzip2
        libxml2
        acl
        libsodium
        util-linux
        xz
        systemd
    ]);
    postBuild = ''
      ln -s ${pkgs.stdenv.cc.bintools.dynamicLinker} $out/share/nix-ld/lib/ld.so
    '';
    extraPrefix = "/share/nix-ld";
    ignoreCollisions = true;
  }; 
  allPkgs = defaultPkgs ++ [ homeManagerProfile nixLdLibraries ];

  baseSystem =
    let
      nixpkgs = pkgs.path;
      channel = runCommand "channel-nixos" { inherit bundleNixpkgs; } ''
        mkdir $out
        if [ "$bundleNixpkgs" ]; then
          ln -s ${
            builtins.path {
              path = nixpkgs;
              name = "source";
            }
          } $out/nixpkgs
          echo "[]" > $out/manifest.nix
        fi
      '';
      rootEnv = buildPackages.buildEnv {
        name = "root-profile-env";
        paths = allPkgs;
      };
      manifest = buildPackages.runCommand "manifest.nix" { } ''
        cat > $out <<EOF
        [
        ${lib.concatStringsSep "\n" (
          builtins.map (
            drv:
            let
              outputs = drv.outputsToInstall or [ "out" ];
            in
            ''
              {
                ${lib.concatStringsSep "\n" (
                  builtins.map (output: ''
                    ${output} = { outPath = "${lib.getOutput output drv}"; };
                  '') outputs
                )}
                outputs = [ ${lib.concatStringsSep " " (builtins.map (x: "\"${x}\"") outputs)} ];
                name = "${drv.name}";
                outPath = "${drv}";
                system = "${drv.system}";
                type = "derivation";
                meta = { };
              }
            ''
          ) allPkgs
        )}
        ]
        EOF
      '';
      profile = buildPackages.runCommand "user-environment" { } ''
        mkdir $out
        cp -a ${rootEnv}/* $out/
        ln -s ${manifest} $out/manifest.nix
      '';
    in
    runCommand "base-system"
      {
        inherit
          passwdContents
          groupContents
          shadowContents
          nixConfContents
          ;
        passAsFile = [
          "passwdContents"
          "groupContents"
          "shadowContents"
          "nixConfContents"
        ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      }
      (
        ''
          env
          set -x
          mkdir -p $out/etc

          mkdir -p $out/etc/ssl/certs
          ln -s /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs

          cat $passwdContentsPath > $out/etc/passwd
          echo "" >> $out/etc/passwd

          cat $groupContentsPath > $out/etc/group
          echo "" >> $out/etc/group

          cat $shadowContentsPath > $out/etc/shadow
          echo "" >> $out/etc/shadow

          mkdir -p $out/usr
          ln -s /nix/var/nix/profiles/share $out/usr/

          mkdir -p $out/nix/var/nix/gcroots

          mkdir $out/tmp

          mkdir -p $out/var/tmp

          mkdir -p $out/etc/nix
          cat $nixConfContentsPath > $out/etc/nix/nix.conf

          mkdir -p $out${userHome}
          mkdir -p $out/nix/var/nix/profiles/per-user/${uname}

          ln -s ${profile} $out/nix/var/nix/profiles/default-1-link
          ln -s /nix/var/nix/profiles/default-1-link $out/nix/var/nix/profiles/default

          ln -s ${channel} $out/nix/var/nix/profiles/per-user/${uname}/channels-1-link
          ln -s /nix/var/nix/profiles/per-user/${uname}/channels-1-link $out/nix/var/nix/profiles/per-user/${uname}/channels

          mkdir -p $out${userHome}/.nix-defexpr
          ln -s /nix/var/nix/profiles/per-user/${uname}/channels $out${userHome}/.nix-defexpr/channels
          echo "${channelURL} ${channelName}" > $out${userHome}/.nix-channels

          mkdir -p $out/bin $out/usr/bin
          ln -s ${lib.getExe' coreutils-full "env"} $out/usr/bin/env
          ln -s ${lib.getExe bashInteractive} $out/bin/sh

          cp -r ${homeManagerGeneration}/home-files/.* $out${userHome}
          ln -s /nix/var/nix/profiles/default $out${userHome}/.nix-profile

          # Nix LD
          mkdir -p $out/lib64
          ln -s ${pkgs.nix-ld}/libexec/nix-ld $out/lib64/ld-linux-x86-64.so.2
        ''
      );

in
pkgs.dockerTools.buildLayeredImageWithNixDb {

  inherit
    name
    tag
    maxLayers
    uid
    gid
    uname
    gname
    ;

  contents = [ baseSystem ];

  extraCommands = ''
    rm -rf nix-support
    ln -s /nix/var/nix/profiles nix/var/nix/gcroots/profiles
  '';
  fakeRootCommands = ''
    chmod 1777 tmp
    chmod 1777 var/tmp
    chown -R ${toString uid}:${toString gid} .${userHome}
    chown -R ${toString uid}:${toString gid} nix
  '';

  config = {
    Cmd = [ (lib.getExe bashInteractive) ];
    User = "${toString uid}:${toString gid}";
    Env = [
      "USER=root"
      "PATH=${
        lib.concatStringsSep ":" [
          "${userHome}/.nix-profile/bin"
          "/nix/var/nix/profiles/default/bin"
          "/nix/var/nix/profiles/default/sbin"
        ]
      }"
      "MANPATH=${
        lib.concatStringsSep ":" [
          "${userHome}/.nix-profile/share/man"
          "/nix/var/nix/profiles/default/share/man"
        ]
      }"
      "SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
      "NIX_PATH=/nix/var/nix/profiles/per-user/${uname}/channels:${userHome}/.nix-defexpr/channels"
      "TERM=screen-256color"
      "NIX_LD_LIBRARY_PATH=/nix/var/nix/profiles/default/share/nix-ld/lib"
      "NIX_LD=/nix/var/nix/profiles/default/share/nix-ld/lib/ld.so"
    ];
  };

}
