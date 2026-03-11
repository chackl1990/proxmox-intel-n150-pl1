# Proxmox Intel N150 linear Power Limmit by load1m

Dynamic Intel RAPL power limit controller for Linux.

This project provides a small daemon that automatically adjusts the CPU power limits **PL1** (long-term power limit) and **PL2** (short-term turbo limit) based on the current system load.

It is designed primarily for low-power systems such as:

- Intel N100 / N150
- small NAS systems
- home servers
- Proxmox nodes
- always-on machines

The goal is to **reduce power consumption and heat during idle or low load** while still allowing **higher power limits when the system is under load**.

---

# How it works

The script reads the system load every few seconds and calculates a normalized load value:

```
load_norm = load1 / cpu_count
```

Example:

| load1 | CPU cores | normalized load |
|------|-----------|----------------|
| 0.40 | 4 | 0.10 |
| 1.00 | 4 | 0.25 |
| 2.00 | 4 | 0.50 |

This normalized value is used to calculate the power limits.

Power policy:

```
load_norm < threshold  → MIN_W
load_norm ≥ threshold  → linear scaling up to MAX_W
```

Example configuration:

```
threshold = 0.20
MIN_W = 6W
MAX_W = 9W
```

Result:

| normalized load | PL1 |
|-----------------|----|
| 0.10 | 6W |
| 0.20 | 6W |
| 0.40 | ~7W |
| 0.70 | ~8W |
| 1.00 | 9W |

PL2 is automatically calculated as:

```
PL2 = PL1 + 2W
```

---

# Features

- automatic PL1 scaling
- automatic PL2 adjustment
- load normalized by CPU count
- exponential smoothing to prevent oscillation
- ramp limiting to avoid sudden power jumps
- configurable power limits
- optional silent mode (`--no-output`)
- systemd service included
- safe fallback limits

---

# Installation

You can install the service directly from GitHub using a one-line command - log in as root

```
wget -qO- https://raw.githubusercontent.com/chackl1990/proxmox-intel-n150-pl1/main/install.sh | bash
```

This command will:

1. Download the install script
2. Install the controller script to:

```
/usr/local/bin/rapl-pl1-linear.sh
```

3. Install the systemd service:

```
/etc/systemd/system/rapl-pl1-linear.service
```

4. Reload systemd
5. Enable and start the service automatically

---

# Uninstall

To completely remove the service:
log in as root

```
wget -qO- https://raw.githubusercontent.com/chackl1990/proxmox-intel-n150-pl1/main/uninstall.sh | bash
```

This will:

- stop the service
- disable it
- remove installed files
- reload systemd

---

# Service control

Check service status:

```
systemctl status rapl-pl1-linear
```

Restart service:

```
systemctl restart rapl-pl1-linear
```

Stop service:

```
systemctl stop rapl-pl1-linear
```

---

# Configuration

The configuration is located at the top of the script:

```
/usr/local/bin/rapl-pl1-linear.sh
```

Important parameters:

```
INTERVAL_SEC=10
```

Update interval in seconds.

```
LOAD_THRESH_NORM=0.20
```

Normalized load threshold where scaling begins.

```
MIN_W=6.0
MAX_W=9.0
```

Minimum and maximum PL1 limits.

```
PL2_OFFSET_W=2.0
```

PL2 is calculated as:

```
PL2 = PL1 + offset
```

---

# Requirements

- Linux kernel with **Intel RAPL support**
- `/sys/class/powercap/intel-rapl` available
- root privileges
- systemd

Test RAPL support:

```
ls /sys/class/powercap/intel-rapl:0
```

You should see files such as:

```
constraint_0_power_limit_uw
constraint_1_power_limit_uw
constraint_0_time_window_us
```

---

# Compatibility

Tested on Terramaster F4-425 plus (Intel N150 with Proxmox 9.x)
Other Intel CPUs supporting RAPL should work as well.

---

# Results on Terramaster F4-425 plus

After enabeling the scrip my System with 2xNVME + 1xHDD in sleep got down to a average load of 17.6 Watts keeping the cpu temperature at ~40°C.

---

# Safety

The script includes several safety features:

- PL1 and PL2 are clamped to safe limits
- ramp limiting prevents sudden jumps
- smoothing prevents oscillation
- systemd restart ensures recovery

---

# License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.
