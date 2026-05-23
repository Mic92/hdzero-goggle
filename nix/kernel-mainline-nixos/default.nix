# Mainline V536 kernel as a NixOS kernel package (linuxManualConfig).
# Board defconfig + NixOS/systemd config fragment (nixos.config).
{
  lib,
  stdenv,
  buildPackages,
  
  linuxManualConfig,
  # boot.kernelPackages overrides the kernel with extra arguments
  # (features, kernelPatches, randstructSeed); accept and ignore them
  # like nix/kernel does.
  ...
}:
let
  # Linux v7.0.9 + the V536/HDZero Goggle port (branch v536-port).
  src = builtins.fetchGit {
    url = "file:///home/joerg/git/linux";
    ref = "v536-port";
    rev = "a57b7e90862c4f4fab808db1ae1b11b71279c783";
  };
  # sun8i_v536_defconfig expanded to a full .config plus the NixOS fragment.
  configfile = stdenv.mkDerivation {
    name = "sun8i-v536-nixos-kernel-config";
    inherit src;
    depsBuildBuild = [ buildPackages.stdenv.cc ];
    nativeBuildInputs = with buildPackages; [
      bc
      bison
      flex
      perl
    ];
    postPatch = ''
      patchShebangs scripts/
    '';
    buildPhase = ''
      runHook preBuild
      export ARCH=arm
      export CROSS_COMPILE=${stdenv.cc.targetPrefix}
      make sun8i_v536_defconfig
      ./scripts/kconfig/merge_config.sh -m .config ${./nixos.config}
      make olddefconfig
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp .config $out
      runHook postInstall
    '';
  };
in
(linuxManualConfig {
  inherit lib stdenv src configfile;
  pname = "linux-mainline-v536";
  version = "7.0.9";
  # no CONFIG_LOCALVERSION in the defconfig, kernel.release is plain 7.0.9
  modDirVersion = "7.0.9";
  allowImportFromDerivation = true;
}).overrideAttrs
  (old: {
    # NixOS skips its requiredKernelConfig assertions for kernels that carry a
    # `features` attribute; the only assertion the generated config cannot
    # satisfy is CONFIG_DMIID, which does not exist on arm32 (needs EFI/DMI)
    # and is not needed by systemd there.
    passthru = (old.passthru or { }) // {
      features = { };
    };
  })
