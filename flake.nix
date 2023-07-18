{
  description = "Rust example flake for Zero to Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };

      devInputs = with pkgs; [
        rustc
        rustfmt
        cargo
        just
      ];

      nativeBuildInputs = with pkgs; [
        cmake
        pkgconf
        makeWrapper
      ];

      buildInputs = with pkgs; [
        libGL
        libxkbcommon
      ];
    in {
      devShells.${system}.default = pkgs.mkShell {
        inherit nativeBuildInputs buildInputs;
        packages = devInputs;
      };

      # TODO: fix this (needs cargo git dependencies like onagre)
      packages.${system}.default = pkgs.rustPlatform.buildRustPackage rec {
        pname = "pop-launcher";
        version = "1.2.2";

        inherit nativeBuildInputs buildInputs;

        src = ./.;

        postPatch = ''
          substituteInPlace src/lib.rs \
              --replace '/usr/lib/pop-launcher' "$out/share/pop-launcher"
          substituteInPlace plugins/src/scripts/mod.rs \
              --replace '/usr/lib/pop-launcher' "$out/share/pop-launcher"
          substituteInPlace plugins/src/calc/mod.rs \
              --replace 'Command::new("qalc")' 'Command::new("${pkgs.libqalculate}/bin/qalc")'
          substituteInPlace plugins/src/find/mod.rs \
              --replace 'spawn("fd")' 'spawn("${pkgs.fd}/bin/fd")'
          substituteInPlace plugins/src/terminal/mod.rs \
              --replace '/usr/bin/gnome-terminal' 'gnome-terminal'
        '';

        cargoLock = {
          lockFile = ./Cargo.lock;
          outputHashes = {
            "cosmic-client-toolkit-0.1.0" = "sha256-jzpy3JMxV8KbLQ8iCWuJtusxocVbjSYEBD5gO6ZmCrE=";
            "smithay-0.3.0" = "sha256-hZPaOTkwDwHdlYzDvHnqXa4QoAmLXM2byejIZBZBZ0c=";
            "smithay-client-toolkit-0.16.0" = "sha256-0Ze7BOLTc4MXxZQ5A9FvmzKmuG1oOxGJ4z9lD/2696I=";
         };
        };

        cargoBuildFlags = [ "--package" "pop-launcher-bin" ];

        postInstall = ''
          mv $out/bin/pop-launcher{-bin,}

          plugins_dir=$out/share/pop-launcher/plugins
          scripts_dir=$out/share/pop-launcher/scripts
          mkdir -p $plugins_dir $scripts_dir

          for plugin in $(find plugins/src -mindepth 1 -maxdepth 1 -type d -printf '%f\n'); do
            mkdir $plugins_dir/$plugin
            cp plugins/src/$plugin/*.ron $plugins_dir/$plugin
            ln -sf $out/bin/pop-launcher $plugins_dir/$plugin/$(echo $plugin | sed 's/_/-/')
          done

          for script in scripts/*; do
            cp -r $script $scripts_dir
          done
        '';

        meta = with pkgs.lib; {
          description = "Modular IPC-based desktop launcher service";
          homepage = "https://github.com/pop-os/launcher";
          platforms = platforms.linux;
          license = licenses.mpl20;
          maintainers = with maintainers; [ samhug ];
        };
      };
    };
}
