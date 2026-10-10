# Testing and verification

Two controlled lab exercises. Goal: confirm the auditd/rsyslog/agent → Manager → Indexer chain fires **existing** rules in `configs/wazuh/local_rules.xml`. Run only against your own lab hosts. Detailed attack procedures and exploit code do not belong in this repo.

Upload screenshots under `assets/sprint-X/` when the exercise has been run. Until then, placeholders stand.

Shared prerequisites: agent Active, `augenrules --load` OK, UTC on all nodes.

---

## Scenario 1 — SSH: many failed passwords (rules 100001 / 100002)

**Control:** AU-6, AU-12.  
**Files:** `configs/wazuh/ossec.conf` (`<localfile>` `auth.log`/`secure`), `configs/wazuh/local_rules.xml` (100001, 100002, parent sid 5716).  
**Lab:** isolated VLAN. Client generates repeated failed SSH authentications against lab sshd. In the lab, Hydra was used only as a load generator against our own host; tool commands and wordlists are not in this repo. Service `sshd` must log `Failed password` / `pam_unix(sshd:auth): authentication failure`.

**Threshold to hit:** rule 100001: five hits on sid 5716 from the same source IP within 120 seconds. Rule 100002: two such 100001 events within 180 s.

### Raw log (journal/auth.log, RFC 3339 after rsyslog template)

Example line format after `FileISO8601` is active (hostname and IP are lab):

```
2026-10-03T20:14:01.112345+00:00 lab-ssh.example.internal sshd[2144]: Failed password for invalid user deploy from 10.20.30.88 port 53144 ssh2
2026-10-03T20:14:03.440192+00:00 lab-ssh.example.internal sshd[2144]: Failed password for invalid user deploy from 10.20.30.88 port 53144 ssh2
2026-10-03T20:14:05.018001+00:00 lab-ssh.example.internal sshd[2150]: Failed password for invalid user deploy from 10.20.30.88 port 53150 ssh2
2026-10-03T20:14:07.201448+00:00 lab-ssh.example.internal sshd[2150]: Failed password for invalid user deploy from 10.20.30.88 port 53150 ssh2
2026-10-03T20:14:09.773002+00:00 lab-ssh.example.internal sshd[2158]: Failed password for invalid user deploy from 10.20.30.88 port 53158 ssh2
```

Wazuh decoder `sshd` maps this to sid **5716**. The fifth line inside the window must yield **100001** (level 10). Continued failures in a new window: **100002** (level 12).

### Expected hit in Wazuh

| Field | Value |
| --- | --- |
| rule.id | 100001 then 100002 |
| rule.level | 10 / 12 |
| data.srcip | 10.20.30.88 |
| agent.name | lab-ssh host |
| decoder.name | sshd |

Dashboard search (Indexer): `rule.id: 100001 OR rule.id: 100002`.

![EVIDENCE MISSING: auth.log excerpt with at least five Failed password from same IP and ISO 8601 time](../../assets/sprint-4/scenario1-authlog.png)

![EVIDENCE MISSING: Wazuh Dashboard Security Events, alerts 100001 and 100002 with srcip 10.20.30.88](../../assets/sprint-4/scenario1-rule-100001.png)

![EVIDENCE MISSING: Dashboard visualization of SSH failures per source IP last hour](../../assets/sprint-4/scenario1-ssh-failures.png)

**Negative test:** a single failed-password line must yield 5716, not 100001.

---

## Scenario 2 — Change to `/etc/shadow` (rule 100005)

**Control:** AU-2, AU-3, AU-12.  
**Files:** `configs/endpoints/auditd.rules` (`-w /etc/shadow -p wa -k identity`), `configs/wazuh/ossec.conf` (`log_format=audit`), `configs/wazuh/local_rules.xml` (100005).

**Lab:** on your own lab host, in a change window, perform an *authorized* administrative write to identity files (for example `vipw`/`chpasswd` during maintenance) so auditd produces `key="identity"`. Goal is detection, not bypass of access control.

### Raw log (`/var/log/audit/audit.log`)

Expected pattern (fields truncated; inode and session vary):

```
type=SYSCALL msg=audit(1762112100.441:8841): arch=c000003e syscall=2 success=yes exit=7 a0=... ppid=1 pid=9022 auid=1000 uid=0 gid=0 euid=0 ses=3 comm="passwd" exe="/usr/bin/passwd" key="identity"
type=PATH msg=audit(1762112100.441:8841): item=0 name="/etc/shadow" nametype=NORMAL cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0
```

`msg=audit(SECONDS.NANO:SERIAL)` is auditd’s epoch format. The rsyslog template wraps journal lines in RFC 3339; the agent with `log_format=audit` parses SYSCALL directly.

### Expected hit in Wazuh

| Field | Value |
| --- | --- |
| rule.id | 100005 |
| rule.level | 12 |
| decoder.name | auditd |
| audit.key | identity |
| audit.exe / data.audit.file.name | passwd / `/etc/shadow` |

Search: `rule.id: 100005 AND audit.key: identity`.

Also: `visudo` or a write under `/etc/sudoers` must yield **100006** (`key=sudoers`). `sudo` as a command can yield **100007** when `audit.exe` matches `/usr/bin/sudo` and key `execve`.

![EVIDENCE MISSING: audit.log SYSCALL+PATH against /etc/shadow with key=identity](../../assets/sprint-3/scenario2-audit-shadow.png)

![EVIDENCE MISSING: Wazuh alert 100005 with decoder auditd and key identity](../../assets/sprint-4/scenario2-rule-100005.png)

![EVIDENCE MISSING: Dashboard FIM/audit view for identity events](../../assets/sprint-4/scenario2-identity.png)

**Negative test:** reading `/etc/shadow` without `w`/`a` must not trigger the watch (`-p wa`). `cat /etc/shadow` as root may still produce other syscall noise if the execve rule is broad; 100005 must not fire without `key=identity`.

---

## Cross-check against validation script

After documentation and config are saved:

```bash
bash scripts/validate_configs.sh
```

The script does not check that the lab exercise was run; it checks that files exist, XML parses, and markdown is free of banned phrases. Missing PNGs are expected until evidence is uploaded.
