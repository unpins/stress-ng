{
  description = "stress-ng as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "stress-ng";

      smoke = [ "--version" ];
      smokePattern = "^stress-ng, version [0-9]+\\.[0-9]+";

      engine = "unpin-llvm";
      multicall = {
        programs = [ { name = "stress-ng"; } ];
      };

      # nixpkgs wires only part of what stress-ng's Makefile.config probes for.
      # The rest each enable a stressor (acl, crypt, jpeg, mpfr, module, hash,
      # ipsec-mb, …), so they are added here. Dropped: libglvnd and libgbm feed
      # only the `gpu` stressor, and both dlopen the vendor's GL/DRM driver at
      # run time, so neither has a static build; libgcrypt is a stale nixpkgs
      # input (stress-ng removed that dependency upstream).
      build = pkgs:
        let
          p = pkgs.pkgsStatic;
          h = p.stdenv.hostPlatform;
          # gmp's x86_64 mpn assembly emits a rel8 BRANCH that Mach-O ld64.lld
          # rejects ("BRANCH relocation has width 1 bytes, but must be 4"); ELF
          # lld relaxes it. Same fix as php: gmp's generic C mpn on darwin, with
          # --disable-fat since configure refuses fat without assembly.
          gmp = p.gmp.overrideAttrs (o: p.lib.optionalAttrs h.isDarwin {
            configureFlags = (o.configureFlags or [ ]) ++ [ "--disable-fat" "--disable-assembly" ];
          });
        in
        (p.stress-ng.override { libglvnd = null; libgbm = null; libgcrypt = null; }).overrideAttrs (old: {
          buildInputs = old.buildInputs
            ++ [ gmp (p.mpfr.override { inherit gmp; }) p.libjpeg p.libxcrypt p.libmd p.xxHash p.xz ]
            ++ p.lib.optionals h.isLinux [ p.acl p.kmod p.zstd ]
            ++ p.lib.optional h.isMusl p.libexecinfo
            # intel-ipsec-mb builds only its shared library unless told otherwise.
            ++ p.lib.optional (h.isLinux && h.isx86_64) (p.intel-ipsec-mb.overrideAttrs (o: {
              makeFlags = (o.makeFlags or [ ]) ++ [ "SHARED=n" ];
            }));
          # The apparmor stressor embeds a profile compiled at build time; without
          # a working parser the probe answers "no" even with libapparmor
          # present. The profile includes `tunables/global`, which the parser
          # looks for under /etc/apparmor.d; point it at nixpkgs' profiles. The
          # probe tests the variable with `-x`, so the flag goes in a wrapper.
          makeFlags = old.makeFlags ++ p.lib.optional h.isLinux
            "APPARMOR_PARSER=${pkgs.buildPackages.writeShellScript "apparmor_parser" ''
              exec ${pkgs.buildPackages.apparmor-parser}/bin/apparmor_parser \
                -I ${pkgs.buildPackages.apparmor-profiles}/etc/apparmor.d "$@"
            ''}";
          # musl has no backtrace(); libexecinfo provides it for the crash
          # backtrace, and the Makefile reads LDFLAGS in both probe and link.
          LDFLAGS = p.lib.optionalString h.isMusl "-lexecinfo";
          # libkmod.a reads zstd-compressed modules, but stress-ng links only
          # -lkmod (it expects the shared libkmod to carry that dependency).
          preBuild = (old.preBuild or "") + p.lib.optionalString h.isLinux ''
            makeFlagsArray+=("LIB_KMOD=-lkmod -lzstd")
          '' + p.lib.optionalString h.isMusl ''
            # The engine's libc is bitcode and folds into the probe's LTO link:
            # musl's pthread_mutexattr_init always returns 0, so the probe's
            # guarded pthread_mutexattr_setprioceiling call is dead code, the
            # probe links, and stress-ng concludes musl has it (it doesn't; the
            # final link then fails). An empty config file reads as "absent".
            mkdir -p configs
            touch configs/HAVE_PTHREAD_MUTEXATTR_SETPRIOCEILING
          '';
        });
    };
}
