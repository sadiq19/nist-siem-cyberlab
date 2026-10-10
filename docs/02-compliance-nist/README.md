# NIST SP 800-53 Rev. 5 AU vs this repo

The table maps selected AU controls to files under `configs/` and to Wazuh rule IDs where they apply. The CSF 2.0 column is DE/RS subcategories covered by the same technical controls, not a full CSF gap analysis.

Control text is abbreviated. Official wording: NIST SP 800-53 Rev. 5.

| Control | Requirement (short) | Implementation in repo | Evidence / rule |
| --- | --- | --- | --- |
| **AU-2** Event Logging | Define events to log (logon, privilege, identity files). | `configs/wazuh/ossec.conf` `<localfile>` for `auth.log`, `secure`, `syslog`, `audit.log`. `configs/endpoints/auditd.rules`: `-w` on `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `-S execve`. | Rules 100003, 100009 in `configs/wazuh/local_rules.xml`. |
| **AU-3** Content of Audit Records | Record must include type, time, location, source, outcome. | `configs/endpoints/rsyslog.conf` template `FwdRFC5424ISO8601`: PRI, RFC 3339 time, hostname, app-name, procid, msgid, msg. `configs/network/rsyslog-network.conf` templates `NetFwdRFC5424ISO8601` and `NetRawFile` with `%fromhost-ip%`. Auditd SYSCALL fields: uid, exe, key, success. | Raw line in test 2, `docs/04-testing-verification`. |
| **AU-6** Audit Record Review, Analysis, and Reporting | Review and correlate logs; report anomalies. | `configs/wazuh/local_rules.xml` 100001–100002 (SSH failure rate), 100004 and 100008 (sudo), 100010 (success after failure). `ossec.conf` `<alerts>` `log_alert_level` 3. | Dashboard alert: `![EVIDENCE MISSING: Wazuh Dashboard alert for rule 100001 or 100002](../../assets/sprint-4/...)` |
| **AU-8** Time Stamps | Authoritative time source; comparable timestamps. | RFC 3339 in both rsyslog files (`date-rfc3339`). `ossec.conf` `<localfile>` command `timedatectl show -p NTPSynchronized`. Host must run NTP/chrony (see configuration guide). | NTP post-mortem, `docs/05-post-mortem-lessons`. |
| **AU-9** Protection of Audit Information | Protect logs from unauthorized change and interception. | TLS: `StreamDriver="gtls"` port 6514 in `configs/endpoints/rsyslog.conf` and `configs/network/rsyslog-network.conf`. Agent `connection=secure` port 1514 in `ossec.conf`. Relay file mode `fileCreateMode="0640"`. auditd `-e 2` locks the ruleset. | Certificate paths `/etc/rsyslog.d/tls/` (not in git). |
| **AU-12** Audit Record Generation | The system must generate audit records for defined events. | auditd rules loaded with `augenrules`. Wazuh reads `audit.log` (`log_format=audit`). Identity change: rule 100005 (`audit.key` identity). sudoers: 100006. execve sudo/su/visudo: 100007. | Test 2, `![EVIDENCE MISSING: raw audit.log line for key identity or execve](../../assets/sprint-3/...)` |

## Rule ID vs control and file

| Rule ID | File | AU |
| --- | --- | --- |
| 100001, 100002, 100010 | `configs/wazuh/local_rules.xml`, parent sshd 5716/5715; input `auth.log` via `ossec.conf` | AU-6, AU-12 |
| 100003, 100004, 100008 | `local_rules.xml` (5401, 5402, 5407); sudo in syslog | AU-2, AU-6, AU-12 |
| 100005, 100006, 100007 | `local_rules.xml` + `configs/endpoints/auditd.rules` | AU-2, AU-9, AU-12 |
| 100009 | `local_rules.xml` (5715) | AU-2, AU-12 |

## CSF 2.0 (excerpt)

| CSF | Coverage |
| --- | --- |
| DE.CM-01, DE.CM-03 | Continuous monitoring of logon and file change (agent + auditd). |
| DE.AE-02, DE.AE-03 | Event analysis; correlation in 100001/100002/100010. |
| RS.AN-03 | Investigation from alert and raw log in Indexer. |

AU-4 (storage capacity), AU-5 (response to audit failure), and AU-11 (retention) are policy. They are not encoded here; indexer retention and disk quota are set in operations.
