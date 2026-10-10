# MT7902 Fixed Driver for Kernel 6.1x

Fixed out-of-tree driver for **MediaTek MT7902** PCIe WiFi on **Linux kernel 6.10–6.14**.

## What's fixed

The upstream driver has a version-gated check in `mt76_vif_phy()` (`src/mac80211.c`) that only runs on kernel ≥ 6.15:

```c
#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 15, 0))
    if (!hw->wiphy->n_radio)
        return hw->priv;
#endif
```

On kernel 6.1x this code is compiled out, so `mt76_vif_phy()` returns `NULL` when there's no channel context yet — causing `mt76_sta_state()` to return `-EINVAL`. The result is the WiFi card can scan networks but **never connects**, spamming `dmesg` with:

```
wlo1: failed to insert STA entry for the AP (error -22)
```

**Fix**: removed the `#if`/`#endif` guard. The `n_radio` field exists on all supported kernels and is 0 for single-radio devices like MT7902, so the fallback to `hw->priv` is always correct.

## Installation

```bash
git clone https://github.com/qtungnui07/mt7902_fixed_kernel_6.1x.git
cd mt7902_fixed_kernel_6.1x
sudo ./install.sh
```

The install script will:
- Check and install build dependencies (headers, gcc, make)
- Build the driver for your running kernel
- Install the module and firmware
- Load the driver

Logs are saved to `/tmp/mt7902_install_*.log`.

## Uninstall

```bash
sudo ./uninstall.sh
```

## Manual build

```bash
make -j$(nproc)          # build only
sudo make install        # install module
sudo make install_fw     # install firmware
sudo make uninstall      # remove module
sudo make uninstall_fw   # remove firmware
```

## DKMS

```bash
sudo dkms add .
sudo dkms build mt7902e/git
sudo dkms install mt7902e/git
```

## Credits

- [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902) — original out-of-tree driver (backport of mainline mt76 with MT7902 patches)
- [abdullaabdullazade/mt7902_driver](https://github.com/abdullaabdullazade/mt7902_driver) — latest upstream with install script and multi-kernel support
- [MediaTek MT7902 patch series](https://lore.kernel.org/all/20260219004007.19733-1-sean.wang@kernel.org/) — original kernel patches by Sean Wang

## License

GPL-2.0-only (same as the Linux kernel)
