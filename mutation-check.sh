#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# mutation-check.sh — AC1's mutation check: break one piece of the model at a
# time, rebuild the series with the mutation, run the qtest, and record which
# cases go red.  A mutation that leaves the suite green is a survivor and is
# reported as such.  Runs on a throw-away git worktree; master is untouched.
# usage: mutation-check.sh [out.md]   (default: evidence/<date>/mutation-check.md)
#
# The detector's rules (kept from the earlier rounds):
#  - the qtest aborts at its first failed assertion, so a KILLED row names
#    that first red case and, when it was not the last, says how many of the
#    M cases ran: the cases after it were not evaluated by that mutation;
#  - a run that ends with no "not ok" line but a non-zero exit (a timeout, a
#    crash) is an abort: reported as KILLED (aborted) with its reason, never
#    as a survivor.  A survivor is a zero exit with M "ok" lines and nothing
#    else, and only the un-mutated model produces that;
#  - every cell is one line of at most 200 characters, with the table's
#    separator replaced, so the table stays a table whatever the qtest prints;
#  - a row is "name|file|sed expression|what it breaks" split on "|": no
#    expression may contain it (use "." for one character, or rewrite), and
#    the expression's delimiter must not occur in its text.
#  - the build and the qtest run in the main build/ directory: after the
#    check it holds the last mutation, so build.sh is run again afterwards.
#    A run's output is kept up to LOGMAX bytes (a mutant that prints without
#    end must not fill the disk); a run cut by the cap counts as an abort.
#  - a row whose mutation makes the emulator itself die (a segfault on a
#    malformed image) ends the qtest without a "not ok" line: it is one of
#    the aborts above.
#  - SELFTEST=1 runs the detector on synthetic logs (a clean run, a red run
#    that stops early, a timeout, a crash, a truncated run) and fails if any
#    verdict is wrong; it builds nothing.
#
# This work is licensed under the terms of your GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
SRC="$PWD/src/qemu-11.1.3"
OUT="${1:-$PWD/evidence/$(date -u +%F)/mutation-check.md}"
C='hw/audio/intel-hda-ace.c'
R='hw/audio/intel-hda-ace-regs.h'

# name|file|sed expression (applied to the file)|what it breaks
MUTATIONS=(
"ack-sense|$C|s#s->xtdr \&= ~ACE_HFIPCXTDR_BUSY;#s->xtdr = s->xtdr;   /* MUTATED */#|the host's acknowledgement of a notification never clears BUSY"
"done-polarity|$C|s#s->xida \&= ~ACE_HFIPCXIDA_DONE;#s->xida = s->xida;   /* MUTATED */#|the DONE bit is never cleared by the host"
"fsr-order|$C|s/ace_set_fsr(s, ACE_ROM_LOAD_FW_CODE_TO_IMR, 0, ACE_FSR_MOD_ROM, false);/ace_set_fsr(s, ACE_ROM_FW_LOADING_DONE, 0, ACE_FSR_MOD_ROM, false);/|the ROM walk emits FW_LOADING_DONE before FW_CODE_TO_IMR"
"fsr-running|$C|s/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_BASE_FW, true \/\* running \*\/);/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_ROM, false);/|the firmware never writes its running status word: the FSR stays the ROM's after FW_READY"
"fsr-entry-running|$C|s/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_ROM, false);/ace_set_fsr(s, ACE_FSR_FW_ENTERED, 0, ACE_FSR_MOD_BASE_FW, true);/|FW_ENTERED carries the running bit in the same instant (the single-instant model the LiberNT driver read as a halt)"
"spib-cut|$C|s#left = spib ? MIN(spib, total) : total;#left = total;   /* MUTATED */#|SPIB ignored: the ROM consumes the whole buffer"
"tag-mask|$R|s/0x00001e00u/0x0000fe00u/|the purge request's tag field read as bits 15:9"
"cpd-length|$C|s/hdr_len = ace_payload_u8(s, off + ACE_RI_CPD_HEADER_LENGTH);   \/\* a byte \*\//hdr_len = ace_payload_u8(s, off + ACE_RI_CPD_HEADER_LENGTH + 2);/|the partition directory header length misread"
"ame-magic|$R|s/0x454d4124u/0x314d4524u/|the module entry magic wrong"
"rom-control-target|$C|s/!(primary \& ACE_IPC4_MSG_TARGET_MASK) \&\& type == ACE_IPC4_GLB_ROM_CONTROL/(primary \& ACE_ROM_IPC_CONTROL)/|ROM control detected by the type bit alone (module messages too)"
"running-guard|$C|s/if (s->state != ACE_LOADING \&\& s->state != ACE_RUNNING) {/if (s->state != ACE_LOADING) {/|the FW_READY step skipped once the firmware runs"
"irq-gating|$C|s#level = enabled \&\& (s->xctl \& ACE_HFIPCXCTL_BUSY);#level = enabled;   /* MUTATED */#|the busy interrupt enable ignored"
"powered-down|$C|s#    return s->powered_down_value;#    return 0;   /* MUTATED */#|x-powered-down-value ignored"
"intipptr-unpowered|$C|s/val = ace_powered(s) ? ACE_MODEL_INTIPPTR : 0xffffffffu;/val = ACE_MODEL_INTIPPTR;/|the interrupt pointer answers while unpowered (R1 of the driver review invisible again)"
"personality-id|$C|s/k->device_id = 0x7f50;/k->device_id = 0x7e28;/|the default personality's PCI id"
"version-stream|$C|s#    memcpy(ver, s->fw_version, sizeof(ver));#    ver[0] = 2; ver[1] = 15; ver[2] = 0; ver[3] = 1;   /* MUTATED */#|the reply's version hardcoded instead of read from the stream"
"delay-scale|$C|s#return (uint64_t)(us \* 1000.0 \* s->delay_scale);#return us * 1000;   /* MUTATED */#|x-delay-scale ignored"
"core-before-subsys|$C|s/if ((s->dsp2cxctl \& ACE_DSP2CXCTL_SPA) \&\&/if (0 \&\& (s->dsp2cxctl \& ACE_DSP2CXCTL_SPA) \&\&/|a core request made before the subsystem is up is dropped"
"reply-dir|$C|s/ACE_IPC4_MSG_DIR_REPLY . (status \& ACE_IPC4_REPLY_STATUS_MASK)/(status \& ACE_IPC4_REPLY_STATUS_MASK)/|the reply's direction bit missing"
"abi-fault|$C|s/s->fault_id == ACE_FAULT_ABI ? s->fault_arg : ACE_IPC4_FW_REGS_ABI_VER/ACE_IPC4_FW_REGS_ABI_VER/|the abi= fault not applied to the register block"
"init-done-delay|$C|s/define ACE_US_ROM_INIT_DONE      500/define ACE_US_ROM_INIT_DONE      300/|INIT_DONE 200 us early"
"fw-ready-delay|$C|s/define ACE_US_FW_READY           200/define ACE_US_FW_READY           100/|FW_READY 100 us early"
"fw-running-early|$C|s/define ACE_US_FW_RUNNING         2000/define ACE_US_FW_RUNNING         200/|the firmware's status word written with FW_READY (the ROM's FW_ENTERED no longer readable for a host poll)"
"purge-tag-plus|$C|s/ACE_ROM_IPC_STREAM_TAG_SHIFT) + 1;/ACE_ROM_IPC_STREAM_TAG_SHIFT);/|the purge tag off by one"
"win0-mirror|$C|s/stl_le_p(s->ram\[0\] + ACE_FWREG_FSR, s->fsr);/stl_le_p(s->ram\[0\] + ACE_FWREG_FSR, 0);/|window 0 no longer mirrors the FSR"
"ppl-running-guard|$C|s/if (state == ACE_IPC4_PIPE_RUNNING \&\& p->state != ACE_IPC4_PIPE_PAUSED) {/if (false) {/|a pipeline asked to run is never refused: the paused-before-running rule gone"
"ppl-state-tracked|$C|s/        p->state = state;/        ;/|the pipeline's state is never stored: a pipeline that was asked to pause is still uninitialized when asked to run"
"ppl-create-tracked|$C|s/        p->used = true;/        ;/|create does not add the pipeline to the table"
"ppl-delete-tracked|$C|s/        p->used = false;/        ;/|delete does not remove the pipeline from the table"
"ppl-instance-shift|$R|s/ACE_IPC4_PIPE_INSTANCE_SHIFT     16/ACE_IPC4_PIPE_INSTANCE_SHIFT     15/|the pipeline instance id read from bits 22:15 (pipeline 16 decodes past the limit)"
"ppl-state-decode|$C|s/uint32_t state = primary \& ACE_IPC4_PIPE_STATE_MASK;/uint32_t state = (primary >> 8) \& ACE_IPC4_PIPE_STATE_MASK;/|the pipeline state read from the wrong bits"
"ppl-status-five|$R|s/ACE_IPC4_ILLEGAL_TRANSITION      5/ACE_IPC4_ILLEGAL_TRANSITION     12/|the illegal transition answers 12 instead of the plan's 5"
"ppl-id-range|$C|0,/return ACE_IPC4_ERROR_INVALID_PARAM;/s//return ACE_IPC4_SUCCESS;/|an instance id out of range (0, 17) is answered 0 instead of 1"
"ppl-limit|$R|s/ACE_MODEL_MAX_PIPELINES          16/ACE_MODEL_MAX_PIPELINES          32/|the pipeline count of the model doubled: instance 17 is accepted"
"ppl-exists|$C|s/return ACE_IPC4_RESOURCE_ID_EXISTS;/return ACE_IPC4_SUCCESS;/|a second create of an instance id answers 0 instead of 10"
"ppl-missing|$C|s/return ACE_IPC4_INVALID_RESOURCE_ID;/return ACE_IPC4_SUCCESS;/|a set-state or delete of a pipeline that does not exist answers 0 instead of 9"
"ppl-table-clear|$C|s/ace_ppl_clear(s);/;/g|the pipeline table is never cleared: it survives a power cycle"
"ppl-multi-flag|$C|s/if (ext \& ACE_IPC4_PIPE_STATE_EXT_MULTI) {/if (false) {/|the multi-pipeline form of set-state is taken for a single pipeline's"
"ppl-target-check|$C|s/return !module_msg \&\& (/return (/|a module-space message of a pipeline's type number is taken for a pipeline message"
"ipc-reply-delay|$C|s/define ACE_US_IPC_REPLY           50/define ACE_US_IPC_REPLY           40/|a pipeline reply 10 us early (the FW_CONFIG reply's delay no longer the model's)"
"fault-applies-all|$C|s/return !s->fault_typed .. s->fault_type == type;/return true;/|a fault that names a message type applies to every type"
"fault-ipc-status-all|$C|s/               ace_fault_applies(s, type);/               true;/|ipc-status=<n>:<type> answers every type with the status"
"fault-never-reply-all|$C|s/(s->fault_id == ACE_FAULT_NEVER_REPLY \&\& ace_fault_applies(s, type))) {/(s->fault_id == ACE_FAULT_NEVER_REPLY)) {/|never-reply=<type> drops every request"
"fault-type-off-by-one|$C|s/    s->fault_type = fault_type;/    s->fault_type = (fault_type + 1) \& 0x1f;/|the fault's message type stored one past the one it names"
"judge-count-code|$C|s/ACE_ROM_BASE_FW_NOT_FOUND\(, .partition directory entries.\)/ACE_ROM_CSE_VALIDATION_FAILED\1/|a directory whose entry count lies outside the stream is refused with another code"
"judge-entry-offset-code|$C|s/ACE_ROM_BASE_FW_NOT_FOUND\(, .ADSP.man entry offset.\)/ACE_ROM_IMR_TO_SMALL\1/|an ADSP.man entry whose offset lies outside the stream is refused with another code"
"judge-segment-code|$C|s/ACE_ROM_BASE_FW_NOT_FOUND\(, .module segment flags.\)/ACE_ROM_IMR_TO_SMALL\1/|a module segment whose flags lie outside the stream is refused with another code"
"judge-segment-inverted|$C|s/if (!ace_judge_u32(s, d + ACE_RI_SEGMENT_FLAGS/if (ace_judge_u32(s, d + ACE_RI_SEGMENT_FLAGS/|a segment whose flags were read is refused: every image with a module"
"payload-bounds-wrap|$C|s/off > s->payload_len .. s->payload_len - off < 4/off + 4 > s->payload_len/|the bounds of a payload word checked with a wrapping addition again (the emulator dies on the wrapped offset)"
"segment-end-wrap|$C|s/if (foff > s->payload_len .. len > s->payload_len - foff) {/if (foff + len > s->payload_len) {/|the end of a segment checked with a wrapping addition again"
"gw-forwarding|$C|s/IntelHDAStream \*dst = g->capture >= 0 ? &d->st\[g->capture\] : NULL;/IntelHDAStream *dst = NULL;/|the forwarding removed: the render stream is drained and its position moves, nothing is written into the capture stream"
"gw-tag-mapping|$C|s/unsigned int i, tag = gw_index + 1;/unsigned int i, tag = gw_index;/|the gateway's node index taken for the stream tag itself (the plan's tag minus one gone)"
"gw-position|$C|s/lpib += n;/lpib += 0;/|the positions never advance: LPIB, the position buffer and the extended register stay at 0 while the bytes move"
"gw-position-mirror|$C|s/ace_gateway_position(d, src, dst);/;/|the position buffer's entries never written after a period (LPIB and the extended register still move)"
"gw-interrupts|$C|s/->ctl .= (1u << 26);/;/|the streams' completion bits never set: no period interrupt on either stream"
"fault-never-reply-running-all|$C|s/(s->fault_id == ACE_FAULT_NEVER_REPLY_RUNNING && s->streams_running &&/(s->fault_id == ACE_FAULT_NEVER_REPLY_RUNNING \&\&/|never-reply-running=<type> drops the type's requests before a stream runs too (the stream condition gone)"
"fault-crash-one-late|$C|s/s->stream_replies >= s->fault_arg)/s->stream_replies > s->fault_arg)/|crash-during-stream=<n> crashes one reply late"
)

# the cases of a clean run (the un-mutated test file), for the abort note
M=$(grep -c "qtest_add_func(" "$SRC/tests/qtest/intel-hda-ace-test.c")
LOG="$(mktemp /tmp/mutation-check.XXXXXX.log)"
LOGMAX=$((64 * 1024 * 1024))     # a mutant that prints without end must not fill the disk
trap 'rm -f "$LOG"' EXIT

# one bounded table cell: a single line, the separator replaced, at most $2
# characters; the qtest's source path (of the worktree the mutation built)
# is shortened
cell() {
    printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\//g; s#\.\./src/qemu-11\.1\.3[^/]*/tests/qtest/##' | cut -c1-"$2"
}

# ONLY=<regex>: run just the rows whose name matches (a trial of new rows);
# the un-mutated model is what the counts of a full run refer to
ONLY="${ONLY:-}"

# The verdict of one qtest run from its exit status and its log: the first
# field names the kind (killed, survived or aborted), the rest are the two
# table cells.  A failed case prints "not ok <path>" (GLib's TAP has no
# number there) and is the last line of results, so the cases after it were
# not evaluated; a non-zero exit without such a line is a timeout or a crash.
verdict() {    # $1 = the exit status, $2 = the log
    local rc=$1 log=$2 n_ok n_not ran red note why last

    n_ok=$(grep -cE '^ok ' "$log")
    n_not=$(grep -cE '^not ok ' "$log")
    ran=$((n_ok + n_not))
    if [ "$n_not" -gt 0 ]; then
        red=$(grep -m1 -E '^not ok ' "$log" | sed -E 's#^not ok( [0-9]+)? /x86_64/intel-hda-ace/##; s# - ERROR:[^ ]*intel-hda-ace-test\.c:([0-9]+):# (test line \1) #')
        note=""
        [ "$ran" -lt "$M" ] && note=" -- the run aborted there: cases $((ran + 1))-$M not evaluated"
        printf 'killed\tKILLED\t%s%s\n' "$(cell "$red" 240)" "$note"
    elif [ "$rc" -eq 0 ] && [ "$n_ok" -eq "$M" ]; then
        printf 'survived\t**SURVIVED**\t- (all %d cases ok)\n' "$M"
    else
        case "$rc" in
            124) why="timeout" ;;
            *)   if [ "$rc" -gt 128 ]; then why="killed by signal $((rc - 128))"; else why="exit $rc"; fi ;;
        esac
        last=$(grep -v '^$' "$log" | tail -1)
        printf 'aborted\tKILLED (aborted)\t%s after %d of %d cases, no "not ok" line; last output: %s\n' \
            "$why" "$ran" "$M" "$(cell "$last" 120)"
    fi
}

# SELFTEST=1: the detector on synthetic logs -- a clean run is a survivor, a
# red run that stops early is killed with the cases after it named, and a
# timeout or a crash without a "not ok" line is an abort, never a survivor
if [ "${SELFTEST:-0}" = 1 ]; then
    T=$(mktemp -d)
    trap 'rm -rf "$T"' EXIT
    for i in $(seq 1 "$M"); do echo "ok $i /x86_64/intel-hda-ace/case"; done > "$T/clean"
    { echo "ok 1 /x86_64/intel-hda-ace/enumerate"
      echo "not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3-wt-x/tests/qtest/intel-hda-ace-test.c:42:step: assertion failed (r4(X) == halt | 0x28): (5 == 2147483688)"
      echo "Bail out!"; } > "$T/red"
    : > "$T/timeout"
    echo "ERROR:../x.c:1:qtest: the emulator died" > "$T/crash"
    head -n $((M - 1)) "$T/clean" > "$T/truncated"
    bad=0
    check() {    # $1 = what is fed, $2 = exit status, $3 = the log, $4 = the verdict wanted
        got=$(verdict "$2" "$T/$3" | cut -f1)
        if [ "$got" != "$4" ]; then bad=$((bad + 1)); echo "SELFTEST FAILED: $1 -> $got, wanted $4"; else echo "selftest ok: $1 -> $4"; fi
    }
    check "a clean run (exit 0, M ok lines)" 0 clean survived
    check "a red run that stops at case 2 (exit 134)" 134 red killed
    check "a timeout (exit 124, no output)" 124 timeout aborted
    check "a crash (exit 139, no not-ok line)" 139 crash aborted
    check "a truncated run (exit 0, M-1 ok lines, no not-ok line)" 0 truncated aborted
    check "a red run that reported its failure but exited 0" 0 red killed
    echo "verdict of the red log: $(verdict 134 "$T/red" | cut -f2-)"
    [ "$bad" -eq 0 ] || exit 1
    exit 0
fi

mkdir -p "$(dirname "$OUT")"
printf '# Mutation check of tests/qtest/intel-hda-ace-test.c (%s)\n\n' "$(date -u +%FT%TZ)" > "$OUT"
printf 'Model `%s` (%s); %d mutations, one per row%s; a clean run is %d cases.\n\n' \
    "$(git -C "$SRC" rev-parse --short master)" "$(git -C "$SRC" log -1 --format=%s master | cut -c1-60)" \
    "${#MUTATIONS[@]}" "${ONLY:+ (ONLY=$ONLY: the rows whose name matches)}" "$M" >> "$OUT"
printf '| # | mutation | what it breaks | qtest result | red cases |\n|---|---|---|---|---|\n' >> "$OUT"
n=0; survivors=0; aborted=0; notapplied=0; failed=0
for m in "${MUTATIONS[@]}"; do
    if [ -n "$ONLY" ] && ! grep -qE -- "$ONLY" <<< "${m%%|*}"; then continue; fi
    n=$((n + 1))
    IFS='|' read -r name file expr what <<< "$m"
    WT="$SRC-wt-$name"
    # an interrupted run leaves its worktree locked and half-initialised
    git -C "$SRC" worktree unlock "$WT" >/dev/null 2>&1 || true
    git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1 || true
    if [ -d "$WT" ]; then rm -rf "$WT"; git -C "$SRC" worktree prune; fi
    git -C "$SRC" worktree add -q --detach "$WT" master || { echo "worktree failed for $name" >&2; continue; }
    sed -i "$expr" "$WT/$file"
    if ! git -C "$WT" diff --quiet; then
        git -C "$WT" -c user.name=mutation -c user.email=mutation@localhost commit -q -am "mutation: $name"
    else
        printf '| %d | %s | %s | NOT APPLIED (sed matched nothing) | - |\n' "$n" "$name" "$(cell "$what" 200)" >> "$OUT"
        notapplied=$((notapplied + 1))
        git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1
        continue
    fi
    PD="$PWD/build/mut/$name/patches"; rm -rf "$PWD/build/mut/$name"; mkdir -p "$PD"
    git -C "$WT" format-patch -q v11.1.3..HEAD -o "$PD"
    res=$(PATCHDIR="$PD" bash build.sh 2>&1 | grep -E 'error:|FAILED|build ok' | head -3)
    if ! grep -q 'build ok' <<< "$res"; then
        failed=$((failed + 1))
        printf '| %d | %s | %s | BUILD FAILED: %s | - |\n' "$n" "$name" "$(cell "$what" 200)" "$(cell "$(echo "$res" | tr '\n' ' ')" 120)" >> "$OUT"
    else
        # the run's output is capped (LOGMAX bytes): its exit status is the
        # qtest's own, also when the cap closes the pipe under it
        (cd build && QTEST_QEMU_BINARY=./qemu-system-x86_64 timeout 400 ./tests/qtest/intel-hda-ace-test 2>&1 \
            | head -c "$LOGMAX" > "$LOG"; exit "${PIPESTATUS[0]}"); rc=$?
        got=$(verdict "$rc" "$LOG")
        kind=${got%%$'\t'*}
        cells=${got#*$'\t'}
        case "$kind" in
            survived) survivors=$((survivors + 1)) ;;
            aborted)  aborted=$((aborted + 1)) ;;
        esac
        printf '| %d | %s | %s | %s |\n' "$n" "$name" "$(cell "$what" 200)" "${cells//$'\t'/ | }" >> "$OUT"
    fi
    git -C "$SRC" worktree remove --force "$WT" >/dev/null 2>&1
done
printf '\n%d mutations: %d killed (%d of them by an abort), **%d survived**, %d not applied, %d build failures.\n' \
    "$n" "$((n - survivors - notapplied - failed))" "$aborted" "$survivors" "$notapplied" "$failed" >> "$OUT"
echo "done: $n mutations, $survivors survivors, $notapplied not applied, $failed build failures -> $OUT"
