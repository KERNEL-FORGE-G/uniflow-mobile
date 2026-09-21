#!/usr/bin/env python3
"""Fabrique les icônes d'application UniFlow à partir de l'écusson de marque.

    python3 tools/generer-icones-uniflow.py                 # écrit le jeu d'icônes
    python3 tools/generer-icones-uniflow.py --apercu DIR     # planches A/B, sans rien écrire dans le dépôt
    python3 tools/generer-icones-uniflow.py --icone-512 F    # exporte en plus l'icône boutique 512 px
    python3 tools/generer-icones-uniflow.py --variante B     # essai de l'autre candidat

Source (dans assets/brand/) : `uniflow_marque.png`, l'écusson carré détouré par
le propriétaire — toque bleu marine, « U » fléché bleu → turquoise, traces de
circuit blanches. C'est un PNG 512 px ; `IMAGES-UNIFLOW/logos/uniflow-logo.svg`
n'est PAS le même dessin (toque en losange, tresse et nœuds redessinés), on ne
s'en sert donc pas, et aucun rendu vectoriel n'est disponible sur cette
machine (ni cairosvg, ni rsvg-convert, ni inkscape). La netteté vient d'un
redimensionnement en alpha prémultiplié suivi d'un léger masque flou inversé
(unsharp) — jamais d'un flou.

Ce que le script écrit
----------------------
android/app/src/main/res/
    mipmap-<densité>/ic_launcher.png             icône héritée (Android < 8, lanceurs sans adaptatif)
    mipmap-<densité>/ic_launcher_round.png       idem, en rond (android:roundIcon)
    mipmap-<densité>/ic_launcher_foreground.png  couche avant adaptative, 108dp
    mipmap-<densité>/ic_launcher_background.png  couche de fond adaptative, 108dp (dégradé)
    mipmap-<densité>/ic_launcher_monochrome.png  couche <monochrome>, icônes thématiques Android 13+
    mipmap-anydpi-v26/ic_launcher.xml, ic_launcher_round.xml
    drawable-<densité>/ic_stat_uniflow.png       silhouette blanche 24dp pour la barre d'état
    drawable-<densité>/splash_ecusson.png        disque de 192dp de l'écran de lancement (Android < 12)
docs/design/icone-android.png                    planche de l'icône retenue
macos/, windows/, web/                           si ces dossiers existent (ce n'est pas le cas du mobile)

Le choix : variante A, tuile claire (décision du 2026-09-21)
-------------------------------------------------------------
Symptôme observé : l'icône précédente posait l'écusson sur un aplat bleu marine
`#1e3a8a`, c'est-à-dire la couleur de la toque elle-même. À 48 dp la toque
disparaissait dans le fond et il ne restait qu'un demi-« U » turquoise : le
lanceur montrait une pastille bleue avec une virgule verte.

Deux candidats ont été rendus côte à côte (`--apercu`) à 48, 72 et 108 px,
masques cercle et carré arrondi, sur lanceur clair et sombre :

  A. tuile claire, dégradé radial blanc → bleu pâle `#bfdbfe` au bord du
     disque visible, écusson en couleurs pleines ;
  B. dégradé de marque `#1d4ed8` → `#0d9488` et l'écusson en glyphe blanc.

A est retenue : à 48 px la toque, le « U » bicolore et même les traces de
circuit restent lisibles, sur fond clair comme sombre. B est propre mais perd
le bicolore et les traces (une silhouette n'a qu'une couleur) et se confond
avec les icônes bleues voisines. B survit sous forme de glyphe : c'est la couche
<monochrome> des icônes thématiques et l'icône de barre d'état.

Premier essai de A avec un bord `#e0f2fe` (sky-100) : la partie visible de la
tuile restait blanche à plus de 90 % et se fondait dans un fond d'écran clair.
D'où le bord `#bfdbfe` (blue-200) et un dégradé normalisé sur les 72dp visibles
plutôt que sur les coins du canevas.

Trois points qui ont coûté du temps et qu'il ne faut pas défaire
----------------------------------------------------------------
1. **Zone sûre : 57 %, pas plus.** La zone sûre d'une icône adaptative est un
   disque de 66dp sur un canevas de 108dp (le lanceur affiche 72dp et peut
   décaler la couche avant en parallaxe). L'écusson est large de toque : sa
   pointe gauche est à 0,53 fois son grand côté du centre. À 62 % du canevas
   elle serait à 36,7dp du centre — HORS du disque visible de 72dp, coupée par
   tout masque rond ; à 60 % (valeur précédente), à 35,5dp, hors zone sûre. Le
   script centre l'écusson sur son cercle englobant minimal (et non sur sa boîte)
   et le pose à 57 %, ce qui met la pointe à 32,7dp : dedans. `--apercu`
   imprime la mesure ; si la source change, la relire avant de toucher au chiffre.

2. **L'alpha est rongé d'un pixel avant composition.** Le fond blanc d'origine
   a laissé sur le contour des pixels semi-transparents blanchâtres ; sur un fond
   sombre ils dessinaient un liseré clair. La tuile claire les rend invisibles,
   mais le rongement est gardé : il ne coûte rien et l'écusson reposé un jour
   sur du sombre ne ressortira pas cerné.

3. **Le redimensionnement se fait en alpha prémultiplié (`RGBa`).** Réduit en
   `RGBA` tel quel, Pillow mélange la couleur des pixels transparents (noirs) au
   bord de l'écusson : un contour gris sale à 48 px. En `RGBa`, le bord reste de
   la couleur de l'écusson.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RACINE = Path(__file__).resolve().parent.parent
BRAND = RACINE / "assets" / "brand"

MARQUE = BRAND / "uniflow_marque.png"
LOGO_LONG = BRAND / "uniflow_logo_horizontal.png"

# Palette relevée dans uniflow-we (Tailwind) : c'est la marque, pas un choix local.
BLEU_MARQUE_HEX = "#1e3a8a"
BLEU_MARQUE = (30, 58, 138)
BLEU_VIF = (29, 78, 216)  # #1d4ed8
TURQUOISE = (13, 148, 136)  # #0d9488
BLANC = (255, 255, 255)
# Bord du dégradé de la tuile claire. `#e0f2fe` (sky-100) a été essayé : trop
# proche du blanc, la tuile n'avait pas de bord sur un fond d'écran clair.
BLEU_PALE = (191, 219, 254)  # #bfdbfe, blue-200
LISERE = (147, 197, 253)  # #93c5fd, liseré des icônes héritées sur fond clair

VARIANTE_RETENUE = "A"

# Couche avant : le grand côté de l'écusson en fraction du canevas de 108dp.
# 0,57 met la pointe la plus éloignée à 32,7dp du centre, dans la zone sûre de
# 33dp (voir le point 1 du bandeau).
PART_ADAPTATIF = 0.57
# Couche <monochrome> : le lanceur la rogne davantage que la couche avant et
# les icônes thématiques de Google occupent ~45 % ; à 57 % le glyphe débordait
# de la pastille dans l'aperçu.
PART_MONOCHROME = 0.46
# Icône de barre d'état : 24dp dont ~2dp de marge, comme les icônes système.
PART_NOTIFICATION = 0.82
# Icône web « maskable » : le navigateur peut la rogner en cercle.
PART_MASKABLE = 0.58
# Icône web / boutique pleine (Icon-192, Icon-512, favicon) : rien ne la rogne.
PART_ICONE = 0.74

# Le lanceur montre 72dp des 108dp de l'icône adaptative.
VISIBLE_ADAPTATIF = 72 / 108
# Zone sûre : 66dp de diamètre.
RAYON_ZONE_SURE_DP = 33.0

DENSITES_ANDROID = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

# Diamètre du disque de l'écran de lancement Android < 12 : c'est celui que
# l'écran de lancement système d'Android 12+ donne à une icône adaptative sans
# fond propre (288dp de canevas, 192dp visibles).
DIAMETRE_SPLASH_DP = 192

TAILLES_MACOS = [16, 32, 64, 128, 256, 512, 1024]
TAILLES_ICO = [16, 32, 48, 64, 128, 256]

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Icône adaptative : le lanceur redimensionne et masque (cercle, goutte,
     carré arrondi...) la superposition de trois couches PNG de 108dp :
       - fond      : tuile claire, dégradé radial blanc -> bleu très pâle ;
       - avant     : l'écusson en couleurs pleines, à 57 %, dans la zone sûre
                     de 66dp (au-delà, la pointe de la toque est rognée) ;
       - monochrome: la silhouette blanche, teintée par le système pour les
                     icônes thématiques d'Android 13+.
     L'aplat bleu marine précédent avalait la toque, de la même couleur ;
     voir tools/generer-icones-uniflow.py, qui régénère tout ceci. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""


# --------------------------------------------------------------------------
# Source
# --------------------------------------------------------------------------


def ecusson_propre() -> Image.Image:
    """Écusson recadré sur ses pixels opaques, contour déblanchi."""
    if not MARQUE.exists():
        sys.exit(f"Source absente : {MARQUE}")
    im = Image.open(MARQUE).convert("RGBA")
    boite = im.getchannel("A").getbbox()
    if boite is None:
        sys.exit(f"{MARQUE} est entierement transparent.")
    im = im.crop(boite)
    # Ronge l'alpha d'un pixel (point 2 du bandeau), puis adoucit le bord
    # rongé de 0,6 px : c'est l'anticrénelage du nouveau contour, pas un flou
    # de l'image.
    alpha = im.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    im.putalpha(alpha)
    return im


def centre_cercle_englobant(im: Image.Image) -> tuple[float, float, float]:
    """Centre (x, y) et rayon en pixels du plus petit cercle contenant l'écusson.

    La boîte englobante est trompeuse : la toque déborde à gauche, l'écusson
    n'est pas symétrique. Centrer sur le cercle englobant plutôt que sur la
    boîte gagne 3 % de taille à zone sûre égale. Recherche sur une grille de
    2 px autour du centre de la boîte, sur les seuls pixels de bord.
    """
    alpha = im.getchannel("A")
    plein = np.asarray(alpha) > 40
    ronge = np.asarray(alpha.filter(ImageFilter.MinFilter(3))) > 40
    ys, xs = np.nonzero(plein & ~ronge)
    cx0, cy0 = (im.width - 1) / 2, (im.height - 1) / 2
    meilleur = (float("inf"), cx0, cy0)
    for dx in range(-40, 41, 2):
        for dy in range(-40, 41, 2):
            cx, cy = cx0 + dx, cy0 + dy
            r = float(np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max())
            if r < meilleur[0]:
                meilleur = (r, cx, cy)
    r, cx, cy = meilleur
    return cx, cy, r


class Ecusson:
    """La source et sa géométrie, calculées une fois."""

    def __init__(self) -> None:
        self.image = ecusson_propre()
        self.cx, self.cy, self.rayon = centre_cercle_englobant(self.image)
        self.grand_cote = max(self.image.size)
        # Distance de la pointe la plus éloignée, relative au grand côté.
        self.rayon_normalise = self.rayon / self.grand_cote

    def rayon_dp(self, part: float, canevas_dp: float = 108) -> float:
        """Distance en dp de la pointe la plus éloignée quand l'écusson est posé à `part`."""
        return self.rayon_normalise * part * canevas_dp

    def part_zone_sure(self) -> float:
        """Plus grande fraction du canevas qui garde toute la pointe dans la zone sûre."""
        return RAYON_ZONE_SURE_DP / (108 * self.rayon_normalise)


# --------------------------------------------------------------------------
# Primitives d'image
# --------------------------------------------------------------------------


def reduit(src: Image.Image, largeur: int, hauteur: int) -> Image.Image:
    """Redimensionne en alpha prémultiplié, puis rend la netteté perdue.

    Le masque flou inversé (unsharp) est doux : radius 1, 60 %. Assez pour que
    les traces de circuit restent des traits à 72 px, pas assez pour créer un
    halo. Il s'applique sur l'image prémultipliée, donc aussi à l'alpha, ce qui
    tient le contour net.
    """
    im = src.convert("RGBa").resize((max(1, largeur), max(1, hauteur)), Image.LANCZOS)
    if max(largeur, hauteur) < src.width:
        im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    return im.convert("RGBA")


def reduit_glyphe(src: Image.Image, largeur: int, hauteur: int) -> Image.Image:
    """Silhouette blanche de `src` réduite : seul l'alpha est redimensionné.

    Réduire une image blanche en `RGBa` puis la dé-prémultiplier laissait des
    pixels de bord à 250 ou 103 au lieu de 255 ; or Android teinte une icône de
    barre d'état par son alpha et attend du blanc pur. Ici la couleur est posée
    après le redimensionnement : elle est blanche par construction.
    """
    alpha = src.getchannel("A").resize((max(1, largeur), max(1, hauteur)), Image.LANCZOS)
    if max(largeur, hauteur) < src.width:
        alpha = alpha.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    toile = Image.new("RGBA", alpha.size, BLANC + (255,))
    toile.putalpha(alpha)
    return toile


def pose(ecusson: Ecusson, taille: int, part: float, glyphe: bool = False) -> Image.Image:
    """Pose l'écusson dans une toile carrée transparente, centré sur son cercle englobant.

    `glyphe` : la silhouette blanche plutôt que l'écusson en couleurs.
    """
    src = ecusson.image
    cible = taille * part
    echelle = cible / ecusson.grand_cote
    nw, nh = round(src.width * echelle), round(src.height * echelle)
    petit = reduit_glyphe(src, nw, nh) if glyphe else reduit(src, nw, nh)
    toile = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    # Le centre du cercle englobant tombe au centre de la toile.
    x = round(taille / 2 - ecusson.cx * echelle)
    y = round(taille / 2 - ecusson.cy * echelle)
    toile.alpha_composite(petit, (x, y))
    return toile


def _forme(taille: int, forme: str, epaisseur: int = 0) -> Image.Image:
    """Forme 8 bits anticrénelée, dessinée à 4x puis réduite.

    `epaisseur` = 0 : la forme pleine (masque) ; > 0 : son seul contour, de
    cette épaisseur en pixels finaux. Le contour est dessiné, pas obtenu par
    érosion du masque : l'érosion carrée donnait un anneau d'épaisseur inégale
    dans les coins arrondis, qui ressemblait à un pointillé à 48 px.
    """
    k = 4
    grand = Image.new("L", (taille * k, taille * k), 0)
    d = ImageDraw.Draw(grand)
    boite = (0, 0, taille * k - 1, taille * k - 1)
    remplissage = dict(fill=255) if epaisseur == 0 else dict(outline=255, width=epaisseur * k)
    if forme == "cercle":
        d.ellipse(boite, **remplissage)
    elif forme == "carre_arrondi":
        # Rayon de 20 %, celui des carrés arrondis de Pixel Launcher.
        d.rounded_rectangle(boite, radius=round(taille * k * 0.2), **remplissage)
    elif forme == "carre":
        d.rectangle(boite, **remplissage)
    else:
        raise ValueError(forme)
    return grand.resize((taille, taille), Image.LANCZOS)


def masque(taille: int, forme: str) -> Image.Image:
    return _forme(taille, forme)


def degrade_radial(taille: int, centre: tuple, bord: tuple) -> Image.Image:
    """Dégradé radial : `centre` au milieu, `bord` atteint au bord du disque visible.

    Normalisé sur les 72dp que le lanceur affiche, pas sur les coins du canevas
    de 108dp : normalisé sur les coins, la partie visible restait blanche à
    plus de 90 % et la tuile se fondait dans un fond d'écran clair.
    """
    ys, xs = np.mgrid[0:taille, 0:taille].astype(np.float32)
    c = (taille - 1) / 2
    d = np.sqrt((xs - c) ** 2 + (ys - c) ** 2) / (c * VISIBLE_ADAPTATIF)
    t = np.clip(d, 0, 1)[..., None]
    rgb = np.array(centre, np.float32) * (1 - t) + np.array(bord, np.float32) * t
    out = np.concatenate([rgb, np.full((taille, taille, 1), 255, np.float32)], axis=2)
    return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def degrade_diagonal(taille: int, haut_gauche: tuple, bas_droite: tuple) -> Image.Image:
    ys, xs = np.mgrid[0:taille, 0:taille].astype(np.float32)
    t = ((xs + ys) / (2 * (taille - 1)))[..., None]
    rgb = np.array(haut_gauche, np.float32) * (1 - t) + np.array(bas_droite, np.float32) * t
    out = np.concatenate([rgb, np.full((taille, taille, 1), 255, np.float32)], axis=2)
    return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def applique_masque(im: Image.Image, forme: str) -> Image.Image:
    out = im.copy()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), masque(im.width, forme)))
    return out


def lisere(im: Image.Image, forme: str, couleur: tuple, epaisseur: int, opacite: int = 210) -> Image.Image:
    """Cerne une icône héritée : la tuile claire, seule sur un fond blanc, n'aurait pas de bord."""
    anneau = _forme(im.width, forme, epaisseur).point(lambda v: v * opacite // 255)
    trait = Image.new("RGBA", im.size, couleur + (255,))
    trait.putalpha(anneau)
    out = im.copy()
    out.alpha_composite(trait)
    return out


# --------------------------------------------------------------------------
# Les deux candidats : chacun est un fond et une couche avant sur 108dp
# --------------------------------------------------------------------------


class Variante:
    def __init__(self, nom: str, ecusson: Ecusson) -> None:
        self.nom = nom
        self.ecusson = ecusson

    def fond(self, taille: int) -> Image.Image:
        if self.nom == "A":
            return degrade_radial(taille, BLANC, BLEU_PALE)
        return degrade_diagonal(taille, BLEU_VIF, TURQUOISE)

    def avant(self, taille: int, part: float = PART_ADAPTATIF) -> Image.Image:
        return pose(self.ecusson, taille, part, glyphe=self.nom == "B")

    def monochrome(self, taille: int) -> Image.Image:
        return pose(self.ecusson, taille, PART_MONOCHROME, glyphe=True)

    def rendu_lanceur(self, diametre: int, forme: str, cerne: bool = False) -> Image.Image:
        """Ce que le lanceur affiche : 72dp des 108dp, composés puis masqués.

        Sert aux planches d'aperçu, aux icônes héritées (ic_launcher,
        ic_launcher_round) et au disque de l'écran de lancement : ainsi tous
        montrent exactement l'icône adaptative telle qu'Android la rend.
        """
        canevas = round(diametre / VISIBLE_ADAPTATIF)
        compose = self.fond(canevas)
        compose.alpha_composite(self.avant(canevas))
        marge = (canevas - diametre) // 2
        coupe = compose.crop((marge, marge, marge + diametre, marge + diametre))
        coupe = applique_masque(coupe, forme)
        if cerne:
            coupe = lisere(coupe, forme, LISERE, max(1, round(diametre / 48)))
        return coupe

    def plein(self, taille: int, part: float) -> Image.Image:
        """Icône carrée pleine (web, boutique) : la tuile et l'écusson, sans masque."""
        im = self.fond(taille)
        im.alpha_composite(self.avant(taille, part))
        return im


# --------------------------------------------------------------------------
# Planches d'aperçu
# --------------------------------------------------------------------------

FOND_LANCEUR_CLAIR = (241, 245, 249)
FOND_LANCEUR_SOMBRE = (17, 24, 39)


def _police(taille: int) -> ImageFont.ImageFont:
    # La police par défaut de Pillow n'a pas d'accents ; DejaVu est sur toute
    # machine Linux de développement.
    for nom in ("DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(nom, taille)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=taille)
    except TypeError:  # Pillow < 10
        return ImageFont.load_default()


def _sur_fond(icone: Image.Image, fond: tuple, marge: int) -> Image.Image:
    toile = Image.new("RGBA", (icone.width + 2 * marge, icone.height + 2 * marge), fond + (255,))
    toile.alpha_composite(icone, (marge, marge))
    return toile


def icone_thematique(variante: Variante, diametre: int, sombre: bool) -> Image.Image:
    """Simulation d'une icône thématique Android 13+ : pastille + glyphe teinté."""
    canevas = round(diametre / VISIBLE_ADAPTATIF)
    pastille = Image.new("RGBA", (canevas, canevas), ((30, 41, 59) if sombre else (219, 228, 253)) + (255,))
    glyphe = variante.monochrome(canevas)
    teinte = Image.new("RGBA", glyphe.size, ((199, 210, 254) if sombre else (30, 58, 138)) + (255,))
    teinte.putalpha(glyphe.getchannel("A"))
    pastille.alpha_composite(teinte)
    marge = (canevas - diametre) // 2
    return applique_masque(pastille.crop((marge, marge, marge + diametre, marge + diametre)), "cercle")


def planche_variante(variante: Variante, echelle: int = 2) -> Image.Image:
    """Une variante : 48/72/108 px, cercle et carré arrondi, lanceur clair et sombre.

    Les icônes sont rendues à leur taille réelle puis agrandies au plus proche
    voisin (`echelle`) : l'œil juge la lisibilité à 48 px, pas une version
    redessinée plus grande.
    """
    tailles = (48, 72, 108)
    formes = ("cercle", "carre_arrondi")
    marge = 14
    lignes = []
    for fond in (FOND_LANCEUR_CLAIR, FOND_LANCEUR_SOMBRE):
        cases = []
        for t in tailles:
            for f in formes:
                ic = variante.rendu_lanceur(t, f)
                cases.append(_sur_fond(ic, fond, marge))
        # Icône thématique et icône héritée, pour compléter la ligne.
        cases.append(_sur_fond(icone_thematique(variante, 72, fond == FOND_LANCEUR_SOMBRE), fond, marge))
        cases.append(_sur_fond(variante.rendu_lanceur(48, "carre_arrondi", cerne=True), fond, marge))
        hauteur = max(c.height for c in cases)
        largeur = sum(c.width for c in cases)
        ligne = Image.new("RGBA", (largeur, hauteur), fond + (255,))
        x = 0
        for c in cases:
            ligne.alpha_composite(c, (x, (hauteur - c.height) // 2))
            x += c.width
        lignes.append(ligne)
    largeur = max(l.width for l in lignes)
    haut_titre = 34
    planche = Image.new("RGBA", (largeur, haut_titre + sum(l.height for l in lignes)), BLANC + (255,))
    d = ImageDraw.Draw(planche)
    d.text(
        (10, 8),
        f"Variante {variante.nom} — 48 / 72 / 108 px, cercle et carré arrondi ; puis icône thématique 72 et héritée 48",
        fill=(30, 41, 59),
        font=_police(15),
    )
    y = haut_titre
    for l in lignes:
        planche.alpha_composite(l, (0, y))
        y += l.height
    if echelle > 1:
        planche = planche.resize((planche.width * echelle, planche.height * echelle), Image.NEAREST)
    return planche


def planche_finale(variante: Variante) -> Image.Image:
    """La planche versionnée dans docs/design : l'icône retenue et ses déclinaisons."""
    marge = 16
    blocs = []
    for fond in (FOND_LANCEUR_CLAIR, FOND_LANCEUR_SOMBRE):
        cases = [_sur_fond(variante.rendu_lanceur(t, f), fond, marge) for t in (48, 72, 108) for f in ("cercle", "carre_arrondi")]
        cases.append(_sur_fond(icone_thematique(variante, 72, fond == FOND_LANCEUR_SOMBRE), fond, marge))
        hauteur = max(c.height for c in cases)
        ligne = Image.new("RGBA", (sum(c.width for c in cases), hauteur), fond + (255,))
        x = 0
        for c in cases:
            ligne.alpha_composite(c, (x, (hauteur - c.height) // 2))
            x += c.width
        blocs.append(ligne)
    # Barre d'état : le glyphe 24dp blanc, tel qu'Android le teinte.
    barre = Image.new("RGBA", (blocs[0].width, 40), (31, 41, 55, 255))
    barre.alpha_composite(pose(variante.ecusson, 24, PART_NOTIFICATION, glyphe=True), (12, 8))
    ImageDraw.Draw(barre).text((44, 12), "UniFlow · Message urgent", fill=(229, 231, 235), font=_police(14))
    blocs.append(barre)
    planche = Image.new("RGBA", (blocs[0].width, sum(b.height for b in blocs)), BLANC + (255,))
    y = 0
    for b in blocs:
        planche.alpha_composite(b, (0, y))
        y += b.height
    return planche.resize((planche.width * 2, planche.height * 2), Image.NEAREST)


# --------------------------------------------------------------------------
# Écriture par plateforme
# --------------------------------------------------------------------------


def ecrit_android(variante: Variante) -> list[str]:
    res = RACINE / "android" / "app" / "src" / "main" / "res"
    if not res.is_dir():
        return []
    ecrits: list[str] = []
    for densite, facteur in DENSITES_ANDROID.items():
        mipmap = res / f"mipmap-{densite}"
        mipmap.mkdir(parents=True, exist_ok=True)
        cote = round(48 * facteur)
        canevas = round(108 * facteur)

        # Icônes héritées : Android < 8 et lanceurs qui ignorent l'adaptatif.
        # Ce sont les rendus du lanceur, cernés d'un liseré : la tuile claire
        # posée seule sur un fond blanc n'aurait pas de bord.
        variante.rendu_lanceur(cote, "carre_arrondi", cerne=True).save(mipmap / "ic_launcher.png")
        variante.rendu_lanceur(cote, "cercle", cerne=True).save(mipmap / "ic_launcher_round.png")
        ecrits += [f"mipmap-{densite}/ic_launcher.png", f"mipmap-{densite}/ic_launcher_round.png"]

        variante.fond(canevas).save(mipmap / "ic_launcher_background.png")
        variante.avant(canevas).save(mipmap / "ic_launcher_foreground.png")
        variante.monochrome(canevas).save(mipmap / "ic_launcher_monochrome.png")
        ecrits += [
            f"mipmap-{densite}/ic_launcher_background.png",
            f"mipmap-{densite}/ic_launcher_foreground.png",
            f"mipmap-{densite}/ic_launcher_monochrome.png",
        ]

        drawable = res / f"drawable-{densite}"
        drawable.mkdir(parents=True, exist_ok=True)
        # Barre d'état : Android ne garde que l'alpha et teinte en blanc ou en
        # gris ; une icône en couleurs y devient un carré gris.
        pose(variante.ecusson, round(24 * facteur), PART_NOTIFICATION, glyphe=True).save(drawable / "ic_stat_uniflow.png")
        ecrits.append(f"drawable-{densite}/ic_stat_uniflow.png")
        # Écran de lancement Android < 12 : le même disque que celui que le
        # système dessine sur Android 12+, pour que les deux se ressemblent.
        variante.rendu_lanceur(round(DIAMETRE_SPLASH_DP * facteur), "cercle").save(drawable / "splash_ecusson.png")
        ecrits.append(f"drawable-{densite}/splash_ecusson.png")

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for nom in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / nom).write_text(ADAPTIVE_XML, encoding="utf-8")
        ecrits.append(f"mipmap-anydpi-v26/{nom}")

    # L'ancien fond uni n'est plus référencé : le laisser ferait croire qu'il
    # sert encore.
    ancien = res / "values" / "ic_launcher_background.xml"
    if ancien.exists():
        ancien.unlink()
        ecrits.append("values/ic_launcher_background.xml (supprime)")
    return ecrits


def ecrit_macos(variante: Variante) -> list[str]:
    dossier = RACINE / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if not dossier.is_dir():
        return []
    ecrits = []
    for taille in TAILLES_MACOS:
        # macOS ne masque pas : l'icône porte elle-même son carré arrondi.
        variante.rendu_lanceur(taille, "carre_arrondi", cerne=True).save(dossier / f"app_icon_{taille}.png")
        ecrits.append(f"AppIcon.appiconset/app_icon_{taille}.png")
    return ecrits


def ecrit_windows(variante: Variante) -> list[str]:
    dossier = RACINE / "windows" / "runner" / "resources"
    if not dossier.is_dir():
        return []
    images = [variante.rendu_lanceur(t, "carre_arrondi", cerne=True) for t in TAILLES_ICO]
    images[-1].save(dossier / "app_icon.ico", format="ICO", sizes=[(t, t) for t in TAILLES_ICO])
    return ["runner/resources/app_icon.ico"]


def ecrit_web(variante: Variante) -> list[str]:
    dossier = RACINE / "web"
    if not dossier.is_dir():
        return []
    ecrits = []
    variante.rendu_lanceur(32, "carre_arrondi", cerne=True).save(dossier / "favicon.png")
    ecrits.append("web/favicon.png")
    icones = dossier / "icons"
    icones.mkdir(exist_ok=True)
    for taille in (192, 512):
        variante.plein(taille, PART_ICONE).convert("RGB").save(icones / f"Icon-{taille}.png")
        ecrits.append(f"web/icons/Icon-{taille}.png")
        variante.plein(taille, PART_MASKABLE).convert("RGB").save(icones / f"Icon-maskable-{taille}.png")
        ecrits.append(f"web/icons/Icon-maskable-{taille}.png")
    return ecrits


def ecrit_planche(variante: Variante) -> list[str]:
    dossier = RACINE / "docs" / "design"
    dossier.mkdir(parents=True, exist_ok=True)
    planche_finale(variante).save(dossier / "icone-android.png", optimize=True)
    return ["docs/design/icone-android.png"]


# --------------------------------------------------------------------------


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--variante", choices=("A", "B"), default=VARIANTE_RETENUE)
    p.add_argument("--apercu", metavar="DIR", help="rend les planches comparatives A et B dans DIR, n'écrit rien dans le dépôt")
    p.add_argument("--icone-512", metavar="FICHIER", help="exporte aussi l'icône boutique 512 px (carré plein, sans transparence)")
    args = p.parse_args()

    ecusson = Ecusson()
    print(f"ecusson    : {ecusson.image.width}x{ecusson.image.height} apres recadrage")
    print(
        f"geometrie  : pointe la plus eloignee a {ecusson.rayon_normalise:.3f} x grand cote ; "
        f"a {PART_ADAPTATIF:.0%} du canevas -> {ecusson.rayon_dp(PART_ADAPTATIF):.1f}dp du centre "
        f"(zone sure {RAYON_ZONE_SURE_DP:.0f}dp, part maximale {ecusson.part_zone_sure():.3f})"
    )
    if ecusson.rayon_dp(PART_ADAPTATIF) > RAYON_ZONE_SURE_DP:
        sys.exit("PART_ADAPTATIF fait sortir l'ecusson de la zone sure : le lanceur rognera la toque.")
    if not LOGO_LONG.exists():
        print(f"note       : {LOGO_LONG.name} absent, ignore")

    if args.apercu:
        dossier = Path(args.apercu)
        dossier.mkdir(parents=True, exist_ok=True)
        for nom in ("A", "B"):
            v = Variante(nom, ecusson)
            planche_variante(v).save(dossier / f"variante-{nom}.png")
            print(f"apercu     : {dossier / f'variante-{nom}.png'}")
        planche_finale(Variante(args.variante, ecusson)).save(dossier / f"planche-finale-{args.variante}.png")
        print(f"apercu     : {dossier / f'planche-finale-{args.variante}.png'}")
        return

    variante = Variante(args.variante, ecusson)
    total: list[str] = []
    for nom, fonction in (
        ("android", ecrit_android),
        ("macos", ecrit_macos),
        ("windows", ecrit_windows),
        ("web", ecrit_web),
        ("planche", ecrit_planche),
    ):
        ecrits = fonction(variante)
        if ecrits:
            print(f"{nom:9}: {len(ecrits)} fichier(s)")
            total += ecrits
        else:
            print(f"{nom:9}: plateforme absente, ignoree")

    if args.icone_512:
        cible = Path(args.icone_512)
        cible.parent.mkdir(parents=True, exist_ok=True)
        # Boutique (Play) : 512 px, carré plein, sans transparence ; c'est la
        # boutique qui arrondit les coins.
        variante.plein(512, PART_ICONE).convert("RGB").save(cible, optimize=True)
        print(f"icone 512  : {cible}")
        total.append(str(cible))

    if not total:
        sys.exit("Aucune plateforme trouvee : lancer depuis la racine du depot.")
    print(f"\n{len(total)} fichier(s) ecrit(s), variante {variante.nom}.")


if __name__ == "__main__":
    main()
