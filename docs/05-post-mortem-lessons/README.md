# Lessons from setup and lab

Notes below are from concrete troubleshooting, not framework filler.

## 1. Timestamps: NTP vs UTC offset

**Symptom:** The same sshd event got three times: journal with local offset `+02:00`, auditd `msg=audit(epoch)`, Indexer document with `timestamp` one hour before the Dashboard clock. Correlation 100010 (success after failure within 300 s) missed because the manager compared agent time with syslog time.

**Cause:** Endpoint had `timedatectl` timezone Europe/Oslo, rsyslog used default `RSYSLOG_TraditionalFileFormat` (local time without T separator), Wazuh Dashboard uses the browser timezone, Indexer stores UTC. NTP looked “green” but `NTPSynchronized` flipped to `no` after a VM clock jump.

**Fix:**

- `timedatectl set-timezone UTC` on manager, indexer, relay, and endpoint.
- Template `date-rfc3339` in `configs/endpoints/rsyslog.conf` and `configs/network/rsyslog-network.conf`.
- chrony with internal NTP; check `chronyc tracking` (Last offset).
- Agent command every 300 s in `ossec.conf`: `timedatectl show -p NTPSynchronized --value`.
- Dashboard: User settings → timezone UTC in lab so screenshots match the ISO strings in `docs/04-testing-verification`.

After that, `decoder.timestamp` and `raw` stayed within one second for sshd. auditd epoch is converted by the Wazuh decoder; do not force RFC 3339 into audit.log itself.

## 2. Regex and decoders against odd lines

**Symptom:** A firewall sent BSD syslog without hostname, only `<%PRI%>msg`. The relay wrote `%HOSTNAME%` as the relay’s own name. The Wazuh pre-decoder took the nested relay name as `program_name`. SSH lines that arrived *via* the relay did not hit sid 5716.

**Cause:** `imudp` + default template. Also: Ubuntu `sshd` via systemd journal can emit `sshd[pid]: error: kex_exchange_identification: Connection closed by remote host` without `Failed password`. 5716 requires authentication failure, not a KEX abort.

**Fix:**

- Network relay: template `NetRawFile` with `%fromhost-ip%` (`configs/network/rsyslog-network.conf`) so source IP survives.
- Do not parse KEX noise as brute-force. 100001 hangs on sid 5716, not on 5758/connection reset.
- Run `wazuh-logtest` on the actual raw line before changing a rule. Wrong approach: guessing `<match>` against a log you have not seen.
- For auditd: the Wazuh field is `audit.key`, not `key`. A local rule with `<match>key=identity</match>` against full_log worked in lab until the JSON field was used; `<field name="audit.key">^identity$</field>` is what `local_rules.xml` has now.

## 3. Noise and level tuning

**Symptom after first agent rollout:** 100004 (sudo to root, level 12) filled the queue. Every `apt` and every Ansible playbook that runs `sudo` became “unauthorized sudo”. 100007 (`execve` on `/usr/bin/sudo`) amplified this. SOC ignored level 12 within two days.

**Fix:**

- 100009 (successful SSH) set to level 3 on purpose: visible in `logall_json`/archive, not as email (`email_alert_level` 12 in `ossec.conf`).
- 100004 kept at 12 only in lab. In production: raise `<if_sid>5402</if_sid>` with `<user>` exceptions or `<hostname>` for known jump hosts, or drop to 6 and leave 100008 (not in sudoers) at 12.
- 100007 level 7: visible in Indexer, not a SOS alert. An execve watch on *all* execve in `auditd.rules` is data-heavy; disk and CPU on auditd rose noticeably. If volume chokes `audit.log`, tighten with `-F uid>=1000` or drop global execve and keep watches on sudoers/passwd.
- 100001 frequency 5 / 120 s filters single failures. Do not reduce to 2 without accepting scanner noise.
- After every level change: restart wazuh-manager and re-run scenarios 1 and 2. Do not trust that old alerts in Indexer reflect the new XML.

## Ops not in the code

Retention (AU-11) and disk alerting (AU-4/AU-5) are not set in `ossec.conf`. Indexer ILM/ISM and an alert on full `/var/ossec/logs` must land in internal ops, or AU-12 stops in practice when the disk fills.
