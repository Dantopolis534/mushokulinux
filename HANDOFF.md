# HANDOFF.md — Contexto de trabajo para otra sesión

> **Si estás leyendo esto como asistente nuevo:** este archivo existe para que
> puedas continuar el proyecto sin la conversación original. Léelo entero
> antes de tocar nada. Está escrito para que lo consuma otra IA, no una
> persona, aunque también sirve de índice.

---

## 1. Qué es este proyecto

Repo de dotfiles para Arch Linux, estilo minimalista con tema **Mushoku
Tensei** ( anime). Escritorio Hyprland + Waybar, Rofi, Dunst, Kitty, zsh con
prompt de themed. El objetivo del usuario es **instalar Arch en su laptop y
aplicar estos dotfiles**, no solo mantenerlos.

**Idioma: el usuario escribe en español. Respóndele siempre en español.**

No está en git (decisión pendiente, ver §8). No hay CI. No hay tests
unitarios; la verificación es por parseo y validación cruzada (§5).

### Orden de lectura sugerido

1. Este archivo
2. `README.md` — flujo general
3. `docs/INSTALL-PRIMERA-VEZ.md` — **donde está el usuario ahora mismo**
4. `docs/02-postinstall.md` — lo que sigue tras instalar
5. `install.sh` — el instalador, lee todo lo que instala

---

## 2. Hardware (exacto, verificado)

```
Laptop        ASUSTeK ASUS TUF Gaming F15  FX506HCB_FX506HCB
BIOS          FX506HCB.316
CPU           Intel Core i5-11400H @ 2.70GHz  (6C/12T, Rocket Lake)
GPU           Intel UHD (integrada) + NVIDIA GeForce RTX 3050 Laptop
RAM           23.7 GB
WiFi          MediaTek MT7921 (WiFi 6)
Discos        Disk 0  Intel SSDPEKNU512GZ   476.9 GB  (C:)
              Disk 1  WD Green SN350 1TB    931.5 GB  (D: y S:)
              USB     UFD 2.0 Silicon-Power8G 7.2 GB
```

### Decisiones de hardware que DEBES respetar

- **Hyprland corre en la Intel iGPU.** NVIDIA solo bajo demanda vía PRIME.
  Está configurado en `/etc/prime-run.conf` y `switcherooctl`. No pongas
  Hyprland en la RTX.
- **`intel-ucode` es obligatorio** en la instalación. El Rocket Lake se
  desestabiliza sin microcódigo.
- **Secure Boot: hoy apagado, se reactiva al final con `sbctl`.** Ver §7.

---

## 3. Discos — la parte más peligrosa

**El numerado de discos cambia entre Windows y Linux.** La regla de oro es
identificar por **tamaño**, nunca por `/dev/nvmeXn1`.

| Tamaño | Windows | Linux | Acción |
|---|---|---|---|
| 476.9 GB | `C:` | `/dev/nvme0n1` | Solo montar `p1` (100 MB, ESP) en `/boot/efi` |
| ~736 GB | `D:` | `/dev/nvme1n1p1` | **NO TOCAR NUNCA** |
| 195.3 GB | `S:` | `/dev/nvme1n1p3` | Destino de Arch. `mkfs.ext4` |
| 7.2 GB | `F:` | `/dev/sda` | USB de arranque |

**Prohibido literal** (borra 931 GB, incluido `D:`):

```bash
parted /dev/nvme1n1 mklabel gpt
```

La tabla de particiones de `nvme1n1` ya es correcta. Solo hace falta:

```bash
mkfs.ext4 -L arch /dev/nvme1n1p3
```

**BitLocker: NO activo** (comprobado con `manage-bde -status`). Esto es lo que
permite apagar Secure Boot sin riesgo de clave de recuperación. Si algún día
se activa, esta guía deja de ser válida tal cual.

### Estado de `S:`

Vacío en lo que importa. 194.6 GB libres de 195.3. Los 402.8 MB que quedan
son papelera de Windows y 3 stubs de 0 bytes. El usuario dijo explícitamente
que no le importan y autorizó destruirlos.

---

## 4. Convenciones del repo (léelas, se rompen fácil)

1. **ASCII puro en configuración y scripts.** Ni acentos, ni `—`, ni `→`, ni
   emojis en `home/`, `themes/`, `scripts/`, `install.sh`. Esos archivos los
   consumen parsers y terminales que no los manejan bien. Usa `-` y `->`.
   La documentación en `docs/` y los `.md` sí pueden llevar acentos (UTF-8).
   Si se te escapa un carácter no-ASCII a un archivo de configuración, casi
   ningún validador te lo va a señalar: revísalo a ojo.
2. **Los comentarios de PowerShell usan `#`, no `//`.** Los de C# usan `//`.
   Rasi y JSONC **no admiten** comentarios `//` en posiciones arbitrarias.
3. **`themes/mushoku-tensei/colors.json` es la fuente de verdad.** Los
   archivos `colors.conf`, `colors.css` y `colors.rasi` se **generan** con
   `themes/export.py`. Nunca los edites a mano: se sobrescriben.
   Después de cambiar `colors.json`, ejecuta `python3 themes/export.py`.
4. En Hyprland la variable de modificadores es `$mainMod`, **no** `$mainPort`.
5. SVG: los comentarios XML no pueden contener `--`. En CSS (dentro de
   `<style>`) `/* */` sí vale.
6. Rasi: sin comentarios, sin variables `@`, sin bloques huérfanos.

---

## 5. Verificación — comandos que sí funcionan

El usuario tiene **WSL (kali-linux)**, así que hay parsers de Linux
disponibles desde Windows. Todos estos pasan hoy:

```bash
# Bash (8 scripts)
for f in install.sh home/.bashrc home/.profile home/.config/shell/*.sh \
         home/.config/rofi/scripts.sh home/.local/bin/mt-temperatura; do
  bash -n "$f" || echo "FALLA $f"
done

# Zsh
zsh -n home/.zshrc

# Fish  <-- NO DISPONIBLE: fish no está instalado en WSL
# fish -n home/.config/fish/config.fish

# JSONC (necesita quitar comentarios primero)
python3 -c "import json,sys; ..." home/.config/waybar/config.jsonc
python3 themes/export.py --check

# SVG
for f in assets/wallpapers/*.svg; do xmllint --noout "$f"; done
```

En PowerShell (Windows):

```powershell
# PowerShell
$errs=$null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\preparar-usb.ps1",[ref]$null,[ref]$errs) | Out-Null
$errs.Count   # 0 = OK

# C# del helper raw
Add-Type -Path scripts\RawDisk.cs -ErrorAction Stop
```

### Limitación conocida

La sesión del asistente **no corre como Administrador**. Por eso no puede
escribir en `\\.\PhysicalDriveN` ni abrir `Get-Disk` para pruebas reales. El
usuario debe ejecutar en su propia consola elevada. Si necesitas que algo se
pruebe de verdad, pídele que lo corra él y te pegue la salida.

---

## 6. Estado actual

### Hecho y verificado

- **Estructura completa** del repo, 52 archivos, ~215 KB.
- **5 SVG** de Mushoku Tensei válidos como XML.
- **Hyprland** dividido en `conf.d/`: `envs`, `autostart`, `monitor`,
  `workspaces`, `rules`, `theme`, `binds`, más `hyprpaper`, `hypridle`,
  `hyprlock` y el `hyprland.conf` raíz.
- **Waybar** con launcher corregido a `rofi -show drun -show-icons`
  (el binario `launcher` que se usaba antes no existe).
- **Rofi** con `theme.rasi` y `scripts.sh` válidos.
- **Dunst** con colores INI reales. Se borró un `theme.rasi` que estaba roto.
- **fastfetch** con `mushoku.jsonc`. Los escapes octales `\033` se cambiaron a
  `\u001b` porque no funcionaban.
- **`themes/export.py`** genera y verifica `colors.conf` / `colors.css` /
  `colors.rasi` desde `colors.json`.
- **`install.sh`** (15.8 KB) con idempotencia, `--dry-run`, y conversión
  SVG→PNG para los fondos.
- **Docs 00-04** revisadas y corregidas contra el código real (rutas de
  archivos, comandos de pacman, flags de prime-run, nvidia_drm, greetd).
- **`scripts/preparar-usb.ps1`** + **`scripts/RawDisk.cs`**: verificación de
  hardware y grabación del USB. Probado en la máquina real.
- **`docs/INSTALL-PRIMERA-VEZ.md`**: guía autocontenida para instalar sin
  ayuda.

### Bugs encontrados y corregidos (no reintroducirlos)

Estos los descubrimos probando de verdad, no leyendo. Están arreglados:

1. **Escritura raw con `FileStream` es imposible.** Windows rechaza con
   `ERROR_INVALID_PARAMETER` ("El parámetro no es correcto") cualquier
   escritura *bufferizada* a `\\.\PhysicalDriveN`. Exige
   `FILE_FLAG_NO_BUFFERING`, longitud múltiplo de sector y puntero alineado.
   Por eso existe `scripts/RawDisk.cs`. **No lo reemplaces por `FileStream`.**
2. **La firma ISO9660 está en `0x8001`, no en `0x8000`.** El descriptor
   primario empieza en el sector 16 (`0x8000`) pero lleva un byte de tipo
   delante. Comprobado sobre la ISO real: `0x8000..4` = `CD00`,
   `0x8001..5` = `CD001`. El código viejo habría reportado "verificación
   fallida" con una escritura perfecta.
3. **`Get-Volume.SizeUsed` miente.** Reportaba `0.00 GB` con 402 MB reales.
   El script ahora enumera archivos con `Get-ChildItem`.
4. **`Write-Dato "RAM" "{0:N1} GB" -f (...)` imprimía el formato literal**,
   no el valor. Faltaban paréntesis. Pasaba por
   `Write-Output "x" "{0}" -f $v`, donde `-f` se aplicaba a la línea
   entera. Todas las llamadas usan ahora `Write-Output ("fmt" -f $val)`.
5. **Bugs de here-string en el banner:** los backticks del arte ASCII se
   consumían como escapes. Resuelto con `@'...'@`.
6. **Gate de seguridad demasiado estricto:** bloqueaba por stubs de 0 bytes
   y no había forma de pasar. Ahora hay tres niveles — papelera (solo avisa),
   stubs <1 MB (no bloquean), contenido ≥1 MB (bloquea salvo `-Forzar`).
   Probado en las dos direcciones.
7. `Add-Type -Path` falla si el tipo ya está cargado. El script comprueba
   `if (-not ("RawDiskWriter" -as [type]))` antes de cargarlo.

### Pendiente

- Validación en runtime: Hyprland, Waybar, Rofi, Dunst, GPU, audio. **Nada
  de esto se ha ejecutado nunca en Linux.** Solo se parseó.
- `intel-ucode` y la cadena GRUB: nunca probados en hardware.
- `docs/01-instalar-arch.md` describe la ruta con `shim` + Secure Boot
  activado. **Hoy la decisión es la contraria** (§7). Los dos documentos
  están en conflicto a propósito; `INSTALL-PRIMERA-VEZ.md` es el vigente.
- **No existe `paquete.sh`**, que estaba en el plan original.
- **Faltan sonidos** y extras de inmersión del tema.
- Sin `mt-persona` funcionando. `home/.local/bin/mt-temperatura` sí existe.
- Sin git. Considerado como red de seguridad dado el punto §1.

---

## 7. Secure Boot: decisión que cambió

Inicialmente se decidió mantener Secure Boot **activo** con la cadena
`shim` + GRUB, para no tocar la ESP de Windows.

**Se revirtió** cuando el usuario dijo que instalaria **sin ayuda**. Con Secure
Boot apagado + GRUB plano el resultado es predecible; con `shim` son 6+ pasos
y si uno falla la laptop no arranca sin nadie a quien llamar.

| | Secure Boot ON + shim | Secure Boot OFF + GRUB |
|---|---|---|
| Arranca | Sí, pero 6 pasos | Sí, garantizado |
| Riesgo | Sistema no arrancable | Ninguno |
| Windows | Perfecto | Perfecto (no hay BitLocker) |

Al terminar la instalación, `sbctl` para firmar kernel, initramfs y módulos.
Está documentado en `docs/02-postinstall.md`.

---

## 8. Dónde está el usuario ahora mismo

1. ✅ Repo creado y validado
2. ✅ ISO de Arch descargada y verificada (`SHA256` coincide con el mirror)
3. ✅ USB grabado y verificado (`CD001` en `0x8001`)
4. ⬜ **Aquí.** Va a reiniciar, entrar a la BIOS y seguir
   `docs/INSTALL-PRIMERA-VEZ.md`
5. ⬜ Instalación base de Arch
6. ⬜ `docs/02-postinstall.md` (NVIDIA, PRIME, ASUS, MT7921, greetd)
7. ⬜ `./install.sh --dry-run` y luego `./install.sh`
8. ⬜ Tema Mushoku Tensei

**Antes de reiniciar** tiene que quitar el volumen del USB desde
`diskmgmt.msc` (click derecho → "Quitar volumen"), porque Windows lo re-montó
automáticamente y podría escribir sobre la ISO.

---

## 9. Preguntas abiertas para el usuario

Ninguna bloqueante, pero conviene confirmarlas:

- ¿Inicializar git en el repo?
- ¿Los sounds y `paquete.sh` siguen siendo requisito, o se descartan?
- ¿Confirmar hostname `fittoa` y zona `America/Mexico_City`?
- ¿`LANG=es_MX.UTF-8` o `en_US.UTF-8`? La guía asume español.
- ¿Contraseña de WiFi para la instalación? (la necesita en `iwctl`)

---

## 10. Si estás corriendo EN LINUX (sesión de OpenCode ya instalada)

Esto cambia el repo por completo. En Windows solo se podía **parsear**; en
Linux puedes **ejecutar de verdad**.

### Dónde está el repo

En Windows vive en:

```
C:\Users\Dante\Documents\Default Project\cyberArch-Dotfiles
```

En Linux, después de instalar, colócalo en tu `$HOME`:

```bash
mkdir -p ~/cyberArch-Dotfiles
```

y cópialo desde la partición de Windows (solo lectura, para no tocar nada):

```bash
# desmonta si ya lo esta
sudo umount /mnt 2>/dev/null
sudo mount -o ro,uid=$(id -u),gid=$(id -g) /dev/nvme0n1p3 /mnt
cp -r "/mnt/Users/Dante/Documents/Default Project/cyberArch-Dotfiles/." ~/cyberArch-Dotfiles/
sudo umount /mnt
```

> Si `cp` se queja de nombres de archivo inválidos (NTFS usa caracteres que
> a veces no existen en Linux), usa `rsync` o `cp -r --no-preserve=mode`.
> Los nombres del repo son ASCII, así que normalmente funciona directo.

### Qué ahora sí puedes validar

Estos validadores **no existían** en la sesión de Windows:

```bash
# Fish por fin
sudo pacman -S --needed fish
fish -n ~/.config/fish/config.fish
fish -c 'source ~/.config/fish/config.fish'

# Hyprland: parser real, no solo grep
hyprctl version
# validar el ensamblado completo
hyprctl reload

# Comprobar que el prompt se genera
zsh -ic 'echo $PROMPT' | head -20

# Wallpapers convertidos a PNG de verdad
file ~/.local/share/wallpapers/*.png

# Verificar colores generados
python3 ~/cyberArch-Dotfiles/themes/export.py --check

# Rofi: preguntar al binario si el tema carga
rofi -no-config -theme ~/.config/rofi/theme.rasi -dmenu -dump-theme | head

# Dunst
dunst -print-config-syntax 2>&1 | head -20
```

### Prioridad de trabajo sugerida

Con la sesión de Linux el orden de ataque cambia. Lo que era imposible pasa
a ser lo prioritario:

1. **`./install.sh --dry-run` y ver qué reporta.** Nunca se ejecutó.
2. **Arrancar Hyprland y arreglar lo que reviente.** El 100% de los errores
   de runtime están ahí, porque nada se ha ejecutado nunca.
3. `hyprctl` para confirmar binds, monitores y workspaces reales.
4. NVIDIA bajo demanda con `prime-run glxinfo | grep renderer` — confirmar que
   sale la RTX, y que el día a día sale la Intel.
5. Fish y zsh, que nunca se ejecutaron.
6. Solo despues, mas extras del tema.

### Cuidado

- **No borres nada de `D:` ni de `C:`.** El repo está en `C:`. Si borras o
  reformateas por error, pierdes el trabajo.
- Mountea la partición de Windows **siempre en solo lectura** (`-o ro`) para
  copiar. Escribir en NTFS desde Linux con ntfs3 puede corromperlo.
- Si algo de `install.sh` intenta tocar `/boot` o `/efi`, que lo reporte en
  vez de ejecutarlo.

---

## 11. Cómo trabajar aquí

- **Verifica, no supongas.** Cada cambio se validó ejecutando el parser
  correspondiente. Mantén esa costumbre; several bugs de este repo solo
  aparecieron al ejecutar, no al leer.
- Si no puedes probar algo en tu entorno, **dilo explícitamente** en lugar
  de afirmar que funciona.
- El usuario agradece el detalle técnico y las tablas comparativas. Pero
  sus mensajes son cortos: sé conciso y ve al grano.
- No ejecutes operaciones destructivas (particiones, mklabel, formatear) sin
  confirmación explícita.
