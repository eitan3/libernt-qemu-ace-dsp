#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# mutation-check.sh — AC1's mutation check: break one piece of the model at a
# time, rebuild the series with the mutation, run the qtest, and record which
# cases go red.  A mutation that leaves the suite green is a survivor and is
# reported as such.  Runs on a throw-away git worktree; master is untouched.
# usage: mutation-check.sh [out.md]   (default: evidence/<date>/mutation-check.md)
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
SRC="$PWD/src/qemu-11.1.3"
OUT="${1:-$PWD/evidence/$(date -u +%F)/mutation-check.md}"
mkdir -p "$(dirname "$OUT")"
C='hw/audio/intel-hda-ace.c'
R='hw/audio/intel-hda-ace-regs.h'

# name|file|sed expression (applied to the file)|what it breaks
MUTATIONS=(
"ack-sense|$C|s/s->xtdr \&= ~ACE_HFIPCXTDR_BUSY;/s->xtdr = s->xtdr;   /* MUTATED *//|the host's acknowledgement of a notification never clears BUSY"
"done-polarity|$C|s/s->xida \&= ~ACE_HFIPCXIDA_DONE;/s->xida = s->xida;   /* MUTATED *//|the DONE bit is never cleared by the host"
"fsr-order|$C|s/ace_set_fsr(s, ACE_ROM_LOAD_FW_CODE_TO_IMR, 0, ACE_FSR_MOD_ROM, false);/ace_set_fsr(s, ACE_ROM_FW_LOADING_DONE, 0, ACE_FSR_MOD_ROM, false);/|the ROM walk emits FW_LOADING_DONE before FW_CODE_TO_IMR"
"fsr-running|$C|s/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_BASE_FW, true \/\* running \*\/);/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_ROM, false);/|FW_ENTERED without the running bit, module ROM"
"spib-cut|$C|s/left = spib ? MIN(spib, total) : total;/left = total;   /* MUTATED *//|SPIB ignored: the ROM consumes the whole buffer"
"tag-mask|$R|s/0x00001e00u/0x0000fe00u/|the purge request's tag field read as bits 15:9"
"cpd-length|$C|s/hdr_len = ace_payload_u8(s, off + ACE_RI_CPD_HEADER_LENGTH);   \/\* a byte \*\//hdr_len = ace_payload_u8(s, off + ACE_RI_CPD_HEADER_LENGTH + 2);/|the partition directory header length misread"
"ame-magic|$R|s/0x454d4124u/0x314d4524u/|the module entry magic wrong"
"rom-control-target|$C|s/!(primary \& ACE_IPC4_MSG_TARGET_MASK) \&\& type == ACE_IPC4_GLB_ROM_CONTROL/(primary \& ACE_ROM_IPC_CONTROL)/|ROM control detected by the type bit alone (module messages too)"
"running-guard|$C|s/if (s->state != ACE_LOADING \&\& s->state != ACE_RUNNING) {/if (s->state != ACE_LOADING) {/|the FW_READY step skipped once the firmware runs"
"irq-gating|$C|s/level = enabled \&\& (s->xctl \& ACE_HFIPCXCTL_BUSY);/level = enabled;   /* MUTATED *//|the busy interrupt enable ignored"
"powered-down|$C|s/    return s->powered_down_value;/    return 0;   /* MUTATED *//|x-powered-down-value ignored"
"personality-id|$C|s/k->device_id = 0x7f50;/k->device_id = 0x7e28;/|the default personality's PCI id"
"version-stream|$C|s/    memcpy(ver, s->fw_version, sizeof(ver));/    ver[0] = 2; ver[1] = 15; ver[2] = 0; ver[3] = 1;   /* MUTATED *//|the reply's version hardcoded instead of read from the stream"
"delay-scale|$C|s/return (uint64_t)(us \* 1000.0 \* s->delay_scale);/return us * 1000;   /* MUTATED *//|x-delay-scale ignored"
"core-before-subsys|$C|s/if ((s->dsp2cxctl \& ACE_DSP2CXCTL_SPA) \&\&/if (0 \&\& (s->dsp2cxctl \& ACE_DSP2CXCTL_SPA) \&\&/|a core request made before the subsystem is up is dropped"
"reply-dir|$C|s/                  ACE_IPC4_MSG_DIR_REPLY | (status \& ACE_IPC4_REPLY_STATUS_MASK),/                  (status \& ACE_IPC4_REPLY_STATUS_MASK),/|the reply's direction bit missing"
"abi-fault|$C|s/s->fault_id == ACE_FAULT_ABI ? s->fault_arg : ACE_IPC4_FW_REGS_ABI_VER/ACE_IPC4_FW_REGS_ABI_VER/|the abi= fault not applied to the register block"
"init-done-delay|$C|s/define ACE_US_ROM_INIT_DONE      500/define ACE_US_ROM_INIT_DONE      300/|INIT_DONE 200 us early"
"fw-ready-delay|$C|s/define ACE_US_FW_READY           200/define ACE_US_FW_READY           100/|FW_READY 100 us early"
"purge-tag-plus|$C|s/ACE_ROM_IPC_STREAM_TAG_SHIFT) + 1;/ACE_ROM_IPC_STREAM_TAG_SHIFT);/|the purge tag off by one"
"win0-mirror|$C|s/stl_le_p(s->ram\[0\] + ACE_FWREG_FSR, s->fsr);/stl_le_p(s->ram[0] + ACE_FWREG_FSR, 0);/|window 0 no longer mirrors the FSR"
)

printf '# Mutation check of tests/qtest/intel-hda-ace-test.c (%s)\n\n' "$(date -u +%FT%TZ)" > "$OUT"
printf '| # | mutation | what it breaks | qtest result | red cases |\n|---|---|---|---|---|\n' >> "$OUT"
n=0; survivors=0
for m in "${MUTATIONS[@]}"; do
    n=$((n + 1))
    IFS='|' read -r name file expr what <<< "$m"
    WT="$SRC-wt-$name"
    git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1 || true
    git -C "$SRC" worktree add -q --detach "$WT" master || { echo "worktree failed for $name" >&2; continue; }
    sed -i "$expr" "$WT/$file"
    if ! git -C "$WT" diff --quiet; then
        git -C "$WT" -c user.name=mutation -c user.email=mutation@localhost commit -q -am "mutation: $name"
    else
        printf '| %d | %s | %s | NOT APPLIED (sed matched nothing) | - |\n' "$n" "$name" "$what" >> "$OUT"
        git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1
        continue
    fi
    PD="$PWD/build/mut/$name/patches"; rm -rf "$PWD/build/mut/$name"; mkdir -p "$PD"
    git -C "$WT" format-patch -q v11.1.3..HEAD -o "$PD"
    res=$(PATCHDIR="$PD" bash build.sh 2>&1 | grep -E 'error:|FAILED|build ok' | head -3)
    if ! grep -q 'build ok' <<< "$res"; then
        printf '| %d | %s | %s | BUILD FAILED: %s | - |\n' "$n" "$name" "$what" "$(echo "$res" | tr '\n' ' ' | cut -c1-80)" >> "$OUT"
    else
        red=$(cd build && QTEST_QEMU_BINARY=./qemu-system-x86_64 timeout 400 ./tests/qtest/intel-hda-ace-test 2>&1 | grep -E '^not ok' | sed 's/^not ok [0-9]* //' | tr '\n' ';')
        if [ -n "$red" ]; then
            printf '| %d | %s | %s | KILLED | %s |\n' "$n" "$name" "$what" "${red%;}" >> "$OUT"
        else
            survivors=$((survivors + 1))
            printf '| %d | %s | %s | **SURVIVED** | - |\n' "$n" "$name" "$what" >> "$OUT"
        fi
    fi
    git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1
done
printf '\n%d mutations, %d survived.\n' "$n" "$survivors" >> "$OUT"
echo "done: $n mutations, $survivors survivors -> $OUT"
