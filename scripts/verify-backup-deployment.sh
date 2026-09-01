#!/bin/bash
# Checks that every artifact docs/backup/README.md specifies actually EXISTS on this
# machine, is executable, and is enabled.
#
# Why this exists: the README was written ahead of the deployment and says so ("must be
# checked as you go"). Three specified artifacts were never deployed, and nothing
# noticed -- including /etc/cron.daily/restic-disk-check, which was mode 0644 so
# run-parts silently skipped it. The alarm built to catch a filling remote was itself
# the thing that failed, and the remote hit 100% before anyone found out.
#
# Every check here is one a human would otherwise have to remember. Read-only: it
# changes nothing. Checks needing root report SKIP rather than failing, so it stays
# useful unprivileged.
#
# Run as your normal user -- root is not required, and sudo breaks the ssh probe
# unless SUDO_USER is honoured (it is, below).
#
# Usage:  scripts/verify-backup-deployment.sh [vps-ssh-host]
#         VPS_HOST=myvps scripts/verify-backup-deployment.sh
set -uo pipefail

VPS="${1:-${VPS_HOST:-}}"

# This script needs no root: every check is read-only and the few that would need
# privilege report SKIP. Run it as yourself. If you do run it under sudo anyway, ssh
# would read /root/.ssh/config and never see the Host aliases in your own config, so the
# VPS probe would report "unreachable" on a perfectly good connection. Drop back to the
# invoking user for the remote probe.
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10)
if [[ -n "${SUDO_USER:-}" && "$(id -u)" -eq 0 ]]; then
    SSH=(sudo -u "$SUDO_USER" -- "${SSH[@]}")
fi
pass=0; fail=0; skip=0; warn=0
if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
else G=''; R=''; Y=''; B=''; N=''; fi

ok()   { printf "  ${G}OK  ${N}  %-44s %s\n" "$1" "${2:-}"; pass=$((pass+1)); }
bad()  { printf "  ${R}FAIL${N}  %-44s %s\n" "$1" "${2:-}"; fail=$((fail+1)); }
skp()  { printf "  ${Y}SKIP${N}  %-44s %s\n" "$1" "${2:-}"; skip=$((skip+1)); }
# NOTE is deliberately not a failure: the thing is deployed, something about it is just
# worth a human glance. Reserve FAIL for "this is definitely broken" -- a checker that
# cries wolf over a correct deployment is one you stop reading.
note() { printf "  ${Y}NOTE${N}  %-44s %s\n" "$1" "${2:-}"; warn=$((warn+1)); }
hdr()  { printf "\n${B}%s${N}\n" "$1"; }

# Checks the file's OWN mode and owner, never whether the invoking user can run it.
# restic-drill.sh is deliberately 0700 root:root because it embeds REST_PASS, so a bare
# [[ -x ]] run as a normal user reports a correct deployment as broken.
script_ok() {  # path, doc-ref, expected-mode
    local path="$1" ref="$2" want="$3" info owner mode
    if ! info=$(stat -c '%U %a' "$path" 2>/dev/null); then
        if [[ -e "$path" ]]; then skp "$path" "$ref -- cannot stat, needs root"
        else bad "$path" "$ref -- missing"; fi
        return
    fi
    owner="${info%% *}"; mode="${info##* }"
    if (( (8#$mode & 8#100) == 0 )); then
        bad "$path" "$ref -- mode $mode: owner cannot execute"
    elif [[ "$owner" != root ]]; then
        note "$path" "$ref -- owned by $owner, expected root"
    elif [[ "$mode" != "$want" ]]; then
        note "$path" "$ref -- mode $mode, expected $want"
    else
        ok "$path" "$ref  root:root $mode"
    fi
}

# repo.pass and the drill embed secrets; group/other must have nothing.
secret_mode() {  # path, doc-ref, expected-mode
    local info mode owner
    info=$(stat -c '%U %a' "$1" 2>/dev/null) || { skp "$1" "$2 -- cannot stat, needs root"; return; }
    owner="${info%% *}"; mode="${info##* }"
    if (( 8#$mode & 8#077 )); then bad "$1" "$2 -- mode $mode is group/other readable"
    elif [[ "$owner" != root ]]; then note "$1" "$2 -- owned by $owner, expected root"
    elif [[ ! "$mode" =~ ^($3)$ ]]; then note "$1" "$2 -- mode $mode, expected $3"
    else ok "$1" "$2  root:root $mode"; fi
}
exists() {
    if [[ -e "$1" ]]; then ok "$1" "$2"
    elif [[ -r "$(dirname "$1")" ]]; then bad "$1" "$2 -- missing"
    else skp "$1" "$2 -- parent unreadable, needs root"; fi
}
timer_on() {
    local state; state=$(systemctl is-active "$1" 2>/dev/null)
    case "$state" in
        active)   ok "$1" "$2" ;;
        inactive|failed) bad "$1" "$2 -- $state" ;;
        *)        bad "$1" "$2 -- not present" ;;
    esac
}

hdr "Home server: binaries (1.5)"
script_ok /usr/local/bin/restic        "1.5" 755
script_ok /usr/local/bin/resticprofile "1.5" 755

hdr "Home server: configuration (1.5, 1.8, 1.9)"
exists /etc/restic/profiles.yaml        "1.9"
secret_mode /etc/restic/repo.pass "1.5" '400|600' 
exists /etc/restic/homelab-excludes.txt "1.8"

hdr "Home server: hook scripts (1.6, 1.7, 5.3)"
script_ok /usr/local/sbin/restic-guard.sh "1.6  mount guard"       755
script_ok /usr/local/sbin/homelab-dump.sh "1.7  dump orchestrator" 755
# 0700: it embeds REST_PASS, so it must not be readable by anyone but root.
script_ok /usr/local/sbin/restic-drill.sh "5.3  quarterly drill"   700

hdr "Home server: timers (1.9, 5.3)"
timer_on resticprofile-backup@profile-homelab.timer    "1.9  nightly backup"
timer_on resticprofile-copy@profile-offsite.timer      "1.9  nightly copy"
timer_on resticprofile-check@profile-maintenance.timer "1.9  weekly check"
timer_on resticprofile-prune@profile-maintenance.timer "1.9  weekly prune"
timer_on restic-drill.timer                            "5.3  quarterly drill"

hdr "Home server: tunnel (1.4)"
timer_on restic-tunnel.service "1.4  ssh -L to the VPS"

# A unit that failed still counts as deployed, but a failed copy means no offsite data.
hdr "Home server: last run state"
for u in resticprofile-backup@profile-homelab.service \
         resticprofile-copy@profile-offsite.service; do
    st=$(systemctl is-failed "$u" 2>/dev/null)
    [[ "$st" == failed ]] && bad "$u" "in FAILED state" || ok "$u" "not failed"
done

if [[ -z "$VPS" ]]; then
    hdr "VPS (1.2, 1.10)"
    skp "VPS checks" "no host given -- pass one as \$1 or set VPS_HOST"
else
    hdr "VPS: $VPS (1.2, 1.10)"
    out=$("${SSH[@]}" "$VPS" '
        printf "ACTIVE=%s\n" "$(systemctl is-active rest-server 2>/dev/null)"
        printf "APPENDONLY=%s\n" "$(systemctl show rest-server -p ExecStart 2>/dev/null | grep -c -- --append-only)"
        printf "MAINTUNIT=%s\n" "$([ -f /etc/systemd/system/rest-server-maintenance.service ] && echo yes || echo no)"
        printf "MAINTON=%s\n" "$(systemctl is-enabled rest-server-maintenance 2>/dev/null || echo not-enabled)"
        printf "DISKEXEC=%s\n" "$([ -x /etc/cron.daily/restic-disk-check ] && echo yes || echo no)"
        printf "DISKRUN=%s\n" "$(run-parts --test /etc/cron.daily 2>/dev/null | grep -c restic-disk-check)"
        printf "USE=%s\n" "$(df --output=pcent /srv 2>/dev/null | tail -1 | tr -dc 0-9)"
    ' 2>/dev/null)
    if [[ -z "$out" ]]; then
        bad "ssh $VPS" "unreachable${SUDO_USER:+ (as $SUDO_USER)}"
    else
        eval "$out"
        [[ "$ACTIVE" == active ]] && ok "rest-server.service" "1.2  running" \
                                  || bad "rest-server.service" "1.2  $ACTIVE"
        # The whole design rests on this: the home server must not be able to delete.
        (( APPENDONLY > 0 )) && ok "rest-server --append-only" "1.2  guard ON" \
                             || bad "rest-server --append-only" "1.2  GUARD IS OFF"
        [[ "$MAINTUNIT" == yes ]] && ok "rest-server-maintenance.service" "1.2  built ahead of need" \
                                  || bad "rest-server-maintenance.service" "1.2  missing -- 5.2 cannot be run"
        [[ "$MAINTON" == enabled ]] && bad "rest-server-maintenance enabled" "1.2  MUST NOT be enabled" \
                                    || ok "rest-server-maintenance disabled" "1.2  correct"
        # Mode 0644 here is why the disk alarm never fired: run-parts skips it silently.
        [[ "$DISKEXEC" == yes ]] && ok "restic-disk-check executable" "1.10" \
                                 || bad "restic-disk-check executable" "1.10  not executable -- never runs"
        (( DISKRUN > 0 )) && ok "run-parts will run disk-check" "1.10" \
                          || bad "run-parts will run disk-check" "1.10  skipped by run-parts"
        if [[ -n "${USE:-}" ]]; then
            (( USE < 70 )) && ok "/srv usage ${USE}%" "1.10  under the 70% trigger" \
                           || bad "/srv usage ${USE}%" "1.10  at/over 70% -- prune per 5.2"
        fi
    fi
fi

hdr "Not checkable here"
skp "emergency diceware key (1.11)" "needs the repo password; verify with 'restic key list'"
skp "restore drill actually passing (5.3)" "HC_DRILL going green is the only proof"

printf "\n${B}%d passed, %d failed, %d noted, %d skipped${N}\n" "$pass" "$fail" "$warn" "$skip"
(( warn > 0 )) && printf "NOTE means deployed but worth a look -- it is not a failure.\n"
(( fail == 0 ))
