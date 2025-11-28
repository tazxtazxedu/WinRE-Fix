<<<<<<< HEAD
# WinRE-Fix
=======
<!--
  README for Winre-Fix.ps1
  Bilingual (Turkish / English)
-->

# WinRE-Fix

**Türkçe / Turkish**

## Özet

`Winre-Fix.ps1` Windows Recovery Environment (WinRE) bileşenini güvenli bir şekilde yeni bir Recovery partition'a taşıma/yeniden oluşturma amaçlı bir PowerShell betiğidir. Betik; mevcut WinRE yerini tespit eder, WinRE'yi devre dışı bırakır (Winre.wim dosyasını korur), eski Recovery partition'ını kaldırır, `C:\` sürücüsünü genişletir/ayırır, yeni Recovery partition'ı oluşturur ve WinRE'yi yeniden etkinleştirir.

## Gereksinimler
- Windows (reagentc aracı mevcut olmalı)
- Yönetici (Administrator) hakları ile çalıştırma zorunludur
- PowerShell (varsayılan Windows PowerShell veya PowerShell 7)

## Parametreler
- `-WhatIf` : Gerçek değişiklik yapmadan adımları simüle eder (güvenli test modudur).
- `-Force` : Onay istemeden bazı adımları (ör. eski partition silme) uygular.
- `-Verbose` : Ayrıntılı çıktı/log için verbose modu.

## Betiğin Yaptığı Adımlar (kısa)
1. Yönetici kontrolü (yönetici değilse çıkış).
2. `reagentc /info` ile mevcut WinRE konumunu tespit eder.
3. `reagentc /disable` ile WinRE'yi devre dışı bırakır ve `C:\Windows\System32\Recovery\Winre.wim` dosyasını korur.
4. Eski Recovery partition'ı (GPT tipi `{de94bba4-06d1-4d40-a16a-bfd50179d6ac}`) tespit ederek siler (isteğe bağlı onay ile).
5. `C:` sürücüsünü genişletir ve yeni Recovery için 1 GB boş alan bırakır.
6. Yeni partition oluşturur, NTFS ile formatlar ve GPT tipini Recovery tipi olarak ayarlar.
7. Yeni partition üzerindeki uygun klasöre `Winre.wim` taşıma veya `reagentc /setreimage` + `reagentc /enable` adımlarıyla WinRE'yi yeniden etkinleştirir.
8. İşlem log'u kullanıcı masaüstünde `WinRE-Fix-Log.txt` olarak tutulur.

## Güvenlik ve Öneriler
- Önce `-WhatIf` ile simülasyon çalıştırın: `.\\Winre-Fix.ps1 -WhatIf -Verbose`.
- Bu tür disk/partition işleri veri kaybına yol açabilir; tam yedek alın.
- Betik `DiskNumber 0` varsaydığı için çoklu diskli sistemlerde dikkatli olun; gerekirse betikte disk numarasını düzenleyin.
```markdown
# WinRE-Fix

> PowerShell betiği: Windows Recovery Environment (WinRE) bileşenini güvenli şekilde yeni bir Recovery partition'a taşır/yeniden oluşturur.

**Türkçe / Turkish**

## Özet

`Winre-Fix.ps1` mevcut WinRE yerini tespit eder, WinRE'yi devre dışı bırakır (Winre.wim korur), eski Recovery partition'ını kaldırır, `C:\` sürücüsünden alan ayırır, yeni Recovery partition'ı oluşturur ve WinRE'yi yeniden etkinleştirir.

## Gereksinimler
- Windows (reagentc aracı mevcut olmalı)
- Yönetici hakları ile çalıştırma zorunludur
- PowerShell (Windows PowerShell veya PowerShell 7)

## Önemli: Yedek Alın
- Partition ve disk işlemleri veri kaybına yol açabilir. Lütfen değişiklik yapmadan önce tam sistem yedeği veya en azından önemli dosyalarınızın yedeğini alın.
- Öncelikle `-WhatIf` ile simülasyon çalıştırın.

## Parametreler
- `-WhatIf` : Gerçek değişiklik yapmadan adımları simüle eder (güvenli test modu).
- `-Force` : Onay istemeden bazı adımları (ör. eski partition silme) uygular.
- `-Verbose` : Ayrıntılı çıktı/log için verbose modu.

## Kısa Adımlar
1. Yönetici kontrolü
2. `reagentc /info` ile WinRE konumunu tespit
3. `reagentc /disable` ile WinRE'yi devre dışı bırakma (Winre.wim korunur)
4. Eski Recovery partition'ını (GPT tipi `{de94bba4-06d1-4d40-a16a-bfd50179d6ac}`) tespit edip isteğe bağlı silme
5. `C:` genişletme ve yeni partition için alan ayırma
6. Yeni partition oluşturma, formatlama ve GPT tipini Recovery olarak ayarlama
7. WinRE'yi yeniden etkinleştirme (`reagentc /enable`)

## Örnek Kullanım
```powershell
# Simülasyon (güvenli)
.\Winre-Fix.ps1 -WhatIf -Verbose

# Normal çalıştırma (onay sorar)
.\Winre-Fix.ps1

# Onay istemeden (Force)
.\Winre-Fix.ps1 -Force
```

---

**English**

## Summary

`Winre-Fix.ps1` is a PowerShell script to move/recreate the Windows Recovery Environment (WinRE) onto a new Recovery partition. It detects the current WinRE location, disables WinRE (preserving Winre.wim), removes the old Recovery partition, allocates space from `C:\`, creates a new Recovery partition, and re-enables WinRE.

## Requirements
- Windows (must have `reagentc` available)
- Run as Administrator
- PowerShell (Windows PowerShell or PowerShell 7)

## Important: Back Up First
- Disk/partition operations can cause data loss. Make a full system backup or at least backup important files before making changes.
- Run with `-WhatIf` to simulate first.

## Parameters
- `-WhatIf` : Simulate steps without making changes.
- `-Force` : Skip confirmation prompts (e.g., deleting old partition).
- `-Verbose` : Enable detailed output/logging.

## Brief Steps
1. Check Administrator privileges
2. Find WinRE location with `reagentc /info`
3. Disable WinRE with `reagentc /disable` (preserves `Winre.wim`)
4. Remove old Recovery partition if applicable
5. Extend `C:` and reserve space for Recovery
6. Create/format new partition and set GPT type
7. Re-enable WinRE (`reagentc /enable`)

## Examples
```powershell
# Simulation (safe)
.\Winre-Fix.ps1 -WhatIf -Verbose

# Normal run (asks for confirmation)
.\Winre-Fix.ps1

# Force run (no confirmation)
.\Winre-Fix.ps1 -Force
```

## Log
- Default log path: `C:\Users\<YourUser>\Desktop\WinRE-Fix-Log.txt`

If you want, I can also add a short `USAGE.md` or include the README content inside the script header comments. Tell me if you'd like me to also add an explicit interactive backup confirmation inside `Winre-Fix.ps1`.
```
