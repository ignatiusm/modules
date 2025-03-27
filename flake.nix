{
  description = "Project with Nextflow and pytest2nf-test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Build up-to-date Nextflow
        nextflowPackage = pkgs.stdenv.mkDerivation rec {
          pname = "nextflow";
          version = "24.10.5";
          src = pkgs.fetchFromGitHub {
            owner = "nextflow-io";
            repo = pname;
            rev = "b271f85df366749438ed3e32da3b091113a3d848";
            hash = "sha256-sCIqeNh+Mdl9d7fywHkjAxWsZwv0VySZi/k5HEgee9w=";
          };

          nativeBuildInputs = with pkgs; [ gradle makeWrapper ];

          postPatch = ''
            # Nextflow invokes the constant "/bin/bash" (not as a shebang) at
            # several locations so we fix that globally. However, when running inside
            # a container, we actually *want* "/bin/bash". Thus the global fix needs
            # to be reverted for this specific use case.
            substituteInPlace modules/nextflow/src/main/groovy/nextflow/executor/BashWrapperBuilder.groovy \
              --replace-fail "['/bin/bash'," "['${pkgs.bash}/bin/bash'," \
              --replace-fail "if( containerBuilder ) {" "if( containerBuilder ) {
                        launcher = launcher.replaceFirst(\"/nix/store/.*/bin/bash\", \"/bin/bash\")"
          '';

          mitmCache = pkgs.gradle.fetchDeps {
            inherit pname;
            data = ./deps.json;
          };
          __darwinAllowLocalNetworking = true;

          gradleUpdateTask = "pack";
          # The installer attempts to copy a final JAR to $HOME/.nextflow/...
          gradleFlags = [ "-Duser.home=\$TMPDIR" ];
          preBuild = ''
            # See Makefile (`make pack`)
            export BUILD_PACK=1
          '';
          gradleBuildTask = "pack";
        
          installPhase = ''
            runHook preInstall
        
            mkdir -p $out/bin
            install -Dm755 build/releases/nextflow-${version}-dist $out/bin/nextflow
        
            runHook postInstall
          '';
        
          postFixup = ''
            wrapProgram $out/bin/nextflow \
              --set JAVA_HOME ${pkgs.jdk} \
              --prefix PATH : ${pkgs.jdk}/bin
          '';

        };

        # Build the Kotlin project
        kotlinProject = pkgs.stdenv.mkDerivation {
          name = "pytest2nf-test";
          src = pkgs.fetchFromGitHub {
            owner = "GallVp";
            repo = "pytest2nf-test";
            rev = "main";
            sha256 = "sha256-F2ylnpWpo5VIgkt9Xr2A2zfcWb6x8SlVmDdsrh4CT6k=";
          };

          nativeBuildInputs = with pkgs; [ jdk makeWrapper ];

          buildPhase = ''
            # Create a writable location for Gradle
            export GRADLE_USER_HOME=$(mktemp -d)

            # Make the gradlew script executable
            chmod +x gradlew

            # Run the installation using the gradle wrapper
            ./gradlew --no-daemon installDist
          '';

          installPhase = ''
            mkdir -p $out/bin

            # Copy the built executable to the output directory
            cp -r build/install/pytest2nf-test/bin/* $out/bin/
            cp -r build/install/pytest2nf-test/lib $out/

            # Ensure the executable script uses the correct paths
            wrapProgram $out/bin/pytest2nf-test \
              --set JAVA_HOME ${pkgs.jdk} \
              --prefix PATH : ${pkgs.jdk}/bin
          '';
        };

        trogonPackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "trogon";
          version = "0.6.0";

          src = pkgs.fetchFromGitHub {
            owner = "Textualize";
            repo = pname;
            rev = "v${version}";
            sha256 = "sha256-YjFLy0XYgpBFMpuoa/TSNTXBxctFtzXe7HaxAFWRufE=";
          };

          format = "pyproject";

          nativeBuildInputs = with pkgs.python3Packages; [
            poetry-core
            setuptools
            wheel
          ];

          propagatedBuildInputs = with pkgs.python3Packages; [
            textualPackage
            click
          ];
        };

        textualPackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "textual";
          version = "0.71.1";

          src = pkgs.fetchFromGitHub {
            owner = "Textualize";
            repo = pname;
            rev = "v${version}";
            sha256 = "sha256-fp9N0jiyp1ooWuaytV6/wqktXd0snsBhEI6uysSkoL4=";
          };

          format = "pyproject";

          nativeBuildInputs = with pkgs.python3Packages; [
            poetry-core
            setuptools
            wheel
          ];

          propagatedBuildInputs = with pkgs.python3Packages; [
            rich
            markdown-it-py
            typing-extensions
          ];
        };

        pdiffPackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "pdiff";
          version = "1.1.4";

          src = pkgs.fetchFromGitHub {
            owner = "nkouevda";
            repo = pname;
            rev = "v${version}";
            sha256 = "sha256-Ek+hWkLfbOnVQvSQ7qSLoZdhXARn5Iz/kmXlFToG2GU=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
            wheel
          ];

          propagatedBuildInputs = with pkgs.python3Packages; [
            colorama
          ];
        };

        refgeniePackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "refgenie";
          version = "0.12.1";

          src = pkgs.fetchFromGitHub {
            owner = pname;
            repo = pname;
            rev = "v${version}";
            sha256 = "sha256-8mi7O9XZUccaAxToQHMS7fCRCPQcb6yh8C0mQ7fAQGc=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
            wheel
          ];
        };

        rocratePackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "rocrate";
          version = "0.13.0";

          src = pkgs.fetchFromGitHub {
            owner = "ResearchObject";
            repo = "ro-crate-py";
            rev = "1f4a5cdfeac5b2e6f11dee46d3bc9e28d932e016";
            sha256 = "sha256-mOLRueAkWoaXf3vsaKv1o6TciayUSCIdbYvKfTLKq18=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
            wheel
          ];

          propagatedBuildInputs = with pkgs.python3Packages; [
            click
            python-dateutil
            jinja2
            requests
            arcpPackage
          ];
        };

        arcpPackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "arcp";
          version = "0.2.0";

          src = pkgs.fetchFromGitHub {
            owner = "stain";
            repo = "${pname}-py";
            rev = "363542f44a8a6312bfdfd03e69a682869acdc2c4";
            sha256 = "sha256-yFFMGvncv/QlCRnPur9tZLmoDXBN0Qr9m+s7F9+JDvc=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
            wheel
          ];
        };

        repo2rocratePackage = pkgs.python3Packages.buildPythonPackage rec {
          pname = "repo2rocrate";
          version = "0.1.2";

          src = pkgs.fetchFromGitHub {
            owner = "crs4";
            repo = pname;
            rev = version;
            sha256 = "sha256-TrwcBnp/eu8zAkPdETUtiJYoSGFHbctbkANAuIVx7I0=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
            wheel
          ];

          propagatedBuildInputs = with pkgs.python3Packages; [
            click
            pyyaml
            rocratePackage
          ];
        };

        # Build nf-core as a Python package
        nfcorePythonPackage = pkgs.python3Packages.buildPythonPackage {
          pname = "nf-core";
          version = "3.2.0";

          src = pkgs.fetchFromGitHub {
            owner = "nf-core";
            repo = "tools";
            rev = "52e810986e382972ffad0aab28e94f828ffd509b";
            sha256 = "sha256-4BEaKDwJvxriipBp5vh3J4WPPRfDtwqNd5z61ggEetU=";
          };

          propagatedBuildInputs = with pkgs.python3Packages; [
            click
            filetype
            gitpython
            pygithub
            jinja2
            jsonschema
            markdown
            packaging
            pillow
            prompt_toolkit
            pydantic
            pyyaml
            questionary
            requests
            requests-cache
            rich-click
            rich
            tabulate
            ruamel-yaml
            # Derivations from GitHub defined above
            textualPackage
            trogonPackage
            pdiffPackage
            rocratePackage
            repo2rocratePackage
            refgeniePackage
          ];
        };
        
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nextflowPackage
            nf-test
            kotlinProject
            jdk
            nfcorePythonPackage
            python3
          ];
          
          # Add our compiled executable to PATH
          shellHook = ''
            echo "Nextflow Development Environment"
            echo "--------------------------------"
            echo "pytest2nf-test is now available in your shell"
            echo "nf-core is now available in your shell"
          '';
        };
      });
}
