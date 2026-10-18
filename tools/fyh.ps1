# =====================================================================
#  Fear & Hunger - Parxe en catala  |  tools\fyh.ps1
#  Motor del parche: deteccion del juego, verificacion por hashes,
#  backup, copia con robocopy y restauracion.  Solo Windows + PowerShell.
# =====================================================================
param(
  [Parameter(Mandatory = $true)][ValidateSet('patch', 'unpatch')]
  [string]$Mode,
  [string]$Root = '',            # ruta candidata del juego (opcional)
  [switch]$Elevated,             # ya se esta ejecutando elevado
  [switch]$Pause,                # pausar al final (ventana elevada)
  [string]$TestSteamRoot = ''    # [hook de prueba] simula la raiz de Steam
)

$ErrorActionPreference = 'Stop'
$ToolsDir  = $PSScriptRoot
$PkgRoot   = Split-Path -Parent $ToolsDir
$FilesDir  = Join-Path $PkgRoot 'files'
$PathFile  = Join-Path $PkgRoot 'FyH_path.txt'
$HashOrig  = Join-Path $ToolsDir 'hashes.txt'
$HashPatch = Join-Path $ToolsDir 'hashes_patch.txt'
$KeyFiles  = @('data\System.json', 'data\CommonEvents.json',
               'data\Map001.json', 'data\Map011.json', 'data\Map175.json')

# ----------------------------- utilidades -----------------------------
function Say([string]$es, [string]$ca, [string]$color = 'Gray') {
  Write-Host ('  ' + $es) -ForegroundColor $color
  if ($ca) { Write-Host ('  ' + $ca) -ForegroundColor DarkGray }
}

function TrimPS([string]$p) { if ($p) { return $p.Trim().TrimEnd('\') } return '' }

function Test-GameRoot([string]$p) {
  $p = TrimPS $p
  if (-not $p) { return $false }
  if (-not (Test-Path -LiteralPath (Join-Path $p 'data\System.json'))) { return $false }
  if (-not (Test-Path -LiteralPath (Join-Path $p 'js\plugins.js')))     { return $false }
  return $true
}

# Acepta la raiz del juego o su subcarpeta www; normaliza a la raiz.
function Normalize-Root([string]$p) {
  $p = TrimPS $p
  if ((Test-GameRoot (Join-Path $p 'www'))) { return (Join-Path $p 'www') }
  return $p
}

# ----------------------------- deteccion ------------------------------
function Get-SteamLibs([string]$TestSteamRoot) {
  $libs = New-Object System.Collections.Generic.List[string]
  if ($TestSteamRoot) { [void]$libs.Add((TrimPS $TestSteamRoot)); return $libs }
  $roots = @()
  foreach ($rk in @('HKCU:\Software\Valve\Steam',
                    'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                    'HKLM:\SOFTWARE\Valve\Steam')) {
    try {
      $ip = Get-ItemProperty -Path $rk -ErrorAction Stop
      $v = $ip.SteamPath; if (-not $v) { $v = $ip.InstallPath }
      if ($v) { $roots += ($v -replace '/', '\') }
    } catch { }
  }
  foreach ($sp in $roots) {
    if ((Test-Path -LiteralPath $sp) -and ($libs -notcontains $sp)) { [void]$libs.Add($sp) }
    $vdf = Join-Path $sp 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      try {
        foreach ($ln in (Get-Content -LiteralPath $vdf -ErrorAction Stop)) {
          if ($ln -match '"path"\s+"([^"]+)"') {
            $lp = ($matches[1] -replace '\\\\', '\') -replace '/', '\'
            if (($libs -notcontains $lp) -and (Test-Path -LiteralPath $lp)) { [void]$libs.Add($lp) }
          }
        }
      } catch { }
    }
  }
  return $libs
}

function Find-GameInDir([string]$base) {
  $base = TrimPS $base
  if (-not $base -or -not (Test-Path -LiteralPath $base)) { return $null }
  if (Test-GameRoot $base)              { return $base }
  if (Test-GameRoot (Join-Path $base 'www')) { return (Join-Path $base 'www') }
  foreach ($n in @('Fear & Hunger', 'Fear and Hunger')) {
    foreach ($c in @((Join-Path $base $n), (Join-Path (Join-Path $base $n) 'www'))) {
      if (Test-GameRoot $c) { return $c }
    }
  }
  $dirs = Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -like 'Fear*Hunger*' }
  foreach ($d in $dirs) {
    $r = Find-GameInDir $d.FullName
    if ($r) { return $r }
  }
  return $null
}

function Find-SteamGame([string]$TestSteamRoot) {
  $libs = Get-SteamLibs $TestSteamRoot
  foreach ($lib in $libs) {
    $common = Join-Path $lib 'steamapps\common'
    if (-not (Test-Path -LiteralPath $common)) { continue }
    $dirs = Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Fear*Hunger*' }
    foreach ($d in $dirs) {
      $r = Find-GameInDir $d.FullName
      if ($r) { return $r }
    }
  }
  return $null
}

function Find-TypicalGame {
  if ($env:FYPATCH_SKIP_TYPICAL -eq '1') { return $null }  # [hook de prueba]
  $bases = @()
  foreach ($p in @('C:\Program Files (x86)\Steam\steamapps\common',
                   'C:\Program Files\Steam\steamapps\common')) { $bases += $p }
  foreach ($d in @('D', 'E', 'F', 'G')) {
    $bases += ($d + ':\SteamLibrary\steamapps\common')
    $bases += ($d + ':\Steam\steamapps\common')
    $bases += ($d + ':\Games')
    $bases += ($d + ':\Juegos')
    $bases += ($d + ':\Games\SteamLibrary\steamapps\common')
  }
  try {
    $bases += [Environment]::GetFolderPath('Desktop')
    $bases += (Join-Path $env:USERPROFILE 'Downloads')
  } catch { }
  foreach ($b in $bases) {
    $b = TrimPS $b
    if (-not $b -or -not (Test-Path -LiteralPath $b)) { continue }
    $r = Find-GameInDir $b
    if ($r) { return $r }
    if ($b -match '(Desktop|Escritorio|Downloads|Descargas)') {
      $subs = Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue |
              Select-Object -First 300
      foreach ($s in $subs) {
        $r = Find-GameInDir $s.FullName
        if ($r) { return $r }
      }
    }
  }
  return $null
}

function Show-FolderPicker {
  if ($env:FYPATCH_NOPROMPT -eq '1') {
    Write-Host '  [prueba] Selector de carpetas omitido (FYPATCH_NOPROMPT=1)' -ForegroundColor Yellow
    return $null
  }
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Selecciona la carpeta del juego (la raiz, o la subcarpeta www) / Selecciona la carpeta del joc (larrel o www)'
    $dlg.ShowNewFolderButton = $false
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    $owner.Text = 'Fear & Hunger - CataLa'
    $res = $dlg.ShowDialog($owner)
    $owner.Dispose()
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
  } catch {
    Write-Host ('  [ERROR] No se pudo abrir el selector: ' + $_.Exception.Message) -ForegroundColor Red
  }
  return $null
}

function Find-GameRoot {
  param([string]$RootDir, [string]$TestSteamRoot)
  # 1) ruta guardada de una ejecucion anterior
  if (Test-Path -LiteralPath $PathFile) {
    try {
      $saved = (Get-Content -LiteralPath $PathFile -TotalCount 1 -ErrorAction Stop)
      $saved = (@($saved)[0])
      if ($saved) {
        $saved = TrimPS ([string]$saved)
        if ($saved) {
          $saved = Normalize-Root $saved          # acepta raiz o subcarpeta www
          if ($saved -and (Test-GameRoot $saved)) {
            Say ('Usando ruta guardada: ' + $saved) ('Usant ruta guardada') 'DarkGray'
            return $saved
          }
        }
      }
    } catch { }
  }
  # 2) Steam (registro + libraryfolders.vdf)
  Say 'Buscando el juego en Steam...' 'Cercant el joc a Steam...' 'DarkGray'
  $r = Find-SteamGame $TestSteamRoot
  if ($r) { return $r }
  # 3) rutas tipicas / Escritorio / Descargas
  Say 'Buscando en rutas tipicas, Escritorio y Descargas...' 'Cercant en rutes tipiques...' 'DarkGray'
  $r = Find-TypicalGame
  if ($r) { return $r }
  # 4) selector de carpeta
  Say 'No se encontro automaticamente. Se abrira un selector de carpetas.' "No s'ha trobat. S'obrira un selector de carpetes." 'Yellow'
  while ($true) {
    $sel = Show-FolderPicker
    if (-not $sel) { return $null }
    $n = Normalize-Root $sel
    if (Test-GameRoot $n) { return $n }
    Say ('Esa carpeta no parece el juego (falta data\System.json o js\plugins.js): ' + $n) 'Intenta con la raiz del juego o la carpeta www.' 'Red'
    if ($env:FYPATCH_NOPROMPT -eq '1') { return $null }
  }
}

# ------------------------------ hashes --------------------------------
function Get-Hash([string]$path) {
  if (Test-Path -LiteralPath $path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
  }
  return $null
}

function Load-HashList([string]$file) {
  $map = @{ }
  if (Test-Path -LiteralPath $file) {
    foreach ($ln in (Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)) {
      $t = $ln.Trim()
      if (-not $t -or $t.StartsWith('#')) { continue }
      $parts = $t -split '\s+', 2
      if ($parts.Count -eq 2) { $map[$parts[1].Replace('/', '\')] = $parts[0].ToLower() }
    }
  }
  return $map
}

# original | patched | mixed | unknown
function Get-State([string]$root) {
  $o = Load-HashList $HashOrig
  $p = Load-HashList $HashPatch
  $allO = $true; $allP = $true
  foreach ($rel in $KeyFiles) {
    $h = Get-Hash (Join-Path $root $rel)
    if (-not $h) { return 'unknown' }
    $mo = ($o.ContainsKey($rel) -and $o[$rel] -eq $h)
    $mp = ($p.ContainsKey($rel) -and $p[$rel] -eq $h)
    if ($env:FYPATCH_DEBUG -eq '1') {
      Say ('[DBG] ' + $rel + ' orig=' + $mo + ' patch=' + $mp + ' h=' + $h.Substring(0, 8)) '' 'DarkGray'
    }
    if (-not $mo) { $allO = $false }
    if (-not $mp) { $allP = $false }
  }
  if ($allP) { return 'patched' }
  if ($allO) { return 'original' }
  return 'mixed'
}

function Test-State([string]$root, [string]$want) { return ((Get-State $root) -eq $want) }

# --------------------------- escritura/elevacion ----------------------
function Test-Writable([string]$root) {
  foreach ($t in @($root, (Join-Path $root 'data'), (Join-Path $root 'js'))) {
    try {
      $f = Join-Path $t '.fyh_write_test'
      Set-Content -LiteralPath $f -Value 'x' -ErrorAction Stop
      Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
    } catch { return $false }
  }
  return $true
}

function Elevate([string]$root) {
  $ps1 = Join-Path $ToolsDir 'fyh.ps1'
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $ps1 + '"'),
         '-Mode', $Mode, '-Root', ('"' + $root + '"'), '-Elevated', '-Pause')
  if ($TestSteamRoot) { $a += @('-TestSteamRoot', ('"' + $TestSteamRoot + '"')) }
  try {
    Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs | Out-Null
    Say 'Se necesita permiso de administrador: se abrira una ventana elevada.' "Es cal permisos: s'obrira una finestra elevada." 'Yellow'
    Say 'El proceso continuara en esa ventana.' 'El proces continuara en aquella finestra.' 'Yellow'
  } catch {
    Say 'Permisos denegados o cancelados por el usuario.' 'Permisos denegats.' 'Red'
    return 1
  }
  return 0
}

# ------------------------------ acciones ------------------------------
function Save-PathFile([string]$root) {
  try {
    [System.IO.File]::WriteAllText($PathFile, $root, (New-Object System.Text.UTF8Encoding($false)))
  } catch { }
}

function Backup-Game([string]$root) {
  $bdir = Join-Path $root 'backup_original_cat'
  if (Test-Path -LiteralPath (Join-Path $bdir 'data\System.json')) {
    Say 'Backup ya existente: se conserva (nunca se sobrescribe).' 'Backup ja existent: es conserva (no es sobreescriu).' 'Yellow'
    return 0
  }
  Say 'Creando backup de los originales en backup_original_cat\ ...' 'Creant backup dels originals...' 'DarkGray'
  New-Item -ItemType Directory -Force -Path (Join-Path $bdir 'data') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $bdir 'js')    | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $bdir 'fonts') | Out-Null
  $pre = @{ }
  foreach ($rel in $KeyFiles) { $pre[$rel] = Get-Hash (Join-Path $root $rel) }
  & robocopy (Join-Path $root 'data') (Join-Path $bdir 'data') /E /NFL /NDL /NJH /NJS /R:2 /W:2 | Out-Null
  if ($LASTEXITCODE -ge 8) {
    Say ('[ERROR] Fallo el backup (robocopy code ' + $LASTEXITCODE + '). No se ha parcheado nada.') '[ERROR] Ha fallat el backup.' 'Red'
    return 1
  }
  if (Test-Path -LiteralPath (Join-Path $root 'js\plugins.js')) {
    Copy-Item -LiteralPath (Join-Path $root 'js\plugins.js') -Destination (Join-Path $bdir 'js\plugins.js') -Force
  }
  if (Test-Path -LiteralPath (Join-Path $root 'fonts\Eczar-Regular.ttf')) {
    Copy-Item -LiteralPath (Join-Path $root 'fonts\Eczar-Regular.ttf') -Destination (Join-Path $bdir 'fonts\Eczar-Regular.ttf') -Force
  }
  foreach ($rel in $KeyFiles) {
    if ((Get-Hash (Join-Path $bdir $rel)) -ne $pre[$rel]) {
      Say ('[ERROR] Backup corrupto (' + $rel + '). Abortando sin parchear.') '[ERROR] Backup corromput.' 'Red'
      return 1
    }
  }
  Say 'Backup creado y verificado.' 'Backup creat i verificat.' 'DarkGray'
  return 0
}

function Copy-Payload([string]$root) {
  & robocopy (Join-Path $FilesDir 'data') (Join-Path $root 'data') /E /IS /IT /NFL /NDL /NJH /NJS /R:2 /W:2 | Out-Null
  if ($LASTEXITCODE -ge 8) {
    Say ('[ERROR] Fallo la copia (robocopy code ' + $LASTEXITCODE + ').') '[ERROR] Ha fallat la copia.' 'Red'
    return 1
  }
  if (Test-Path -LiteralPath (Join-Path $FilesDir 'js\plugins.js')) {
    Copy-Item -LiteralPath (Join-Path $FilesDir 'js\plugins.js') -Destination (Join-Path $root 'js\plugins.js') -Force
  }
  if (Test-Path -LiteralPath (Join-Path $FilesDir 'fonts')) {
    & robocopy (Join-Path $FilesDir 'fonts') (Join-Path $root 'fonts') /E /IS /IT /NFL /NDL /NJH /NJS /R:2 /W:2 | Out-Null
    if ($LASTEXITCODE -ge 8) {
      Say ('[ERROR] Fallo copiando las fuentes (robocopy code ' + $LASTEXITCODE + ').') '[ERROR] Ha fallat la copia de fonts.' 'Red'
      return 1
    }
  }
  return 0
}

function Restore-Backup([string]$root) {
  $bdir = Join-Path $root 'backup_original_cat'
  if (-not (Test-Path -LiteralPath (Join-Path $bdir 'data\System.json'))) { return $false }
  & robocopy (Join-Path $bdir 'data') (Join-Path $root 'data') /E /IS /IT /NFL /NDL /NJH /NJS /R:2 /W:2 | Out-Null
  if ($LASTEXITCODE -ge 8) {
    Say ('[ERROR] Fallo la restauracion (robocopy code ' + $LASTEXITCODE + ').') '[ERROR] Ha fallat la restauracio.' 'Red'
    return $false
  }
  if (Test-Path -LiteralPath (Join-Path $bdir 'js\plugins.js')) {
    Copy-Item -LiteralPath (Join-Path $bdir 'js\plugins.js') -Destination (Join-Path $root 'js\plugins.js') -Force
  }
  if (Test-Path -LiteralPath (Join-Path $bdir 'fonts\Eczar-Regular.ttf')) {
    Copy-Item -LiteralPath (Join-Path $bdir 'fonts\Eczar-Regular.ttf') -Destination (Join-Path $root 'fonts\Eczar-Regular.ttf') -Force
  }
  return $true
}

# -------------------------------- main --------------------------------
function Main {
  Write-Host ''
  Write-Host '  ================================================='
  if ($Mode -eq 'patch') {
    Write-Host '   Fear & Hunger  -  PARCHE EN CATALA / PATX EN CATALA'  -ForegroundColor White
  } else {
    Write-Host '   Fear & Hunger  -  RESTAURAR ORIGINAL / RESTAURAR ORIGINAL' -ForegroundColor White
  }
  Write-Host '  ================================================='
  Write-Host ''

  # 1) detectar ruta
  $root = Find-GameRoot -RootDir $PkgRoot -TestSteamRoot $TestSteamRoot
  if (-not $root) {
    Say 'No se encontro el juego. Abortando.' 'No s ha trobat el joc. Avortant.' 'Red'
    return 2
  }
  $root = TrimPS $root
  Say ('Ruta del juego: ' + $root) ('Ruta del joc: ' + $root) 'Cyan'
  Save-PathFile $root

  # permisos solo si hace falta
  if (-not (Test-Writable $root)) {
    if ($Elevated) {
      Say 'Sin permisos de escritura incluso como administrador.' 'Sense permisos ni com administrador.' 'Red'
      return 1
    }
    return (Elevate $root)
  }

  if ($Mode -eq 'patch') {
    # 2) verificacion de version
    $state = Get-State $root
    $doBackup = $true
    if ($state -eq 'patched') {
      Say 'AVISO: el juego ya esta parcheado (hashes = version catalana).' 'AVIS: el joc ja te la traduccio al catala.' 'Yellow'
      Say 'No se creara otro backup; se volvera a copiar el parche.' 'No es fara un altre backup; es tornara a copiar el patx.' 'Yellow'
      $doBackup = $false
    } elseif ($state -eq 'original') {
      Say 'Version verificada: coincide con la original esperada.' 'Versio verificada: coincideix amb l original esperada.' 'Green'
    } else {
      Say 'AVISO: tu version del juego NO coincide con la esperada.' 'AVIS: la teva versio del joc NO coincideix amb lesperada.' 'Yellow'
      Say 'El parche puede romper el juego.' 'El patx pot trencar el joc.' 'Yellow'
      if (-not (Confirm-YN 'Continuar de todos modos? (S/N)' 'Continuar de totes maneres? (S/N)')) {
        Say 'Cancelado por el usuario.' 'Cancel·lat per l usuari.' 'Yellow'
        return 2
      }
    }

    # 3) backup (solo si no existe; nunca sobrescribir)
    if ($doBackup) {
      $rc = Backup-Game $root
      if ($rc -ne 0) { return $rc }
    }

    # 4) copiar files\ con robocopy
    $rc = Copy-Payload $root
    if ($rc -ne 0) {
      Say 'Restaurando desde el backup...' 'Restaurant des del backup...' 'Yellow'
      [void](Restore-Backup $root)
      Say 'Juego restaurado. No se han guardado cambios.' 'Joc restaurat.' 'Yellow'
      return 1
    }

    # 5) verificar hashes tras copiar
    if (-not (Test-State $root 'patched')) {
      Say '[ERROR] Los archivos copiados no pasan la verificacion de hashes.' '[ERROR] Verificacio de hashes fallida.' 'Red'
      Say 'Restaurando automaticamente desde el backup...' 'Restaurant automaticament...' 'Yellow'
      [void](Restore-Backup $root)
      if (Test-State $root 'original') {
        Say 'Juego restaurado al original (verificado).' 'Joc restaurat (verificat).' 'Green'
      } else {
        Say 'ATENCION: revisa backup_original_cat\ manualmente.' 'ATENCIO: revisa backup_original_cat\.' 'Red'
      }
      return 1
    }

    # 6) exito
    Say 'EXITO: traduccion al catalan aplicada y verificada.' 'EXIT: traduccio aplicada i verificada.' 'Green'
    Say 'Para volver al espanol ejecuta unpatch.bat.' 'Per tornar al castella: unpatch.bat.' 'DarkGray'
    return 0
  }
  else {
    # ---------------- unpatch ----------------
    $bdir = Join-Path $root 'backup_original_cat'
    if (-not (Test-Path -LiteralPath (Join-Path $bdir 'data\System.json'))) {
      Say 'No hay backup en este juego: no se toca nada.' 'No hi ha backup: no es toca res.' 'Yellow'
      Say '(El backup se crea la primera vez que ejecutas patch.bat.)' ''
      return 0
    }
    Say 'Restaurando originales desde backup_original_cat\ ...' 'Restaurant els originals...' 'DarkGray'
    if (-not (Restore-Backup $root)) { return 1 }
    if (Test-State $root 'original') {
      Say 'EXITO: juego restaurado al original (hashes verificados).' 'EXIT: joc restaurat (hashes verificats).' 'Green'
      return 0
    }
    Say 'AVISO: restaurado, pero algun hash no coincide con el original.' 'AVIS: restaurat, pero algun hash no coincideix.' 'Yellow'
    return 1
  }
}

function Confirm-YN([string]$es, [string]$ca) {
  if ($env:FYPATCH_NOPROMPT -eq '1') {
    Write-Host '  [prueba] Confirmacion automatica: N' -ForegroundColor Yellow
    return $false
  }
  while ($true) {
    Write-Host ('  ' + $es) -ForegroundColor Yellow
    $a = Read-Host '  Respuesta'
    if (-not $a) { return $false }
    $a = $a.Trim().ToUpper()
    if ($a -eq 'S' -or $a -eq 'Y' -or $a -eq 'SI' -or $a -eq 'YES') { return $true }
    if ($a -eq 'N' -or $a -eq 'NO') { return $false }
  }
}

$code = 0
try   { $code = Main }
catch {
  Write-Host ('  [ERROR] ' + $_.Exception.Message + '  (linea ' +
              $_.InvocationInfo.ScriptLineNumber + ' en fyh.ps1)') -ForegroundColor Red
  $code = 1
}
if ($Pause) { try { [void](Read-Host '  Pulsa ENTER para salir / Prem ENTER per sortir') } catch { } }
exit $code
