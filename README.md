# Azure Network Security Lab

A small segmented network in Azure that I attack myself, then detect and block those attacks in Microsoft Sentinel. Telemetry also feeds my [Cloud SIEM project](https://github.com/krishpuw/AWS_SOC_SIEM). An LLM firewall joins the lab later so AI attacks land in the same SIEM.

All attacks run only against VMs I own inside this lab's VNet.

## Repo layout

```
infra/          Bicep for VNet, subnets, NSGs, VMs
attacks/        commands and Metasploit resource scripts
pcaps/          captured traffic
detections/     KQL rules
reports/        incident reports
llm-firewall/   FastAPI proxy, rules, classifier, logging
```

## Build order

- [x] 1. Bicep for VNet, subnets, NSGs ([infra/](infra/README.md))
- [ ] 2. Cowrie honeypot -> Sentinel log pipeline
- [ ] 3. Kali + targets, first attack with Wireshark capture and KQL alert
- [ ] 4. Logic App auto-block playbook
- [ ] 5. Remaining attack scenarios and incident reports
- [ ] 6. LLM firewall MVP and its detections
- [ ] 7. Defender for Cloud, Azure Policy, Key Vault extras
- [ ] 8. Architecture diagram, resume bullets
