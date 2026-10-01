#!/usr/bin/env python3
"""
cyberArch-Dotfiles :: Mushoku Tensei
themes/export.py  --  Genera los formatos de color desde colors.json

    python3 export.py            # genera .conf, .css y .rasi
    python3 export.py --check    # solo verifica que esten al dia

Fuente de verdad:  colors.json
Generados:        colors.conf   (Hyprland, apps tipo *.conf)
                  colors.css    (Waybar, GTK4 web, apps tipo *.css)
                  colors.rasi   (rofi)

Nunca edites los generados a mano: se pisan con este script.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

AQUI = pathlib.Path(__file__).resolve().parent / "mushoku-tensei"
ORIGEN = AQUI / "colors.json"

CABECERA_CONF = """\
# cyberArch-Dotfiles :: Mushoku Tensei
# Formato nativo de Hyprland: `nombre = #RRGGBB`
# Generado desde colors.json por export.py -- NO EDITAR A MANO.

"""

CABECERA_CSS = """\
/* cyberArch-Dotfiles :: Mushoku Tensei
 * Formato universal tipo *.css para: waybar, hypridle, foot, gtk-4 web.
 * Generado desde colors.json por export.py -- NO EDITAR A MANO.
 */

"""

CABECERA_RASI = """\
/* cyberArch-Dotfiles :: Mushoku Tensei - formato rasi
 * Consumido por rofi (home/.config/rofi/theme.rasi lo importa con @theme).
 * OJO: dunst NO usa rasi; sus colores van en home/.config/dunst/dunstrc.
 * Generado desde colors.json por export.py - NO EDITAR A MANO.
 */
"""

# Claves del JSON -> nombres internos del tema
CLAVE_BASE = {
    "bg0_void": "bg0",
    "bg1_night": "bg1",
    "bg2_fittoa": "bg2",
    "bg3_wood": "bg3",
    "bg4_stone": "bg4",
    "fg0": "fg0",
    "fg1": "fg1",
    "fg2": "fg2",
    "fg3": "fg3",
}

ORDEN_BASE = [
    "bg0", "bg1", "bg2", "bg3", "bg4",
    "fg0", "fg1", "fg2", "fg3",
]

ORDEN_PERSONAJES = ["roxy", "eris", "sylphie", "ghislaine", "rudeus",
                    "hitogami", "lara", "ruijerd"]

ORDEN_FUNCIONAL = ["error", "success", "warning", "info", "hint",
                   "selection", "selection_fg"]


def cargar() -> dict:
    if not ORIGEN.exists():
        sys.exit(f"[x] No existe {ORIGEN}")
    with ORIGEN.open(encoding="utf-8") as fh:
        return json.load(fh)


def recolectar(datos: dict) -> dict[str, str]:
    """Devuelve {nombre_interno: '#RRGGBB'} en el orden del tema."""
    paleta: dict[str, str] = {}

    for clave_json, nombre in CLAVE_BASE.items():
        entrada = datos["base"].get(clave_json)
        if entrada:
            paleta[nombre] = entrada["hex"].upper()

    for nombre in ORDEN_PERSONAJES:
        entrada = datos["personajes"].get(nombre)
        if entrada:
            paleta[nombre] = entrada["hex"].upper()

    for nombre in ORDEN_FUNCIONAL:
        if nombre in datos["funcional"]:
            valor = datos["funcional"][nombre]
            if isinstance(valor, str):
                paleta[nombre] = valor.upper()

    return paleta


def rgba(hex_color: str, alfa: float) -> str:
    """#5BC8FF -> rgb(91,200,255) / rgba(91,200,255,0.5)"""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if alfa >= 1:
        return f"rgb({r},{g},{b})"
    return f"rgba({r},{g},{b},{alfa:g})"


def gen_conf(paleta: dict[str, str], datos: dict) -> str:
    """Formato nativo de Hyprland: `nombre = #RRGGBB`, sin bloques ni ';'.

    Hyprland NO parsea CSS, asi que este archivo no usa `* { }`.
    """
    out = [CABECERA_CONF, ""]
    out.append("# --- bases (fondo) ---")
    for n in ["bg0", "bg1", "bg2", "bg3", "bg4"]:
        out.append(f"{n:<10} = {paleta[n]}")

    out.append("")
    out.append("# --- texto ---")
    for n in ["fg0", "fg1", "fg2", "fg3"]:
        out.append(f"{n:<10} = {paleta[n]}")

    out.append("")
    out.append("# --- personajes ---")
    for n in ORDEN_PERSONAJES:
        if n in paleta:
            out.append(f"{n:<10} = {paleta[n]}")

    out.append("")
    out.append("# --- funcional ---")
    for n in ["error", "success", "warning", "info", "hint"]:
        if n in paleta:
            out.append(f"{n:<10} = {paleta[n]}")

    out.append("")
    out.append("# --- variantes rgba para decoration/animations ---")
    out.append("# Ejemplo:  active_shadow_color = rgba(1b2340cc)")
    for n in ["bg0", "bg2", "bg3", "bg4"]:
        out.append(f"#   {n}20  = {rgba(paleta[n], 0.125)}")
    out.append(f"#   roxy80      = {rgba(paleta['roxy'], 0.5)}")
    out.append(f"#   hitogami66  = {rgba(paleta['hitogami'], 0.4)}")

    return "\n".join(out) + "\n"


def gen_css(paleta: dict[str, str], datos: dict) -> str:
    out = [CABECERA_CSS]
    for n in ["bg0", "bg1", "bg2", "bg3", "bg4"]:
        out.append(f"@define-color {n:<6} {paleta[n]};")
    out.append("")
    for n in ["fg0", "fg1", "fg2", "fg3"]:
        out.append(f"@define-color {n:<6} {paleta[n]};")
    out.append("")
    for n in ORDEN_PERSONAJES:
        if n in paleta:
            out.append(f"@define-color {n:<9} {paleta[n]};")
    out.append("")
    for n in ["error", "success", "warning", "info", "hint"]:
        if n in paleta:
            out.append(f"@define-color {n:<9} {paleta[n]};")
    out.append("")
    out.append("@define-color selected_bg   "
               + f"{paleta.get('selection', paleta['bg4'])};")
    out.append("@define-color selected_fg   "
               + f"{paleta.get('selection_fg', paleta['fg0'])};")
    return "\n".join(out) + "\n"


def gen_rasi(paleta: dict[str, str], datos: dict) -> str:
    out = [CABECERA_RASI, "", "* {"]
    ancho = max(len(n) for n in paleta)
    for n in ORDEN_BASE:
        out.append(f"    {n:<{ancho}}:  {paleta[n]};")
    out.append("")
    for n in ORDEN_PERSONAJES:
        if n in paleta:
            out.append(f"    {n:<{ancho}}:  {paleta[n]};")
    out.append("")
    for n in ["error", "success", "warning", "info", "hint"]:
        if n in paleta:
            out.append(f"    {n:<{ancho}}:  {paleta[n]};")
    out.append("")
    out.append(f"    {'selected':<{ancho}}:  "
               f"{paleta.get('selection', paleta['bg4'])};")
    out.append("}")
    return "\n".join(out) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Genera los formatos de color de Mushoku Tensei")
    ap.add_argument("--check", action="store_true",
                    help="solo verifica que los generados esten al dia")
    args = ap.parse_args()

    datos = cargar()
    paleta = recolectar(datos)

    faltantes = [n for n in ORDEN_BASE if n not in paleta]
    if faltantes:
        sys.exit(f"[x] Faltan colores base en colors.json: {', '.join(faltantes)}")

    objetivo = {
        "colors.conf": gen_conf(paleta, datos),
        "colors.css": gen_css(paleta, datos),
        "colors.rasi": gen_rasi(paleta, datos),
    }

    print(f"  cyberArch-Dotfiles :: Mushoku Tensei")
    print(f"  fuente: {ORIGEN.name}   ({len(paleta)} colores)")
    print()

    desactualizados = []

    for nombre, contenido in objetivo.items():
        ruta = AQUI / nombre

        if args.check:
            actual = ruta.read_text(encoding="utf-8") if ruta.exists() else ""
            estado = "ok" if actual == contenido else "DESACTUALIZADO"
            if actual != contenido:
                desactualizados.append(nombre)
            marca = "*" if actual == contenido else "!"
            print(f"  [{marca}] {nombre:<14} {estado}")
            continue

        ruta.write_text(contenido, encoding="utf-8")
        print(f"  [+] {nombre:<14} generado ({len(contenido)} bytes)")

    print()

    if args.check:
        if desactualizados:
            print(f"  Ejecuta  python3 export.py  para regenerar.\n")
            sys.exit(1)
        print("  Todo al dia.\n")
    else:
        print(f"  Ahora:  ./install.sh --no-paquetes  y despues  hyprctl reload\n")


if __name__ == "__main__":
    main()
