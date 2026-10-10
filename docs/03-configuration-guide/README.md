# Configuration guide

Order of work: PKI and NTP, Wazuh Manager/Indexer (install per official Wazuh docs for the chosen version), then agent, auditd, and rsyslog. Commands below target Debian/Ubuntu-like systems. Red Hat: `yum`/`dnf`, paths `/var/log/secure` instead of `auth.log`.

Replace every `PLACEHOLDER.*` before restart.

## 1. Time (AU-8)

```bash
timedatectl set-timezone UTC
systemctl enable --now chronyd
chronyc tracking
timedatectl show -p NTPSynchronized --value
```

Expected: `NTPSynchronized=yes`. The Wazuh agent in `configs/wazuh/ossec.conf` runs the same `timedatectl` command every 300 seconds.

## 2. Wazuh Manager: local rules

1. Copy `configs/wazuh/local_rules.xml` to `/var/ossec/etc/rules/local_rules.xml` on the manager.
2. Confirm manager `ossec.conf` has `<rule_dir>etc/rules</rule_dir>` as in `configs/wazuh/ossec.conf`.
3. Do not paste the full repo file over an existing manager `ossec.conf` without a diff. Merge `<remote>`, `<localfile>`, `<indexer>`, and `<ruleset>` section by section.
4. Test syntax and reload rules:

```bash
/var/ossec/bin/wazuh-logtest
systemctl restart wazuh-manager
/var/ossec/bin/wazuh-control status
```

In `wazuh-logtest`: paste an `sshd` “Failed password” line. Expect hit on sid 5716, then 100001 when five lines with the same source IP arrive within 120 s.

## 3. Wazuh agent on Linux endpoint

1. Install the agent from the same major version as the manager (Wazuh packages, not an arbitrary mirror).
2. During install: manager address = FQDN for the 10.20.50.11 sketch, protocol tcp, port 1514.
3. Agent key: `manage_agents` on the manager, import on the agent, or use Wazuh enrollment (5510/tcp) if enabled — enrollment is not configured in repo `ossec.conf`; document the chosen method in the internal runbook.
4. Copy the `<localfile>` blocks for `auth.log`/`secure`, `syslog`, and `audit.log` into `/var/ossec/etc/ossec.conf` on the agent.
5. Start:

```bash
systemctl enable --now wazuh-agent
/var/ossec/bin/wazuh-control status
```

6. On the manager: the agent must show as Active. If missing: check 1514/tcp, DNS, and clock.

## 4. auditd (AU-2, AU-12)

```bash
apt-get install -y auditd audispd-plugins
cp configs/endpoints/auditd.rules /etc/audit/rules.d/99-nist-au.rules
augenrules --load
auditctl -l
```

`auditctl -l` must show watches on `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` and `execve` with keys `identity`, `sudoers`, `execve`. The `-e 2` line in the file locks the ruleset; new rules need a reboot or temporary `auditctl -e 1` after a change window.

The Wazuh agent reads `/var/log/audit/audit.log` with `<log_format>audit</log_format>`.

## 5. Rsyslog TLS 6514 (AU-3, AU-8, AU-9)

### Certificates

Create `/etc/rsyslog.d/tls/` with `ca.pem`, `client-cert.pem`, `client-key.pem`. Permissions: key `640`, owner `root:root` or `syslog`. CN/SAN on the server certificate must match `StreamDriverPermittedPeers` and `target` in `configs/endpoints/rsyslog.conf`.

### Package

```bash
apt-get install -y rsyslog rsyslog-gnutls
```

On RHEL: `rsyslog-gnutls` and optionally `rsyslog-openssl` depending on `StreamDriver`. Repo files use `gtls`.

### Configuration

1. Back up `/etc/rsyslog.conf`.
2. Merge `configs/endpoints/rsyslog.conf` (prefer a drop-in under `/etc/rsyslog.d/60-siem.conf` over replacing the distro file blindly).
3. Set `target` and `StreamDriverPermittedPeers` to the manager/relay FQDN.
4. Validate and reload:

```bash
rsyslogd -N1
systemctl restart rsyslog
ss -lntp | grep 6514 || true
```

`-N1` checks syntax. 6514 listens on the *receiver*, not the endpoint. From the endpoint: `openssl s_client -connect PLACEHOLDER.host.example.internal:6514 -CAfile /etc/rsyslog.d/tls/ca.pem`.

### Relay for network devices

On 10.20.40.10: install the same TLS modules, copy `configs/network/rsyslog-network.conf` to `/etc/rsyslog.d/50-network-relay.conf`, create `/var/log/network` mode 0750, restart. Switches point syslog at the relay’s 514. The relay forwards on 6514.

## 6. Rule tuning

- Level: 100009 is 3 (noise). 100002 and 100004 are 12 (escalation). Adjust `level` in `local_rules.xml`, restart manager, see `docs/05-post-mortem-lessons`.
- Frequency: 100001 needs 5 hits on sid 5716 within 120 s, same IP. A low-rate SSH scanner will not fire; that is intentional.
- Field `audit.key`: must be exactly `identity` / `sudoers` / `execve` as in `auditd.rules` (`-k`).

## 7. Indexer TLS

`<indexer><hosts>` in `ossec.conf` points at `https://PLACEHOLDER.indexer.example.internal:9200` with CA/cert/key under `/etc/filebeat/certs/`. Filebeat (or the Wazuh indexer integration for your version) needs valid files; they are not versioned in this git tree.

## Pre-production checklist

- [ ] No `PLACEHOLDER` in files actually deployed on hosts
- [ ] `bash scripts/validate_configs.sh` is green in the repo
- [ ] Agent Active, NTP synced, TLS handshake 6514 OK
- [ ] Lab tests 1 and 2 in `docs/04-testing-verification` run; screenshots under `assets/sprint-X/`
