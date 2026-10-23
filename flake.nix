{
  description = "Flight report toolchain: pandoc + filters + LuaLaTeX + fonts + python";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
					# drawio (the CLI underneath drawio-headless) is flagged unfree in
					# nixpkgs; whitelist exactly that one package instead of blanket
					# allowUnfree.
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "drawio" ];
        };

				# Exactly the TeX Live packages this report needs (0.6 GB / 499 store
				# paths) instead of a whole scheme (texliveMedium: 2.5 GB / 1687). Each
				# tl package is prebuilt in cache.nixos.org and `.withPackages` only
				# symlinks them into an env, so this is a ~1 s local build -- not the
				# uncached texlive.combine of old nixpkgs. Add a name here if a report
				# wants a missing .sty; fall back to pkgs.texliveMedium if that turns
				# into whack-a-mole.
				tex = pkgs.texliveSmall.withPackages (ps: with ps; [
					polyglossia      # lang: uk
					unicode-math     # pulled by pandoc's LaTeX template under lualatex
					lualatex-math    # unicode-math loads it on the lualatex engine
					extsizes         # documentclass: extarticle, fontsize: 14pt
					booktabs         # pandoc/crossref tables
					fontspec microtype xurl bookmark footnotehyper selnolig upquote
					koma-script caption etoolbox
				]);

        python = pkgs.python3.withPackages (ps: with ps; [
          numpy pandas scipy matplotlib
        ]);

				# Report fonts: Liberation Serif/Mono -- metric-compatible with Times
				# New Roman, full Cyrillic, FREE and prebuilt in cache.nixos.org.
				# (corefonts, the actual Times New Roman, is unfree AND downloads MS
				# installers at build time, so a locked-down CI runner must build it
				# with external egress -> the repeated "font cannot be found" / OOM
				# failures. Liberation removes that entirely.) One package provides
				# both the serif and the mono; see report.md main/monofont.
        fonts = pkgs.liberation_ttf;

				# fontconfig view of the fonts. Second, independent font-discovery path
				# for LuaLaTeX's luaotfload, belt-and-suspenders with OSFONTDIR below.
        fontsConf = pkgs.makeFontsConf { fontDirectories = [ fonts ]; };

        toolchain = [
					# pandoc, pandoc-crossref and pandoc-plot all come from the same
					# haskellPackages set, so their pandoc-types ABI always matches - no
					# manual version pinning.
          pkgs.pandoc
          pkgs.haskellPackages.pandoc-crossref
          pkgs.haskellPackages.pandoc-plot
          pkgs.drawio-headless
          tex
          python
        ];
				# Environment shared by the dev shell and the sandboxed package build,
				# so `nix build` and `nix develop -c sh build.sh` behave identically.
        env = {
					# luaotfload resolves fontspec's font *names* by scanning OSFONTDIR
					# (it recurses into share/fonts/truetype). This needs no prebuilt
					# fontconfig cache, so it works on a clean CI runner. FONTCONFIG_FILE
					# is a redundant second path to the same fonts.
          OSFONTDIR = "${fonts}/share/fonts";
          FONTCONFIG_FILE = fontsConf;

          MPLBACKEND = "Agg";

					# Nix-built LuaTeX needs a valid locale; en_US.UTF-8 isn't in the Nix
					# glibc on non-NixOS hosts, so pin the always-present C.UTF-8 (else
					# "Error producing PDF").
          LANG = "C.UTF-8";
          LC_ALL = "C.UTF-8";
        };
      in {
				# Hermetic report build: `nix build` -> result/report.{pdf,docx,html}.
				# Runs the same build.sh as the dev shell, just inside the Nix sandbox
				# (build.sh already points HOME at build/, so the luaotfload/matplotlib
				# caches land there).
        packages.default = pkgs.stdenvNoCC.mkDerivation ({
          name = "flight-report";
          src = self;
          nativeBuildInputs = toolchain;
          buildPhase = "sh build.sh";
          installPhase = ''
            mkdir -p $out
            install -m644 build/report.pdf build/report.docx build/report.html "$out"/
          '';
        } // env);

				# Toolchain for iterating locally: `nix develop -c sh build.sh`
				# rebuilds in place, without copying the source to the store.
        devShells.default = pkgs.mkShell ({
          packages = toolchain;
        } // env);
      });
}
