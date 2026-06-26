# ─────────────────────────────────────────────────────────────
#  EduSync — Full Project Backup Script (PowerShell)
#  Run from the project root:  .\scripts\backup-project.ps1
# ─────────────────────────────────────────────────────────────

param(
  [string]$OutputDir = ".\backups",
  [switch]$DBOnly,
  [switch]$CodeOnly,
  [switch]$SkipNodeModules
)

$Timestamp  = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
$BackupRoot = Join-Path $OutputDir $Timestamp

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       EduSync Project Backup Tool        ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Output → $BackupRoot" -ForegroundColor Gray
Write-Host ""

# ── Create output directory ───────────────────────────────────
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

# ─── 1. Database backup (via backup.js) ───────────────────────
if (-not $CodeOnly) {
  Write-Host "  📦  Step 1/2 — Backing up Neon PostgreSQL database..." -ForegroundColor Yellow

  $DbDir = Join-Path $BackupRoot "database"
  New-Item -ItemType Directory -Force -Path $DbDir | Out-Null

  Push-Location backend
  node backup.js --out $DbDir
  Pop-Location

  Write-Host "  ✅  Database backup saved to: $DbDir" -ForegroundColor Green
  Write-Host ""
}

# ─── 2. Code + config archive ─────────────────────────────────
if (-not $DBOnly) {
  Write-Host "  📦  Step 2/2 — Archiving project source code..." -ForegroundColor Yellow

  $CodeArchive = Join-Path $BackupRoot "edusync_code_$Timestamp.zip"

  # Items to exclude from the zip
  $Exclude = @(
    "backups",
    "*.zip",
    ".git",
    "node_modules",
    "build",
    ".dart_tool",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "*.g.dart",
    "uploads"          # local uploaded files — backed up separately if needed
  )

  # Build compress-archive exclusion using a temporary manifest
  $TempList = New-TemporaryFile
  Get-ChildItem -Path "." -Recurse | Where-Object {
    $rel = $_.FullName.Substring((Get-Location).Path.Length + 1)
    $skip = $false
    foreach ($ex in $Exclude) {
      if ($rel -like "*$ex*") { $skip = $true; break }
    }
    -not $skip
  } | Select-Object -ExpandProperty FullName | Set-Content $TempList

  # Compress
  Compress-Archive -Path (Get-Content $TempList) -DestinationPath $CodeArchive -Force 2>$null

  # Fallback: use a simpler approach if the above fails
  if (-not (Test-Path $CodeArchive)) {
    $TempDir = Join-Path $env:TEMP "edusync_backup_$Timestamp"
    Copy-Item -Path "." -Destination $TempDir -Recurse -Force
    # Remove excluded folders from temp copy
    foreach ($ex in $Exclude) {
      Get-ChildItem -Path $TempDir -Filter $ex -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path "$TempDir\*" -DestinationPath $CodeArchive -Force
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
  }

  Remove-Item $TempList -ErrorAction SilentlyContinue

  Write-Host "  ✅  Code archive saved: $CodeArchive" -ForegroundColor Green
  Write-Host ""
}

# ─── 3. Summary ───────────────────────────────────────────────
$Size = (Get-ChildItem $BackupRoot -Recurse | Measure-Object -Property Length -Sum).Sum
$SizeMB = [math]::Round($Size / 1MB, 2)

Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║           Backup Complete 🎉              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Location : $BackupRoot" -ForegroundColor White
Write-Host "  Total    : $SizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "  To restore the database:" -ForegroundColor Gray
Write-Host '  psql $DATABASE_URL -f .\backups\<date>\database\edusync_backup_*.sql' -ForegroundColor DarkGray
Write-Host ""
