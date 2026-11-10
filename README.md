# Personal Scoop Bucket — Sally

這是AI自動生成的scoop bucket方案，以下是其內容：
這是一個以 **Sally** 為目前唯一套件的個人 Scoop Bucket 初始專案。

- Sally 官方專案：https://github.com/0xeb/sally
- Sally 官方下載頁：https://get-sally.app/download/
- 官方授權：GPL-2.0-or-later
- 目前初始化版本：`1.0.47`（2026-11-06 發布；執行初始化腳本時會重新查詢最新版本）
- 支援架構：Windows x64、x86、ARM64

> **重要：先初始化 SHA-256，再安裝或發布 Bucket。**
>
> 本專案不猜測或虛構官方檔案雜湊值。`bucket/sally.json` 初始檔中的 hash 是明確的待初始化提示字串；執行 `scripts/Update-SallyManifest.ps1` 後，腳本會從 GitHub Releases API 找到最新發布版及官方 `SHA256SUMS.txt`，下載校驗清單，核對三種架構的 ZIP 檔名並填入 SHA-256。初始化完成前，`Test-Bucket.ps1` 會故意失敗，避免發布未驗證的 Manifest。

## 1. 專案結構

```text
scoop-sally-bucket/
├─ .github/
│  └─ workflows/
│     ├─ ci.yml                 # push / PR 時驗證 Manifest
│     └─ excavator.yml          # 每 4 小時檢查 Sally 新版本
├─ bin/
│  └─ auto-pr.ps1               # Scoop Excavator 的 PR 入口
├─ bucket/
│  └─ sally.json                # Sally 的 Scoop Manifest
├─ scripts/
│  ├─ Update-SallyManifest.ps1  # 首次初始化 / 手動同步最新版本與官方 hash
│  └─ Test-Bucket.ps1           # 本地 Manifest 檢查
├─ .gitattributes
├─ .gitignore
├─ LICENSE
└─ README.md
```

## 2. 首次初始化（Windows PowerShell 5.1 / PowerShell 7）

解壓專案後，在專案根目錄開啟 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Update-SallyManifest.ps1
.\scripts\Test-Bucket.ps1
```

初始化腳本會：

1. 查詢 `https://api.github.com/repos/0xeb/sally/releases/latest`。
2. 取得最新 release tag 和官方發布資產。
3. 下載該 release 的 `Sally-v<version>-SHA256SUMS.txt`。
4. 分別匹配 `x64`、`x86`、`ARM64` ZIP 的 SHA-256。
5. 更新 `bucket/sally.json` 的版本、下載 URL 和 hash。
6. 不會在找不到資產或 checksum 不匹配時靜默略過。

請檢查 Git 差異，確認版本和三個 hash 都已更新，再提交。

## 3. 建立 GitHub Repository

建議在 GitHub 建立一個 **Public** repository，例如：

```text
scoop-sally-bucket
```

將本專案內容推送到該 Repository。先在 `bin/auto-pr.ps1` 中將：

```powershell
YOUR_GITHUB_USERNAME/scoop-sally-bucket:main
```

替換成你自己的 GitHub 帳號，例如：

```powershell
alice/scoop-sally-bucket:main
```

然後在專案根目錄執行：

```powershell
git init
git branch -M main
git add .
git commit -m "Initial Sally manifest and bucket automation"
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/scoop-sally-bucket.git
git push -u origin main
```

把上面最後一條命令中的 `YOUR_GITHUB_USERNAME` 換成自己的 GitHub 使用者名稱。

### 啟用 GitHub Actions

在 GitHub Repository：

1. 打開 **Settings → Actions → General**。
2. 在 Actions permissions 中，允許工作流程使用所需的 actions。
3. 在 Workflow permissions 中選擇 **Read and write permissions**，讓 Excavator 能提交更新／建立更新 PR。
4. 保存設定。

本專案使用固定 commit SHA 引用 `actions/checkout` 和 `ScoopInstaller/GithubActions`，避免直接跟隨可變的 `main` 標籤。可在 `.github/workflows/` 中審查或更新這些版本。

## 4. 在 Scoop 中添加和安裝

先確保已安裝 Scoop 和 Git。Scoop Bucket 需要 Git：

```powershell
scoop install git
```

添加自己的 Bucket：

```powershell
scoop bucket add sallybucket https://github.com/YOUR_GITHUB_USERNAME/scoop-sally-bucket
```

安裝 Sally：

```powershell
scoop install sallybucket/sally
```

檢查：

```powershell
scoop list
scoop info sally
```

更新 Bucket 清單及 Sally：

```powershell
scoop update
scoop update sally
```

卸載：

```powershell
scoop uninstall sally
```

## 5. Sally 的自動更新與 Scoop 更新

Sally 本身包含更新程式；Scoop 也會根據 Bucket Manifest 更新程式。為避免兩套更新機制同時修改 Scoop 管理的安裝目錄，建議安裝後在 Sally 中把內建更新檢查設定為 **Never**：

`Options → Configuration → General → Check for updates → Never`

之後統一使用：

```powershell
scoop update
scoop update sally
```

Sally 的個人設定存放在目前使用者的登錄檔：

```text
HKEY_CURRENT_USER\Software\Sally
```

這些設定不在 Scoop 的版本目錄中，正常卸載 Scoop 套件不會替你備份或遷移該登錄檔設定。建議定期使用 Sally 的 **Options → Export Configuration** 匯出設定備份。

## 6. 自動更新工作流程

`.github/workflows/excavator.yml` 會每四小時啟動一次 Scoop 的官方 GitHub Actions 維護工具：

- 使用 Manifest 的 `checkver.github` 檢查 Sally 最新正式版（GitHub pre-release 不會作為穩定版本）。
- 使用 `autoupdate` 更新 x64、x86、ARM64 的下載 URL。
- 從 Sally 官方 `SHA256SUMS.txt` 取得對應 ZIP 的 hash；若官方 checksum 格式或下載方式變更，請先檢查工作流程結果，不要手動刪除 hash。
- 由 `bin/auto-pr.ps1` 將更新提交到自己的 Bucket 分支／PR 流程。

GitHub Actions 的排程不是精確定時服務，GitHub 忙碌時可能延遲。也可以在 Actions 頁面手動執行 **Excavator → Run workflow**。

## 7. 手動更新與除錯

手動將 Manifest 同步到 Sally 最新正式版：

```powershell
.\scripts\Update-SallyManifest.ps1
.\scripts\Test-Bucket.ps1
git diff
```

確認差異後提交：

```powershell
git add bucket/sally.json
git commit -m "Update Sally manifest"
git push
```

只檢查 Manifest：

```powershell
.\scripts\Test-Bucket.ps1
```

若 GitHub Actions 更新失敗，先查看該次工作流程日誌。常見原因包括：

- Sally 發布資產改名。
- 官方 checksum 文件改名或格式變更。
- GitHub API rate limit。
- `bin/auto-pr.ps1` 的 Repository owner/name 尚未替換。
- Repository 的 Actions 權限不足。

## 8. 安全與維護原則

- 只從 `github.com/0xeb/sally` 的官方 Releases 下載。
- 不接受缺少 SHA-256 的更新；初始化腳本會在無法驗證時停止。
- 不要為了讓 CI 通過而把 hash 留空、填任意值或使用 `skip_hash_check`。
- Manifest 及 GitHub Actions 都是可執行程式碼的供應鏈入口；更新第三方 Action 前先審查其來源與版本。
- Sally 官方說明其發行檔目前尚未 Authenticode 簽章；首次執行可能出現 SmartScreen 提示。請核對來源與 SHA-256，不要因為提示而隨意關閉 Defender。

## 9. 官方參考資料

- Sally：<https://github.com/0xeb/sally>
- Sally Releases：<https://github.com/0xeb/sally/releases>
- Sally Download / checksums：<https://get-sally.app/download/>
- Scoop Bucket Template：<https://github.com/ScoopInstaller/BucketTemplate>
- Scoop App Manifest：<https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests>
- Scoop App Manifest Autoupdate：<https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate>
