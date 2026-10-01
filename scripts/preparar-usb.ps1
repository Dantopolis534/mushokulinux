<#
.SYNOPSIS
    cyberArch-Dotfiles :: Mushoku Tensei
    Prepara la instalacion de Arch Linux desde Windows.

.DESCRIPTION
    Verifica la maquina, confirma que S: es la particion correcta para Linux,
    descarga la ISO de Arch y la graba en un pendrive USB.

    Todo lo que hace es reversible salvo el paso de formatear el USB, que
    requiere confirmacion explicita.

.PARAMETER SoloVerificar
    No descarga ni escribe nada. Solo el reporte de la maquina.

.PARAMETER ISODestino
    Ruta donde guardar la ISO. Por defecto: ~/Downloads/archlinux.iso

.PARAMETER UsbNumero
    Numero de disco del pendrive (segun Get-Disk). Obligatorio para grabar.

.PARAMETER ConfirmarGrabado
    Sin esta opcion el script solo simula: no borra nada.

.PARAMETER Forzar
    Continua aunque S: tenga contenido real fuera de la papelera. Destruye
    esos archivos. La papelera y los stubs de Windows nunca bloquean.

.EXAMPLE
    .\preparar-usb.ps1 -SoloVerificar

.EXAMPLE
    .\preparar-usb.ps1 -UsbNumero 2 -ConfirmarGrabado

.NOTES
    Para grabar el USB hace falta PowerShell como Administrador, porque se
    escribe en crudo sobre \\.\PhysicalDriveN.
#>

[CmdletBinding()]
param(
    [switch]$SoloVerificar,
    [switch]$ConfirmarGrabado,
    [switch]$Forzar,
    [string]$ISODestino = "$env:USERPROFILE\Downloads\archlinux.iso",
    [int]$UsbNumero = -1,
    [string]$Espejo = "https://geo.mirror.pkgbuild.com/iso"
)

$ErrorActionPreference = "Stop"

# --- Administrador -------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Colores -----------------------------------------------------------------
function Write-Titulo   { param($t) Write-Host ""; Write-Host "  $t" -ForegroundColor Cyan }
function Write-Ok       { param($t) Write-Host "  [+] $t" -ForegroundColor Green }
function Write-Aviso    { param($t) Write-Host "  [!] $t" -ForegroundColor Yellow }
function Write-Error2   { param($t) Write-Host "  [x] $t" -ForegroundColor Red }
function Write-Dato     { param($k,$v) Write-Host "      $($k.PadRight(22)) $v" -ForegroundColor DarkGray }

# --- Banner ------------------------------------------------------------------
function Show-Banner {
    # Ojo: aqui NO se usan comillas dobles. Con " el PowerShell se come los
    # backticks del arte ASCII y lo deja hecho un desastre.
    $arte = @'
        _..-"-.._        MUSHOKU TENSEI
     .'`  .-~~~-.  `'.     cyberArch-Dotfiles
    /   /  o o  \   \    Preparacion para Arch Linux
   |   |   >^<    |   |   ASUS TUF Gaming F15 FX506HCB
    \   \  `~~~  /   /
     `._ `-.___.-' _'
         '-._.-'
'@
    Write-Host ""
    foreach ($line in $arte -split "`r?`n") {
        if ($line -match 'MUSHOKU') { Write-Host $line -ForegroundColor DarkYellow }
        else                        { Write-Host $line -ForegroundColor Cyan }
    }
    Write-Host ""
}

# --- Reporte de la maquina ----------------------------------------------------
function Get-ReporteMaquina {
    Write-Titulo "Tu maquina"

    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name

    Write-Dato "Laptop"        "$($cs.Manufacturer) $($cs.Model)"
    Write-Dato "BIOS"          (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
    Write-Dato "CPU"           $cpu.Name
    Write-Dato "Nucleos/hilos" "$($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T"
    Write-Dato "RAM"           ("{0:N1} GB" -f ($cs.TotalPhysicalMemory / 1GB))
    Write-Dato "GPU"           ($gpu -join " + ")

    $wifi = Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True" |
            Where-Object { $_.Name -match "Wireless|Wi-Fi|WiFi" } | Select-Object -First 1
    if ($wifi) { Write-Dato "WiFi" $wifi.Name }

    # Secure Boot
    $sb = $null
    try { $sb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -ErrorAction Stop).UEFISecureBootEnabled }
    catch { }
    if ($null -ne $sb) {
        $estado = if ($sb -eq 1) { "ACTIVO (usaremos shim + grub)" } else { "inactivo" }
        Write-Dato "Secure Boot" $estado
    }

    Write-Titulo "Tus discos"
    Get-Disk | ForEach-Object {
        $d = $_
        $partes = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue |
                  ForEach-Object {
                      $etiqueta = if ($_.DriveLetter) { "$($_.DriveLetter):" } else { "   " }
                      "{0,-6}{1,8:N1} GB" -f $etiqueta, ($_.Size / 1GB)
                  }
        Write-Dato "Disk $($d.Number)" "$($d.FriendlyName)  [$($d.PartitionStyle)]  $([math]::Round($d.Size/1GB,1)) GB"
        $partes | ForEach-Object { Write-Host "      $($_.Replace('  ', '   '))" -ForegroundColor DarkGray }
    }
}

# --- Verificar la particion objetivo ------------------------------------------
function Test-ParticionObjetivo {
    Write-Titulo "Verificando la particion objetivo"

    $part = Get-Partition -DriveLetter S -ErrorAction SilentlyContinue
    if (-not $part) {
        Write-Error2 "No existe la unidad S:. No puedo confirmar la particion objetivo."
        Write-Host "        Revisa con:  Get-Volume" -ForegroundColor DarkGray
        return $false
    }

    Write-Dato "S:"            ("{0:N1} GB" -f ($part.Size/1GB))
    Write-Dato "DiskNumber"     $part.DiskNumber
    Write-Dato "PartitionNumber" $part.PartitionNumber
    Write-Dato "Offset (MB)"   ([math]::Round($part.Offset / 1MB))

    # Cuanto hay realmente ocupado. Un directorio vacio ocupa 0; lo que
    # importa es el tamano de los ARCHIVOS, no el numero de carpetas.
    # NO confiar en Get-Volume.SizeUsed: en esta maquina devuelve 0.00 GB
    # aunque hay ~0.4 GB de archivos. Un SizeUsed de 0 haria que el script
    # dijera "es seguro formatear" incluso con la particion llena.
    # Medimos de verdad sumando el tamano de los archivos.
    $vol   = Get-Volume -DriveLetter S -ErrorAction SilentlyContinue
    $libre = $vol.SizeRemaining
    $todos = @(Get-ChildItem S:\ -Force -Recurse -File -ErrorAction SilentlyContinue)
    if ($todos.Count -le 50000) {
        $usado = ($todos | Measure-Object Length -Sum).Sum
        $precision = "medido sobre $($todos.Count) archivo(s)"
    } else {
        $usado = $vol.SizeUsed
        $precision = "APROXIMADO: $($todos.Count) archivos; se uso SizeUsed"
        Write-Aviso "S: demasiados archivos para medir bien. Verificalo a mano."
    }
    if ($null -eq $usado) { $usado = 0 }
    Write-Dato "Usado / Libre" ("{0:N2} GB usado   |   {1:N1} GB libre" -f ($usado/1GB), ($libre/1GB))
    Write-Dato "Medicion"       $precision

    $items = @(Get-ChildItem S:\ -Force -ErrorAction SilentlyContinue)
    $pctUsado = [math]::Round(($usado / $vol.Size) * 100, 1)

    if ($items.Count -eq 0) {
        Write-Ok "S: esta realmente VACIA. Lista para Arch."
    }
    elseif ($usado -eq 0) {
        # Carpetas vacias y stubs de Windows: no hay ni un byte que perder.
        Write-Aviso ("S: tiene $($items.Count) carpeta(s) pero CERO archivos. Solo restos vacios.")
        Write-Ok "Es seguro formatear S: para Arch."
    }
    else {
        # Hay archivos. Separamos tres categorias:
        #   1. Papelera   -> ya los borraste tu. Se avisa, pero NO bloquea.
        #   2. Stubs      -> restos de Windows/Xbox de 0 bytes. No bloquean.
        #   3. Contenido  -> archivos de verdad fuera de la papelera. BLOQUEAN
        #                    salvo que pases -Forzar.
        $enPapelera  = @($todos | Where-Object { $_.FullName -like '*\$RECYCLE.BIN\*' })
        $fuera       = @($todos | Where-Object { $_.FullName -notlike '*\$RECYCLE.BIN\*' })
        # 1 MB como umbral: por debajo es un stub o un archivo de trabajo
        # diminuto; por encima ya es algo que se nota perder.
        $contenido   = @($fuera | Where-Object { $_.Length -ge 1MB })
        $stubs       = @($fuera | Where-Object { $_.Length -lt  1MB })

        Write-Aviso ("S: {0:N1} MB en {1} archivo(s) ({2}%)." -f ($usado/1MB), $todos.Count, $pctUsado)

        if ($enPapelera.Count -gt 0) {
            $mbPapelera = ($enPapelera | Measure-Object Length -Sum).Sum
            Write-Host ("        PAPELERA: {0} archivo(s), {1:N1} MB (ya los habias borrado; se destruyen igual)." -f $enPapelera.Count, ($mbPapelera/1MB)) -ForegroundColor DarkGray
        }

        if ($stubs.Count -gt 0) {
            Write-Host ("        STUBS DE WINDOWS (no bloquean): {0} archivo(s) de menos de 1 MB." -f $stubs.Count) -ForegroundColor DarkGray
        }

        if ($contenido.Count -gt 0) {
            Write-Host ""
            Write-Host "        CONTENIDO REAL fuera de la papelera:" -ForegroundColor White
            foreach ($a in ($contenido | Sort-Object Length -Descending)) {
                Write-Host ("        {0,10:N2} MB  {1}" -f ($a.Length/1MB), $a.FullName.Replace("S:\", "")) -ForegroundColor Yellow
            }
            Write-Host ""
            if ($Forzar) {
                Write-Aviso "Has pasado -Forzar: se continua y se destruye lo de arriba."
            }
            else {
                Write-Error2 "Copia o restaura eso a D: primero."
                Write-Error2 "Si de verdad no lo quieres, repite con -Forzar y se destruye sin preguntar."
                return $false
            }
        }
        else {
            Write-Ok "Solo papelera y stubs. Nada que te importe. S: apta para Arch."
        }
    }

    # Salida en el log para la guia de instalacion
    Write-Host ""
    Write-Host "      -> En Linux esta particion sera /dev/nvme$($part.DiskNumber)n1p$($part.PartitionNumber)" -ForegroundColor Green
    return $true
}

# --- Descargar la ISO ---------------------------------------------------------
function Get-IsoArch {
    Write-Titulo "Descargando la ISO de Arch"

    if (Test-Path $ISODestino) {
        $tam = (Get-Item $ISODestino).Length / 1MB
        if ($tam -gt 500) {
            Write-Ok "La ISO ya existe ($([math]::Round($tam)) MB): $ISODestino"
            return $true
        }
        Write-Aviso "El archivo existe pero esta incompleto. Se vuelve a descargar."
        Remove-Item $ISODestino -Force
    }

    $nombre = "archlinux-x86_64.iso"
    $url = "$Espejo/latest/$nombre"

    Write-Host "      $url" -ForegroundColor DarkGray
    Write-Host "      (descargando ~1 GB, puede tardar)" -ForegroundColor DarkGray

    try {
        curl.exe -L --fail -o $ISODestino $url
    } catch {
        Write-Error2 "Fallo la descarga: $_"
        return $false
    }

    if (-not (Test-Path $ISODestino)) {
        Write-Error2 "No se descargo la ISO."
        return $false
    }

    $tam = (Get-Item $ISODestino).Length / 1MB
    if ($tam -lt 500) {
        Write-Error2 "La ISO esta incompleta ($([math]::Round($tam)) MB). Revisa tu conexion."
        return $false
    }

    Write-Ok "ISO descargada: $ISODestino ($([math]::Round($tam)) MB)"
    return $true
}

# --- Grabar el USB ------------------------------------------------------------
function Write-IsoAlUsb {
    param([string]$Iso, [int]$Disco)

    Write-Titulo "Grabar en el USB"

    $usb = Get-Disk -Number $Disco -ErrorAction SilentlyContinue
    if (-not $usb) {
        Write-Error2 "No existe el disco numero $Disco."
        return $false
    }

    # Validacion: tiene que ser USB
    if ($usb.BusType -ne "USB") {
        Write-Error2 "El disco $Disco es de tipo $($usb.BusType), no USB. Abortando."
        return $false
    }

    # --- Comprobaciones de seguridad ------------------------------------------
    if ($usb.Size -lt 4GB) {
        Write-Error2 "El dispositivo tiene menos de 4 GB. No sirve."
        return $false
    }

    # ESTA ES LA COMPROBACION IMPORTANTE: nunca tocar el disco del sistema
    # operativo ni el de la particion objetivo.
    $discosPeligrosos = @()
    foreach ($l in @("C", "S", "D")) {
        $p = Get-Partition -DriveLetter $l -ErrorAction SilentlyContinue
        if ($p) { $discosPeligrosos += $p.DiskNumber }
    }
    $discosPeligrosos = $discosPeligrosos | Select-Object -Unique

    if ($discosPeligrosos -contains $Disco) {
        Write-Error2 "PELIGRO: el disco $Disco contiene C:, D: o S:. Grabarlo destruiria tu sistema."
        Write-Error2 "Discos protegidos detectados: $($discosPeligrosos -join ', ')"
        Write-Error2 "Abortando. Nada se modifico."
        return $false
    }

    Write-Dato "Disco"       "$Disco  $($usb.FriendlyName)"
    Write-Dato "Capacidad"   "$([math]::Round($usb.Size/1GB,1)) GB"
    Write-Dato "Tipo"        $usb.BusType
    Write-Dato "Modelo"      $($usb.SerialNumber)
    Write-Ok "Comprobacion superada: no contiene C:, D: ni S:"

    # El USB tiene que ser >= el tamano de la ISO
    if ($usb.Size -lt (Get-Item $Iso).Length) {
        Write-Error2 "El USB ($([math]::Round($usb.Size/1GB,2)) GB) es mas pequeno que la ISO."
        return $false
    }

    Write-Host ""
    Write-Host "      ESTO BORRA COMPLETAMENTE EL DISCO NUMERO $Disco" -ForegroundColor Red
    Write-Host "      ($($usb.FriendlyName)  serial $($usb.SerialNumber))" -ForegroundColor Red
    Write-Host ""

    if (-not $ConfirmarGrabado) {
        Write-Aviso "Simulacion. Para ejecutarlo de verdad:"
        Write-Host "        .\preparar-usb.ps1 -UsbNumero $Disco -ConfirmarGrabado" -ForegroundColor Yellow
        return $true
    }

    $carta = Read-Host "Escribe SI (mayusculas) para confirmar"
    if ($carta -ne "SI") {
        Write-Aviso "Cancelado. No se modifico nada."
        return $false
    }

    if (-not (Test-Admin)) {
        Write-Error2 "Se necesita PowerShell como Administrador para escribir en \\.\PhysicalDrive$Disco."
        Write-Error2 "Cierra esto y ejecuta de nuevo con:  Start-Process powershell -Verb RunAs"
        return $false
    }

    # 1. Desmontar y borrar particiones del USB. La ISO hibrida de Arch trae su
    #    propia tabla de particiones, asi que no creamos ninguna.
    Write-Host "      Desmontando y limpiando el USB..." -ForegroundColor DarkGray
    Get-Partition -DiskNumber $Disco -ErrorAction SilentlyContinue |
        Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue

    # Sin volumen montado, el kernel suelta el disco y CreateFile puede abrirlo
    # para escritura. Si falla, al menos no hay nada leyendo el dispositivo.
    try { Set-Disk -Number $Disco -IsOffline $true -ErrorAction Stop } catch { }

    # 2. Escritura CRUDA de la ISO sobre el dispositivo fisico.
    #    OJO: copiar el archivo .iso dentro de una particion NO arranca.
    #    Hay que escribir los sectores en \\.\PhysicalDriveN, como haria dd.
    #    FileStream falla aqui con ERROR_INVALID_PARAMETER: los discos raw
    #    exigen E/S sin buffer y alineada a sectores. De eso se encarga RawDisk.cs.
    Write-Host "      Escribiendo la ISO en crudo (2-5 min, no lo desconectes)..." -ForegroundColor DarkGray

    $rutaFisica = "\\.\PhysicalDrive$Disco"
    # Add-Type falla si el tipo ya esta cargado (p.ej. al re-ejecutar en la
    # misma sesion), asi que se comprueba antes.
    if (-not ("RawDiskWriter" -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot "RawDisk.cs") -ErrorAction Stop
    }

    $tamIso    = (Get-Item -LiteralPath $Iso).Length
    $tamIsoMb  = [math]::Round($tamIso / 1MB, 1)
    $impreso   = 0
    $fuente    = [System.IO.File]::OpenRead($Iso)
    $escritor  = New-Object RawDiskWriter($rutaFisica, 4)
    $total     = 0
    try {
        while ($true) {
            $n = $escritor.WriteChunk($fuente)
            if ($n -le 0) { break }
            $total += $n
            $mb = [math]::Round($total / 1MB)
            if ($mb -ge $impreso) {
                Write-Host ("`r      {0,7} MB / {1} MB" -f $mb, $tamIsoMb) -NoNewline -ForegroundColor DarkGray
                $impreso = $mb + 50
            }
        }
        $escritor.Flush()
        Write-Host ("`r      {0} MB escritos.              " -f [math]::Round($total / 1MB)) -ForegroundColor DarkGray
    }
    finally {
        $escritor.Dispose()
        $fuente.Dispose()
    }

    # 3. Verificacion real ANTES de expulsar: releer el sector 16 del disco y
    #    confirmar la firma ISO9660. El descriptor primario empieza en el sector
    #    16 (byte 0x8000) y el identificador "CD001" va un byte mas adelante,
    #    en 0x8001. Como la lectura va sin buffer solo puede empezar en
    #    multiplos de 4096, asi que se lee el bloque y se inspecciona dentro.
    $firmaTxt = "(sin verificar)"
    try {
        $bloque = [RawDiskWriter]::ReadBlock($rutaFisica, 0x8000, 4096)
        $firmaTxt = [System.Text.Encoding]::ASCII.GetString($bloque, 1, 5)
    } catch {
        Write-Aviso "No pude releer el dispositivo: $($_.Exception.Message)"
    }

    # Devolver el disco a Windows y expulsar el medio para que el firmware
    # lo lea limpio al arrancar.
    Start-Sleep -Seconds 2
    try { Set-Disk -Number $Disco -IsOnline $true -ErrorAction Stop } catch { }
    Update-HostStorageCache -ErrorAction SilentlyContinue

    $dpScript = [System.IO.Path]::GetTempFileName()
    "select disk $Disco`noffline disk`nexit" | Set-Content -Path $dpScript -Encoding ASCII
    Start-Process diskpart.exe -ArgumentList "/s `"$dpScript`"" -Wait -NoNewWindow | Out-Null
    Remove-Item $dpScript -Force -ErrorAction SilentlyContinue

    if ($firmaTxt -eq "CD001") {
        Write-Ok "Verificado: firma ISO9660 'CD001' valida en el byte 0x8001 (sector 16)."
        Write-Ok "USB listo (disco fisico $Disco)."
    } else {
        Write-Error2 "Verificacion fallida: se leyo '$firmaTxt' en vez de 'CD001'."
        Write-Error2 "El USB no arrancara. Alternativa: Rufus en modo DD, o balenaEtcher."
        return $false
    }

    Write-Host ""
    Write-Host "      Ahora reinicia, entra al BIOS con F2, y pon el USB" -ForegroundColor Cyan
    Write-Host "      como primer dispositivo de arranque (Boot Option #1)." -ForegroundColor Cyan

    return $true
}

# --- Main ---------------------------------------------------------------------
Show-Banner
Get-ReporteMaquina

$listo = Test-ParticionObjetivo

if ($SoloVerificar) {
    Write-Titulo "Resumen"
    if ($listo) {
        Write-Host "  S: apta para Arch. Nada se modifico." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Siguiente paso: docs/01-instalar-arch.md" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    }
    else {
        Write-Host "  S: requiere atencion antes de continuar. Nada se modifico." -ForegroundColor Red
        Write-Host ""
        Write-Host "  1. Copia a otra unidad lo que te importe (ver la lista de arriba)."
        Write-Host "  2. Vuelve a ejecutar con -SoloVerificar para confirmar."
        Write-Host ""
        exit 1
    }
}

if (-not $listo) {
    Write-Host ""
    Write-Error2 "La particion objetivo no esta lista. Revisa lo de arriba y vuelve a ejecutar."
    exit 1
}

Write-Host ""
$okIso = Get-IsoArch
if (-not $okIso) { exit 1 }

if ($UsbNumero -lt 0) {
    Write-Titulo "Pendrives conectados"
    Get-Disk | Where-Object { $_.BusType -eq "USB" } |
        ForEach-Object { Write-Dato "Disk $($_.Number)" "$($_.FriendlyName)  $([math]::Round($_.Size/1GB,1)) GB" }
    Write-Host ""
    Write-Host "      Usa:  .\preparar-usb.ps1 -UsbNumero N -ConfirmarGrabado" -ForegroundColor Cyan
    exit 0
}

$okUsb = Write-IsoAlUsb -Iso $ISODestino -Disco $UsbNumero

Write-Host ""
if ($okUsb) {
    Write-Host "  Siguiente paso: docs/01-instalar-arch.md" -ForegroundColor Cyan
}
Write-Host ""
