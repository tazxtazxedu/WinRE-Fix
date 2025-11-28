# WinRE-Fix

> PowerShell script to safely move/recreate Windows Recovery Environment (WinRE) to a new Recovery partition.

---

## ⚠️🔴 BACKUP WARNING / YEDEK UYARISI 🔴⚠️

| 🇹🇷 Türkçe | 🇬🇧 English |
|------------|-------------|
| **Bu script'i çalıştırmadan önce mutlaka tam sistem yedeği alın!** Disk/partition işlemleri geri dönüşü olmayan veri kaybına yol açabilir. | **Take a full system backup before running this script!** Disk/partition operations can cause irreversible data loss. |

---

## 🇹🇷 Türkçe

### Özet

`Winre-Fix.ps1` Windows Recovery Environment (WinRE) bileşenini güvenli bir şekilde yeni bir Recovery partition'a taşıyan/yeniden oluşturan bir PowerShell betiğidir.

### Gereksinimler
- Windows 10/11 (reagentc aracı mevcut olmalı)
- **Yönetici (Administrator)** hakları ile çalıştırma zorunludur
- PowerShell 5.1 veya PowerShell 7+

### ⚠️ Önemli Uyarılar
- **Yedek alın!** Partition ve disk işlemleri veri kaybına yol açabilir.
- Önce `-WhatIf` ile simülasyon çalıştırın.
- Script sadece **Disk 0** üzerinde çalışır.

### Parametreler

| Parametre | Açıklama |
|-----------|----------|
| `-WhatIf` | Gerçek değişiklik yapmadan adımları simüle eder (güvenli test modu) |
| `-Force` | Onay istemeden tüm adımları uygular + minimum alan uyarılarını geçer |
| `-Verbose` | Ayrıntılı çıktı/log için verbose modu |

### Script Akışı

```
1. PRE-CHECK: Disk 0'da "Unallocated" (boş) alan var mı?
   ├─ Yok → HATA: "No unallocated space found" → Çıkış
   ├─ < 1.2 GB → Uyarı, -Force gerekli
   └─ >= 1.2 GB → OK, devam
        ↓
2. Yedek onayı iste (YES yazılmalı, -Force/-WhatIf ile atlanır)
        ↓
3. Recovery partition'ı bul (GPT Type ile tüm partition'ları tarar)
   ├─ Bulunamadı → HATA → Çıkış
   └─ Bulundu → OK, devam
        ↓
4. Partition doğrulama (boyut < 10 GB olmalı)
   ├─ Çok büyük → HATA: "Too large, might be Windows!" → Çıkış
   └─ OK → devam
        ↓
5. WinRE disable et (reagentc /disable)
        ↓
6. Eski Recovery partition'ı sil
        ↓
7. C: sürücüsünü genişlet (1 GB rezerv bırakır)
        ↓
8. Yeni Recovery partition oluştur + NTFS formatla
        ↓
9. GPT Type + Hidden attribute ayarla (diskpart)
        ↓
10. WinRE enable et (reagentc /enable)
        ↓
   TAMAMLANDI!
```

### Örnek Kullanım

```powershell
# 1. Simülasyon (güvenli test)
.\Winre-Fix.ps1 -WhatIf -Verbose

# 2. Normal çalıştırma (onay sorar)
.\Winre-Fix.ps1

# 3. Otomatik çalıştırma (onay sormaz)
.\Winre-Fix.ps1 -Force
```

### Log Dosyası
- Konum: `C:\temp\WinRE-Fix-Log.txt`

---

## 🇬🇧 English

### Summary

`Winre-Fix.ps1` is a PowerShell script that safely moves/recreates the Windows Recovery Environment (WinRE) to a new Recovery partition.

### Requirements
- Windows 10/11 (must have `reagentc` available)
- **Run as Administrator** (required)
- PowerShell 5.1 or PowerShell 7+

### ⚠️ Important Warnings
- **Back up your data!** Disk/partition operations can cause data loss.
- Run with `-WhatIf` first to simulate.
- Script only works on **Disk 0**.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-WhatIf` | Simulate steps without making changes (safe test mode) |
| `-Force` | Skip confirmation prompts + override minimum space warnings |
| `-Verbose` | Enable detailed output/logging |

### Script Flow

```
1. PRE-CHECK: Is there "Unallocated" space on Disk 0?
   ├─ None → ERROR: "No unallocated space found" → Exit
   ├─ < 1.2 GB → Warning, requires -Force
   └─ >= 1.2 GB → OK, proceed
        ↓
2. Backup confirmation (must type YES, skipped with -Force/-WhatIf)
        ↓
3. Find Recovery partition (scans all partitions by GPT Type)
   ├─ Not found → ERROR → Exit
   └─ Found → OK, proceed
        ↓
4. Partition validation (size must be < 10 GB)
   ├─ Too large → ERROR: "Might be Windows drive!" → Exit
   └─ OK → proceed
        ↓
5. Disable WinRE (reagentc /disable)
        ↓
6. Delete old Recovery partition
        ↓
7. Extend C: drive (reserves 1 GB)
        ↓
8. Create new Recovery partition + format NTFS
        ↓
9. Set GPT Type + Hidden attribute (diskpart)
        ↓
10. Enable WinRE (reagentc /enable)
        ↓
   COMPLETE!
```

### Usage Examples

```powershell
# 1. Simulation (safe test)
.\Winre-Fix.ps1 -WhatIf -Verbose

# 2. Normal run (asks for confirmation)
.\Winre-Fix.ps1

# 3. Automatic run (no confirmation)
.\Winre-Fix.ps1 -Force
```

### Log File
- Location: `C:\temp\WinRE-Fix-Log.txt`

---

## Safety Features

| Check | Description |
|-------|-------------|
| 🔒 Administrator | Script exits if not run as Administrator |
| 💾 Unallocated Space | Checks for free disk space **before** any changes |
| ✅ Backup Confirmation | Requires typing "YES" before proceeding (skipped with -Force) |
| 🔍 GPT Type Scan | Finds Recovery partition by scanning all partitions for correct GPT type |
| 📏 Size Sanity Check | Recovery partition must be < 10 GB (prevents deleting Windows!) |
| 📝 Full Logging | All operations logged to `C:\temp\WinRE-Fix-Log.txt` |
| 🛡️ Winre.wim Check | Verifies recovery image exists before enabling WinRE |

---

## License

MIT License - Use at your own risk.

## Author

Created for safe WinRE partition management on Windows systems.
