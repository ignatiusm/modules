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
        
        # Build the Kotlin project
        kotlinProject = pkgs.stdenv.mkDerivation {
          name = "pytest2nf-test";
          src = pkgs.fetchFromGitHub {
            owner = "GallVp";
            repo = "pytest2nf-test";
            rev = "main";
            sha256 = "sha256-F2ylnpWpo5VIgkt9Xr2A2zfcWb6x8SlVmDdsrh4CT6k="; # Replace with actual hash after first attempt
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
        
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nextflow
            kotlinProject # Add our compiled project
            jdk # Include JDK for development
          ];
          
          # Add our compiled executable to PATH
          shellHook = ''
            echo "pytest2nf-test is now available in your shell"
          '';
        };
      });
}
