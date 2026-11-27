#!/bin/bash
# s4b.sh -- S4b on a boot of its own: crash-notification injected at the first open of the render
# stream while dsploop runs; the run must end by itself; the next run is tried at once, then after
# a disable/enable cycle of the DSP device (whatever the device answers); ended by the power button.
set -u
RUN="${RUN:-r-s4b}"
. /tmp/c6g/tools/r2-common.sh
log "s4b: $RUN on disk/$OVERLAY.qcow2 (BootDsp = 1 and the topology, set in the guest by the first VM)"
session
cmd s4b-enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
log "the endpoints the guest lists: $(pouch_text s4b-enum-endpoint.txt | grep -c 'Loopback') Loopback lines"
runfault s4b-crash-notification crash-notification 1 "$RUNMAX"
g shot s4b-after >/dev/null
mustpass s4b-recovered
s5
log "s4b done"
