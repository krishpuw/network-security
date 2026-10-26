using 'main.bicep'

// Copy to main.local.bicepparam (git-ignored) and fill in your own values.
param prefix = 'seclab'

// Your public IP, e.g. '203.0.113.7/32'. Find it with: curl -s https://ifconfig.me
param adminSourceAddress = ''

// Leave empty until the pfSense/OPNsense VM exists, then set its trust NIC IP
// (first usable host in snet-fw-trust is 10.0.1.148) and redeploy.
param firewallTrustIp = ''
