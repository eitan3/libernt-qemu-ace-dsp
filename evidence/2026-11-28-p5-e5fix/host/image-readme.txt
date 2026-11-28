LiberNT test image - audio: Intel SST, the P5 image
===================================================

What this is
  The audio branch feat/audio-control-polish at d8fbfe348da (on upstream
  master 23a7b6407b7) plus the burned-in settings: the DSP driver boots the
  DSP by itself and runs its loopback self-test (BootDsp = 1, SelfTest = 3,
  Topology = sof-ipc4-loopback.tplg). No diagnostic trace code.
  In it: the Intel SST DSP driver (boot, streams through the DSP, the volume
  and mute nodes, power-down and recovery), the headphone jack plug/unplug
  fix, the endpoint properties (adapter path, form factor, speakers), and
  the file-system fix for the stick.
  Kernel identity: 20261128-nt10.0-045-3191-g486b024.libernt

Rules for the stick
  Shut LiberNT down from the Start menu and wait for the power-off. In Windows
  use "Safely Remove Hardware" before you unplug the stick.

Files
  LiberNT.img   the image for the USB stick
  LiberNT.iso   CD image (a VM can boot it)
  LiberNT.vhd   disk image (a VM can boot it)
  SHA256SUMS    the three checksums

  LiberNT.iso  sha256 0d7596b784ae0605c03c5aa987d6f7540221516aad537b9cd07a3030e2333a77
  LiberNT.vhd  sha256 c17f8ad889cba8e729ebd45717e21e34453064ae74af1e37613fd47bb109a2ae
  LiberNT.img  sha256 a1128fe829a1dfbdebbf2b94aded158f779ce89f9e154f7820922d9f184cd83b

Test (about 2 minutes on the machine with the real DSP)
  1. Boot and wait one minute: the DSP boots by itself and runs its self-test.
  2. Settings -> Sound: the endpoints "Speakers (Intel SST Loopback)" and
     "Microphone (Intel SST Loopback)"; play a sound; move the volume.
  3. Shut down and send C:\lastboot.log from the stick.
  The line "loopback self-test: ..." in the log is the first self-test on a
  real DSP. The full first-session checklist comes with the P5-H list.
