# Personal Scoop Bucket — Sally + RPG Maker VX Ace RTP

這是你的個人 Scoop Bucket，目前包含兩個套件：

1. **Sally** — 輕量雙面板 Windows 文件管理器。
2. **RPG Maker VX Ace RTP** — VX Ace 遊戲所需的官方 Runtime Package。

## 套件清單

| Manifest | 軟體 | 安裝方式 | 版本策略 |
|---|---|---|---|
| `bucket/sally.json` | Sally | 一般 per-user Scoop 安裝 | GitHub Releases 自動檢查更新 |
| `bucket/rpg-vx-ace-rtp.json` | RPG Maker VX Ace RTP | **必須 global + 管理員權限** | 官方目前列為 RTP Ver. 1.00，沒有自動版本 API |

官方來源：

- Sally 專案：https://github.com/0xeb/sally
- Sally 下載頁：https://get-sally.app/download/
- RPG Maker VX Ace RTP：https://www.rpgmakerweb.com/run-time-package
- RTP 官方 EULA：https://www.rpgmakerweb.com/eula

## 重要：初始化 SHA-256

本專案不猜測或虛構任何下載檔案的雜湊值。初始 Manifest 中的 hash 是待初始化提示字串；**在初始化完成之前，不要發布或安裝 Bucket**。

### 1. 初始化 Sally

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Update-SallyManifest.ps1
```

腳本會查詢 Sally GitHub Releases，下載官方 `SHA256SUMS.txt`，驗證 x64、x86、ARM64 三個 ZIP 的 SHA-256，然後更新 `bucket/sally.json`。

### 2. 初始化 RPG Maker VX Ace RTP

```powershell
.\scripts\Initialize-RtpManifest.ps1
```

RTP 官方網站提供 ZIP 下載，但頁面沒有公布可直接使用的 SHA-256 校驗清單。此腳本會：

1. 從官方 `assets.rpgmakerweb.com` 網域下載 `RPGVXAce_RTP.zip`。
2. 檢查檔案大小及 ZIP 結構。
3. 確認 ZIP 內含 `RPGVXAce_RTP100/Setup.exe` 和 `Setup-1.bin`。
4. 計算下載檔案的 SHA-256。
5. 將 hash 寫入 `bucket/rpg-vx-ace-rtp.json`。
6. 刪除暫存下載檔。

首次初始化會下載約 186 MiB 的官方 ZIP。這個 hash 是你首次從官方 HTTPS 網址取得檔案後建立的完整性鎖定值，不是發行商簽署的獨立 checksum；請確認下載來源和網域正確後再提交。

### 3. 檢查所有 Manifest

```powershell
.\scripts\Test-Bucket.ps1
```

測試會在任一套件的 hash 尚未初始化時失敗，避免把未驗證的 Manifest 推送到 GitHub。

## 專案結構

```text
scoop-sally-bucket/
├─ .github/
│  └─ workflows/
│     ├─ ci.yml
│     └─ excavator.yml
├─ bin/
│  └─ auto-pr.ps1
├─ bucket/
│  ├─ sally.json
│  └─ rpg-vx-ace-rtp.json
├─ scripts/
│  ├─ Update-SallyManifest.ps1
│  ├─ Initialize-RtpManifest.ps1
│  └─ Test-Bucket.ps1
├─ .gitattributes
├─ .gitignore
├─ LICENSE
└─ README.md
```

## 建立 GitHub Repository

建議建立 Public repository，例如：

```text
scoop-sally-bucket
```

在 `bin/auto-pr.ps1` 中，把：

```text
YOUR_GITHUB_USERNAME/scoop-sally-bucket:main
```

替換成自己的 GitHub 帳號。

完成兩個套件的 hash 初始化並通過測試後，在專案根目錄執行：

```powershell
git init
git branch -M main
git add .
git commit -m "Initial personal Scoop bucket"
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/scoop-sally-bucket.git
git push -u origin main
```

將命令中的 `YOUR_GITHUB_USERNAME` 換成自己的 GitHub 使用者名稱。

### 啟用 GitHub Actions

在 GitHub Repository：

1. 打開 **Settings → Actions → General**。
2. 允許工作流程使用所需 Actions。
3. 在 Workflow permissions 中選擇 **Read and write permissions**，讓 Excavator 能提交更新。
4. 保存設定。

`ci.yml` 會在 push、PR 時執行本地 Manifest 驗證。`excavator.yml` 每四小時檢查 Sally 的 GitHub Releases 更新。RTP 是固定的官方 Ver. 1.00 套件，沒有 `checkver` / `autoupdate`，不會被當成每小時變動的應用程式。

## 安裝 Sally

先安裝 Git 並添加 Bucket：

```powershell
scoop install git
scoop bucket add sallybucket https://github.com/YOUR_GITHUB_USERNAME/scoop-sally-bucket
```

安裝及更新 Sally：

```powershell
scoop install sallybucket/sally
scoop update
scoop update sally
```

Sally 內建更新檢查建議設定為 **Never**，避免 Scoop 和 Sally 內建更新器同時修改安裝目錄：

`Options → Configuration → General → Check for updates → Never`

Sally 使用者設定存放於：

```text
HKEY_CURRENT_USER\Software\Sally
```

建議使用 Sally 的 **Options → Export Configuration** 定期備份設定。

## 安裝 RPG Maker VX Ace RTP（重要）

RTP 與 Sally 不同。官方 `Setup.exe` 會把 runtime 安裝到共用的 Program Files (x86) 位置，並註冊系統級資訊；因此本 Manifest **會拒絕一般 per-user 安裝**，要求使用 Scoop global install。

### 1. 確認尚未手動安裝 RTP

預設安裝路徑：

```text
C:\Program Files (x86)\Common Files\Enterbrain\RGSS3\RPGVXAce\
```

如果這個目錄已有 `unins000.exe`，代表 RTP 可能已經安裝。此時不要重複安裝；可以繼續使用既有版本，或先透過 Windows 已安裝應用程式／原廠卸載程式移除，再改由 Scoop 管理。

### 2. 使用管理員權限安裝

先安裝 Scoop 的 `sudo` 輔助工具（若尚未安裝）：

```powershell
scoop install sudo
```

然後執行：

```powershell
sudo scoop install sallybucket/rpg-vx-ace-rtp --global
```

也可以在已提升權限的 PowerShell 中執行 global install：

```powershell
scoop install sallybucket/rpg-vx-ace-rtp --global
```

安裝器使用 Inno Setup 靜默參數：

```text
/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
```

安裝後，原始 ZIP 解壓檔會從 Scoop 版本目錄清理，只保留管理標記。RTP 真正的 runtime 檔案位於廠商安裝路徑。

### 3. 更新與卸載

RTP 官方頁目前標示 Ver. 1.00，沒有像 Sally GitHub Releases 那樣的版本 API。若官方日後更新檔案，需重新執行：

```powershell
.\scripts\Initialize-RtpManifest.ps1
.\scripts\Test-Bucket.ps1
```

如果官方仍使用相同的 1.00 版本號但替換了 ZIP，應人工審查 hash 變化，並在 Manifest 中提高內部 package revision（例如 `1.00-2`），再提交。

透過 Scoop global install 的卸載命令：

```powershell
sudo scoop uninstall rpg-vx-ace-rtp --global
```

Manifest 會呼叫官方 `unins000.exe /SILENT`。不要直接刪除 `C:\Program Files (x86)\Common Files\Enterbrain\RGSS3\RPGVXAce`，否則可能留下註冊資訊或破壞卸載紀錄。

### 4. RTP 授權注意事項

官方 EULA 對 RTP 的使用範圍有明確限制，包括：

- 授權是免費、非專屬、不可轉讓的。
- RTP 的授權用途限定為遊玩由完成註冊程序的 RPG Maker VX Ace 使用者製作及發行的遊戲。
- 未經書面同意，不得出售、分發、轉讓、出租、再授權或以其他方式轉移 RTP 軟體及其資料。

本 Bucket 只提供官方下載連結和安裝自動化，不會將 RTP ZIP、音樂、圖片或 DLL 重新上傳到 GitHub。使用者仍應閱讀並遵守官方 EULA。

## 自動更新

`.github/workflows/excavator.yml` 每四小時執行 Scoop 官方 GitHub Actions 維護工具：

- Sally：由 `checkver.github` 檢查正式 Release，依 `autoupdate` 更新版本、下載 URL 和官方 SHA256 清單。
- RPG Maker VX Ace RTP：目前固定為 Ver. 1.00，不參與自動版本更新。

GitHub Actions 排程不是精確定時服務；也可以在 GitHub Actions 頁面手動執行 **Excavator → Run workflow**。

## 安全原則

- Sally 僅從 `github.com/0xeb/sally` 官方 Releases 下載。
- RTP 僅從 `assets.rpgmakerweb.com` 官方下載連結取得。
- 不接受空白或未初始化的 SHA-256。
- RTP 首次 hash 是由本機對官方 HTTPS 下載檔計算；這能固定後續安裝內容，但不等同於廠商簽署的 checksum。
- 不把 RTP 素材重新打包或上傳到自己的 Bucket。
- Manifest、PowerShell hooks 和 GitHub Actions 都可能執行程式碼；更新時應審查差異和來源。

## 參考資料

- Sally：https://github.com/0xeb/sally
- Sally Releases：https://github.com/0xeb/sally/releases
- RPG Maker VX Ace RTP：https://www.rpgmakerweb.com/run-time-package
- RPG Maker EULA：https://www.rpgmakerweb.com/eula
- Scoop App Manifests：https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests
- Scoop Global Installs：https://github.com/ScoopInstaller/Scoop/wiki/Global-Installs
- Scoop App Manifest Autoupdate：https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate
