# 01 · Instalar Arch en la FX506HCB

Instalador **por consola, manual**, paso a paso. Pensado para dejar Windows
intacto y arrancar en dual boot con Secure Boot activo.

> **Que hace este guide:** borra y reformatea **solo** `S:` (195.3 GB), comparte
> la ESP que Windows ya tiene, e instala GRUB. Nada mas.
>
> **Que NO hace:** tocar `C:`, `D:`, la particion de recuperación, ni la ESP
> existente (solo escribe dentro de `EFI/arch/`).

---

## Mapa de particiones objetivo

```
Disk 0 -- INTEL SSDPEKNU512GZ (512 GB)          [ NO SE TOCA ]
├── p1  100 MB   ESP (FAT32)      -> /boot/efi   <- se monta, se usa
├── p2   16 MB   MSR
├── p3  475.9 GB ntfs  C:         <- Windows, intacta
└── p4   0.9 GB ntfs  Recovery    <- intacta

Disk 1 -- WD Green SN350 1TB (1 TB)              [ ARCH VA AQUI ]
├── p1   16 MB   MSR                             <- intacta
├── p2  736.2 GB ntfs  D:         <- NO SE TOCA
└── p3  195.3 GB ntfs  S:         <- SE BORRA -> ext4 -> /
```

**Regla de oro:** confirma siempre por el **tamano (931.5G)**, nunca por el
nombre del dispositivo. Si tu BIOS enumera los NVMe al reves, `nvme1n1` seria el
de Windows.

> **Nota sobre `archinstall`:** existe y es comodo, pero intenta administrar las
> particiones por ti y aqui necesitamos reutilizar una particion existente y
> compartir la ESP de Windows. Por eso esta guia es manual y sin `archinstall`.

---

## 1.1 · Arrancar el instalador

1. USB conectado, reinicia la laptop
2. Entra al BIOS con `F2` al inicio
3. Verifica **Boot Option #1** = tu USB
4. Guarda y reinicia
5. Selecciona el USB en el menu de arranque

Deberias ver el menu de arranque de Arch.

Si el USB arranca como **Legacy** (pantalla negra con `syslinux`), no sigas.
Apagate, `F2`, y pon **Boot Mode: UEFI**.

---

## 1.2 · Consola, teclado y red

```bash
# Teclado US por defecto; ajusta mas abajo si el tuyo es LatAm/Espana
loadkeys us

# Consola legible
setfont ter-132n

# Red por cable (el WiFi del instalador suele fallar)
ip link set eth0 up
dhcpcd
```

### Si tu teclado es Latinoamericano o Español

```bash
loadkeys es-latinamerican       # si tu distro lo trae
loadkeys es                    # si no
```

Disponibles: `ls /usr/share/kbd/keymaps/i386/qwerty/`

### Si de verdad necesitas internet en el instalador

```bash
ip link set wlan0 up
iwctl
> [iwd]# station wlan0 connect NOMBRE_DE_TU_WIFI
> [iwd]# station wlan0 activate
```

---

## 1.3 · Particionar y montar

### Desmonta lo que haya montado

```bash
umount -R /mnt 2>/dev/null
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT
```

Confirma que el de 195.3 GB es la tercera particion del disco de 931.5G.

### Borra la firma de `S:` y crea ext4

```bash
# ADVERTENCIA: esto destruye todo lo que haya en S: (195.3 GB, particion 3
# del disco de 931.5 GB).

# Confirmacion visual antes de borrar:
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/nvme1n1

# 1. Borra las firmas (GPT, NTFS). NO toca la tabla de particiones.
wipefs -a /dev/nvme1n1p3

# 2. Crea el sistema de archivos
mkfs.ext4 -L archlinux /dev/nvme1n1p3
```

> **Por que `wipefs` y no `sgdisk --zap-all`:** `sgdisk` espera un **disco
> completo**, no una particion. Pasarle una particion falla o, si te equivocas de
> argumento, manda a la basura la tabla GPT entera del disco. `wipefs -a` borra
> justo las firmas de la particion y deja el resto del disco intacto.

### Monta la raiz y la ESP

```bash
mount /dev/nvme1n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

Comprueba:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT /dev/nvme0n1 /dev/nvme1n1
df -h /mnt
```

Debe verse `archlinux` montado en `/mnt` y la ESP en `/mnt/boot/efi`.
Si algo no coincide: `umount -R /mnt` y rehazlo.

---

## 1.4 · Base del sistema (`pacstrap`)

Este paso **no se puede saltar**: sin el, `/mnt` esta vacio y `pacman` instalaria
todo en la RAM del live, que se pierde al reiniciar.

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode \
    zram-generator sudo networkmanager networkmanager-wifi iwd \
    grub shim efibootmgr os-prober git wget curl

genfstab -U /mnt >> /mnt/etc/fstab
```

`genfstab -U` genera el `fstab` con los UUID correctos (raiz y ESP).

Anota el UUID de la raiz, lo usas en el diagnostico:

```bash
blkid -s UUID -o value /dev/nvme1n1p3
```

### Entra al chroot

```bash
arch-chroot /mnt
```

> **A partir de aqui estas DENTRO del sistema instalado.** Todo lo que escribas
> en `/etc/...` va al disco duro, no a la RAM del live. Si necesitas salir:
> `exit`.

---

## 1.5 · Locales y zona horaria (dentro del chroot)

```bash
# Zona horaria: USA la tuya
ln -s /usr/share/zoneinfo/America/Mexico_City /etc/localtime
# ln -s /usr/share/zoneinfo/Europe/Madrid     /etc/localtime

# Reloj en UTC (correcto para arranque dual con Windows)
hwclock --systohc --utc

# Locales
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
echo "es_MX.UTF-8 UTF-8" >> /etc/locale.gen   # o es_ES.UTF-8 segun tu teclado
locale-gen

echo "LANG=es_MX.UTF-8" > /etc/locale.conf
echo 'export LANGUAGE=es' >> /etc/locale.conf

# Consola
echo 'KEYMAP=us' > /etc/vconsole.conf
echo 'FONT=ter-132n' >> /etc/vconsole.conf
```

### Keyboard en espanol

```bash
pacman -S --needed xf86-input-libinput
```

---

## 1.6 · Hostname y red (dentro del chroot)

```bash
echo "fittoa" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1        localhost ip6-localhost ip6-loopback
EOF

# DNS con systemd-resolved (incluido)
ln -s /usr/share/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl enable NetworkManager.service
systemctl enable iwd.service
```

---

## 1.7 · Contraseñas y usuario (dentro del chroot)

```bash
passwd root

useradd -m -G wheel,audio,video,input,storage,power,network,usb,rfkill -s /bin/bash rudeus
passwd rudeus

# sudo para %wheel (Arch lo trae comentado por defecto)
EDITOR=nano visudo
```

En `visudo`, descomenta la linea:

```
%wheel ALL=(ALL:ALL) ALL
```

---

## 1.8 · Actualiza el sistema (dentro del chroot)

```bash
pacman -Syu
```

---

## 1.9 · Swap: zram (dentro del chroot)

Con 24 GB de RAM no necesitas swap en disco. `zram-generator` ya crea
`/dev/zram0` solo al arrancar: **no hay que tocar nada mas** (no va en
`mkinitcpio.conf`, es un generador de systemd).

```bash
systemctl enable zram-generator   # normalmente ya activo
```

---

## 1.10 · initramfs (dentro del chroot)

```bash
mkinitcpio -P
```

> **No pongas `intel-ucode` en `MODULES()`.** El microcode no es un modulo del
> kernel: se carga con el hook `microcode`, que ya viene dentro de `base` en
> mkinitcpio >= 36. Como `intel-ucode` se instalo en el `pacstrap` (1.4),
> `mkinitcpio -P` ya lo incluye automaticamente.
>
> Si aun asi te pide microcode, tu `mkinitcpio.conf` es antiguo. Comprueba:
> `grep HOOKS /etc/mkinitcpio.conf` debe incluir `base ... udev ...`.

`intel-ucode` es **obligatorio** en tu i5-11400H (Ice Lake) para estabilidad.

---

## 1.11 · GRUB + shim, con Secure Boot activo (dentro del chroot)

Tu BIOS tiene **Secure Boot ENABLED**. Usamos `shim`, firmado por Microsoft, para
que Windows siga cumpliendo y Arch tambien arranque.

Ya instalaste `grub shim efibootmgr os-prober` en el paso 1.4.

### Instala GRUB en la ESP

Adentro del chroot la ESP esta en `/boot/efi` (sin el `/mnt`):

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
```

### Instala la cadena firmada `shim -> grub`

```bash
mkdir -p /boot/efi/EFI/arch

cp /usr/share/shim/x64/shimx64.efi /boot/efi/EFI/arch/
cp /usr/share/shim/x64/mmx64.efi   /boot/efi/EFI/arch/
cp /usr/share/shim/x64/fbx64.efi   /boot/efi/EFI/arch/

# shim busca grubx64.efi en \EFI\arch\ primero
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/arch/
```

### Configura GRUB

```bash
# Menú visible de 4 s con Windows al lado
sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=4/' /etc/default/grub
sed -i 's/^#\?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=auto/' /etc/default/grub

grep -q '^GRUB_LANG=' /etc/default/grub || echo 'GRUB_LANG=en_US.UTF-8' >> /etc/default/grub
grep -q '^GRUB_TERMINAL_OUTPUT=' /etc/default/grub || \
    echo 'GRUB_TERMINAL_OUTPUT="gfxterm gfxterm_color"' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
```

Verifica que Windows quedo incluido:

```bash
grep -i "Windows Boot Manager" /boot/grub/grub.cfg
```

Debe listar `Windows Boot Manager (loader/glyph)`. Si no aparece, el problema es
que GRUB no ve la ESP de Windows: comprueba que la particion de 100 MB en
`nvme0n1` tiene el flag de arranque:

```bash
ls /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi
```

### Si shim no acepta GRUB

En algunas firmwares shim rechaza `grubx64.efi` por firma. Si al arrancar sale
`Verification failed` o `Bad signature`, enrolla una clave propia:

```bash
pacman -S --needed sbctl
sbctl enroll-key /usr/share/pkcs11/keys/MOK/Arch_Linux_manual_signing.der
sbctl sign-all -s
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Reinicia y en el **MokManager** (azul, del firmware) elige *Enroll key*,
introduce el password que fijaste, y reinicia otra vez.

---

## 1.12 · Salir, desmontar, reiniciar

```bash
exit                    # sales del chroot (vuelves al live)

umount -R /mnt
reboot
```

Saca el USB cuando aparezca el menu de arranque.

Deberia aparecer el menu de **GRUB** con:

```
Arch Linux
Windows Boot Manager
```

---

## 1.13 · Diagnostico: si no arranca Windows desde GRUB

Todo esto se ejecuta **con Arch ya arrancado** (no en el chroot).

Comprueba el estado de Secure Boot:

```bash
bootctl status
```

Reinstala la cadena de shim:

```bash
mount /dev/nvme0n1p1 /boot/efi          # normalmente ya montada
mkdir -p /boot/efi/EFI/arch
cp /usr/share/shim/x64/shimx64.efi /boot/efi/EFI/arch/
cp /usr/share/shim/x64/mmx64.efi   /boot/efi/EFI/arch/
cp /usr/share/shim/x64/fbx64.efi   /boot/efi/EFI/arch/
cp /boot/efi/EFI/GRUB/grubx64.efi  /boot/efi/EFI/arch/
grub-mkconfig -o /boot/grub/grub.cfg
```

Mas soluciones en [`04-resolucion-problemas.md`](04-resolucion-problemas.md).

---

## 1.14 · Alternativas de arranque

### Opcion A · `systemd-boot` en vez de GRUB

```bash
bootctl --esp-path=/boot/efi install
pacman -S efibootmgr
```

Desactiva el flag `auto` de GRUB en la ESP para que no compitan:

```bash
efibootmgr -c /boot/efi/EFI/systemd/systemd-bootx64.efi "Arch Linux"
```

### Opcion B · Que el menu sea el de Windows

Si prefieres arrancar desde el Windows Boot Manager, genera las entradas con
`grub-install` y despues:

```powershell
# Desde Windows, PowerShell como Administrador
bcdedit /enum firmware
```

Consultar la wiki de Arch sobre `EFISTUB` si quieres que Windows llame a
`EFI/arch/loader.efi`. Es mas fragil con Secure Boot; **no es la recomendada.**

---

## Siguiente

[`02-postinstall.md`](02-postinstall.md) — GPU (Intel + RTX 3050 via PRIME), wifi
MT7921, audio SOF, herramientas ASUS, Hyprland.
