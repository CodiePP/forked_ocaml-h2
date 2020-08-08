{ pkgs ? import ./sources.nix { inherit ocamlVersion; }
, ocamlVersion ? "4_10"
, doCheck ? true }:

let
  inherit (pkgs) lib stdenv ocamlPackages;
  inherit (lib) gitignoreSource;
in

  with ocamlPackages;

  let
    genSrc = { dirs, files ? [] }: gitignoreSource (lib.cleanSourceWith rec {
      src = ./..;
      # Good examples: https://github.com/NixOS/nixpkgs/blob/master/lib/sources.nix
      filter = name: type:
      let
        path = toString name;
        baseName = baseNameOf path;
        relPath = lib.removePrefix (toString src + "/") path;
      in
        (lib.any (dir: dir == relPath || (lib.hasPrefix "${dir}/" relPath)) dirs) ||
        (type == "regular" &&
          (lib.hasPrefix "dune" baseName ||
           (lib.any (file: lib.hasPrefix file baseName) files)));
    });
    buildH2 = args: buildDunePackage ({
      version = "0.6.0-dev";
      useDune2 = true;
      doCheck = doCheck;
    } // args);

    h2Packages = rec {
      hpack = buildH2 {
        pname = "hpack";
        src = genSrc {
          dirs = [ "hpack" ];
          files = [ "hpack.opam" ];
        };

        buildInputs = [ alcotest hex yojson ];
        propagatedBuildInputs = [ angstrom faraday ];
        checkPhase = ''
          dune build @slowtests -p hpack --no-buffer --force
        '';
      };

      h2 = buildH2 {
        pname = "h2";
        src = genSrc {
          dirs = [ "lib" "lib_test" ];
          files = [ "h2.opam" ];
        };

        buildInputs = [ alcotest hex yojson ];
        propagatedBuildInputs = [
          angstrom
          faraday
          base64
          psq
          hpack
          httpaf
        ];
      };

      # These two don't have tests
      h2-lwt = buildH2 {
        pname = "h2-lwt";
        src = genSrc {
          dirs = [ "lwt" ];
          files = [ "h2-lwt.opam" ];
        };
        doCheck = false;
        propagatedBuildInputs = [ h2 lwt gluten-lwt ];
      };

      h2-lwt-unix = buildH2 {
        pname = "h2-lwt-unix";
        src = genSrc {
          dirs = [ "lwt-unix" ];
          files = [ "h2-lwt-unix.opam" ];
        };
        doCheck = false;
        propagatedBuildInputs = [
          h2-lwt
          gluten-lwt-unix
          faraday-lwt-unix
          lwt_ssl
        ];
      };
    };
  in
  h2Packages // (if (lib.versionOlder "4.08" ocaml.version) then {
    h2-async = buildH2 {
      pname = "h2-async";
      src = genSrc {
        dirs = [ "async" ];
        files = [ "h2-async.opam" ];
      };
      doCheck = false;
      propagatedBuildInputs = with h2Packages; [
        h2
        async
        gluten-async
        faraday-async
        async_ssl
      ];
    };

    h2-mirage = buildH2 {
      pname = "h2-mirage";
      src = genSrc {
        dirs = [ "mirage" ];
        files = [ "h2-mirage.opam" ];
      };
      doCheck = false;
      propagatedBuildInputs = with h2Packages; [
        conduit-mirage
        h2-lwt
        gluten-mirage
      ];
    };
    } else {})
