# 00 · Preparar desde Windows

Antes de tocar un solo sector: backup, USB y confirmacion de que `S:` es la
particion correcta. Nada de esto es opcional.

---

## 0.1 · Tu maquina (verificada)

| | |
|---|---|
| Laptop | ASUS TUF Gaming F15 **FX506HCB** |
| BIOS | FX506HCB.316 |
| CPU | Intel Core i5-11400H (6c / 12t) |
| RAM | 24 GB |
| GPU | Intel UHD 11th gen (iGPU) + **NVIDIA RTX 3050 Laptop** |
| WiFi | MediaTek **MT7921** (WiFi 6) |
| Ethernet | Realtek Gaming GbE |
| Audio | Intel SST (SOF) + Realtek |
| Touchpad | ASUS Precision (ELAN por I2C) |
| Secure Boot | **ACTIVO** |

### Discos

| Disco | Modelo | Capacidad | Particiones |
|---|---|---|---|
| `Disk 0` | INTEL SSDPEKNU512GZ | 512 GB | p1 ESP 100 MB · p2 MSR · p3 `C:` 476 GB · p4 Recovery 0.9 GB |
| `Disk 1` | WD Green SN350 1TB | 1 TB | p1 MSR · p2 `D:` 736 GB · **p3 `S:` 195 GB (vacia)** |

**Objetivo:** Arch Linux en `Disk 1` particion 3 (la que Windows ve como `S:`),
arrancando desde la ESP que ya existe en `Disk 0`.

> **Sobre el WD Green SN350:** es un NVMe sin cache DRAM. Va a funcionar bien,
> pero notaras que el arranque y la apertura de muchas apps son mas lentos que
> en el Intel. Arch te deja arrancar por el Intel de forma permanente con
> `systemd-boot`, o mover `/boot` a un disco USB muy rapido. Si el rendimiento
> te molesta despues, lo optimizes desde el particionado.

---

## 0.2 · Backup (hazlo bien)

`S:` esta vacio, pero **Windows sigue teniendo tu vida dentro de `C:`**.
Arch instalador va a tocar la tabla GPT, la ESP y el firmware. Un fallo aqui
cuesta el equipo.

### Cosas que respaldar

```
C:/Users/Dante/
├── Documentos/
├── Escritorio/
├── Descargas/
├── Videos/
├── Imagenes/
├── Musica/
└── AppData/Roaming/    <- Recommended, Milestone, Sublime, configs de todo
```

Tambien:

- Claves de Steam / saves de juegos
- `.ssh/`, `.gnupg/`, `.aws/`, `.config/` por si usas WSL
- Cualquier thing en un segundo disco externo
- Fotos del telefono, si no estan en la nube

### Metodo recomendado

**Opcion A · imagen del disco con Clonezilla**
Barre el `Disk 0` completo a un disco externo. Es lo unico que te salva de
verdad si algo sale mal.

**Opcion B · copia manual de lo importante**

```powershell
# Desde PowerShell normal (no admin)
$destino = "E:\backup-$(Get-Date -Format yyyy-MM-dd)"
New-Item -ItemType Directory -Force $destino

# Carpetas personales
robocopy "$env:USERPROFILE\Documentos" "$destino\Documentos" /E /R:1 /W:1
robocopy "$env:USERPROFILE\Escritorio"  "$destino\Escritorio"  /E /R:1 /W:1
robocopy "$env:USERPROFILE\Descargas"   "$destino\Descargas"   /E /R:1 /W:1
robocopy "$env:USERPROFILE\Videos"      "$destino\Videos"      /E /R:1 /W:1
robocopy "$env:USERPROFILE\Imagenes"    "$destino\Imagenes"    /E /R:1 /W:1

# Configuraciones
robocopy "$env:APPDATA" "$destino\AppData-Roaming" /E /R:1 /W:1 /XD \
  "..\LocalLow" "Temp" "Code\Cache" "Microsoft\Windows"

Write-Host "Backup terminado en $destino" -ForegroundColor Green
```

Verifica que los archivos existen antes de seguir:

```powershell
Get-ChildItem $destino | Select-Object Name, @{n='GB';e={[math]::Round((Get-ChildItem $_.FullName -Recurse -File | Measure-Object Length -Sum).Sum/1GB,2)}}
```

---

## 0.3 · Verificar que `S:` es realmente la particion vacia

Este paso es el que te salva de formatear `D:` por accidente.

```powershell
# Que unidad es fisicamente cada letra
Get-Partition | Where-Object DriveLetter | Select-Object DiskNumber, PartitionNumber, DriveLetter,
    @{n='GB';e={[math]::Round($_.Size/1GB,1)}}, @{n='OffsetMB';e={[math]::Round($_.Offset/1MB)}}
```

Esperado:

```
DiskNumber PartitionNumber DriveLetter    GB  OffsetMB
---------- -------------- ----------- ----  --------
0          3              C:            475.9      117
1          2              D:            736.2       16
1          3              S:            195.3  753868
```

**`S:` = `Disk 1` particion 3, offset 753868 MB.** Guardate este dato. En Linux
esa particion aparecera como `/dev/nvme1n1p3` o `/dev/nvme0n1p3` segun como
los ordene el BIOS.

Confirma que no hay nada importante:

```powershell
Get-ChildItem S:\ -Force | Measure-Object | Select-Object Count
Get-PSDrive S | Select-Object Used, Free
```

Deberia dar `Count` 0 y `Free` ~194 GB. **Si ves archivos, borralos antes.**

---

## 0.4 · Crear el USB de instalacion

Necesitas un pendrive de **8 GB o mas**. Se borra completo.

### Opcion A · Rufus (la mas simple)

1. Descarga [Rufus](https://rufus.ie) desde su sitio oficial
2. Descarga `archlinux-x86_64.iso` desde [archlinux.org/download](https://archlinux.org/download/)
3. En Rufus:
   - **Dispositivo**: tu pendrive
   - **Seleccion de arranque**: *Seleccionar* → `archlinux-x86_64.iso`
   - **Esquema de particion**: GPT
   - **Sistema de archivos**: FAT32 (por defecto)
   - **Modo de imagen**: ISO o DD, cualquiera
4. **Iniciar**

### Opcion B · Balena Etcher (instalador grafico)

Descarga la ISO, selecciona el pendrive, dale *Flash*. Sin decisiones que tomar.

### Opcion C · desde PowerShell (sin instalar nada)

```powershell
# Descargar la ISO
curl.exe -L -o "$env:USERPROFILE\Downloads\archlinux.iso" `
  "https://geo.mirror.pkgbuild.com/iso/archlinux-x86_64.iso"

# Grabar (requiere PowerShell como ADMINISTRADOR)
# Reemplaza 3 por el numero de disco del pendrive
# VERIFICA CUAL ES EL PENDRAVE antes de ejecutar esto
Get-Disk | Format-Table Number, FriendlyName, Size, PartitionStyle
```

Anota el numero del pendrive y ejecuta:

```powershell
# DESTRUCTIVO. Substituye el numero por el de tu pendrive.
$usb = 3
$iso = "$env:USERPROFILE\Downloads\archlinux.iso"

# Quitar particiones del pendrive
Get-Partition -DiskNumber $usb | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue

# Montar como FAT32 y copiar
$letter = "E"
$vol = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if (-not $vol) { New-Partition -DiskNumber $usb -UseMaximumSize -DriveLetter $letter -IsActive | Format-Volume -FileSystem FAT32 -NewFileSystemLabel ARCH | Out-Null }

Remove-Item "$($letter):\*" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $iso "$($letter):\archlinux.iso" -Force

Write-Host "USB listo: $($letter):\archlinux.iso" -ForegroundColor Green
```

> A partir de aqui, el pendrive se arranca desde el BIOS. En una ASUS TUF:
> enciende, presiona `F2` repetidamente, ve a **Boot**, y pon el USB arriba.

---

## 0.5 · Ajustes de BIOS recommended

Entra con `F2` (o `Fn+F2`). En **Advanced** / **Security**:

| Ajuste | Valor | Por que |
|---|---|---|
| Secure Boot | **Enabled** (dejalo asi) | vamos a usar `shim`, no hay que apagarlo |
| Boot Mode | **UEFI** | obligatorio, no uses CSM/Legacy |
| Fast Boot | **Disabled** | evita que el USB no aparezca |
| Virtualization (VT-x) | Enabled | necesario para el aislamiento de procesos |
| OS Boot entry | tu USB | |

En **Boot**: asegura que el USB esta en el **primer** puesto de Boot Option #1.

**Opcional** en el mismo BIOS:

- **Graphic Device Mode** → *Hybrid Graphics* (usa Intel + NVIDIA). Si lo pones
  en *NVIDIA GPU only*, la sesion Wayland tendra mas problemas y no lo
  soportamos en esta guia.
- **Battery Health Charging** → *Balanced* (o 60% fijo, que es lo que aplica
  `asusctl`).

---

## 0.6 · Check list antes de arrancar el instalador

- [ ] Backup hecho y **verificado** (abri archivos desde el)
- [ ] `S:` confirmado vacio (`Count = 0`)
- [ ] USB de Arch flasheado y arranca en modo UEFI
- [ ] Secure Boot sigue activo
- [ ] Guardaste: `Disk 1`, particion `3`, offset `753868` MB
- [ ] Carregador de Windows arranca bien todavia

Siguiente: [`01-instalar-arch.md`](01-instalar-arch.md)
