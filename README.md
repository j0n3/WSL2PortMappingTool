# WSL2PortMappingTool [Work In progress]
Manage Windows firewall rules and port forwardings to expose a port in your WSL2 machine.

Tested in Windows 10

```
Firewall Rules and Port Forwardings for WSL2
--------------------------------------------------
Firewall Rule: Allowing LAN connections to port 5000
    0.0.0.0:5000 to localhost:5000


1) Create new rule and port forwarding
2) Delete an existing rule
3) Display Firewall Rule for port
4) Display all Firewall rules "Allowing LAN connections to port *"
5) Display all port forwardings
0) Exit

Choose an option:
```

# Other useful commands
To add or remove rules administrative privileges are required.
Adding or deleting rules persist over reboots and can imply a security risk or
cause applications to stop working. Use this at your own risk.

## Firewall

### All rules backup export
`netsh advfirewall export "firewall_rules_backup.wfw"`
### Import backup
`netsh advfirewall import "firewall_rules_backup.wfw"`
### Show all firewall rules
`netsh advfirewall firewall show rule name=all`
### Show all rules matching a pattern
`netsh advfirewall firewall show rule name=all | find "Allowing LAN connections to port"`
### Show config for a single rule
`netsh advfirewall firewall show rule name="Allowing LAN connections to port 5000"`
### Add an in rule open for everyone
`netsh advfirewall firewall add rule name="Allowing LAN connections to port 5000" dir=in action=allow protocol=TCP localport=5000`
### Add an in rule for a single ip
`netsh advfirewall firewall add rule name="Allowing LAN connections to port 5000" dir=in action=allow protocol=TCP localport=5000 remoteip=192.168.1.83/32`
### Delete a rule
`netsh advfirewall firewall delete rule name="Allowing LAN connections to port 5000"`

## Port forwarding
### Show all forwardings
`netsh interface portproxy show all`
### Add forwarding
`netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=5000 connectaddress=localhost connectport=5000`
### Delete forwarding
`netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=5000`

# Credits
Thanks to ChatGPT :)
