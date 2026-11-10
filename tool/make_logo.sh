#!/usr/bin/env bash
# Regenerates the Arise logo PNGs and Android icon resources with ImageMagick.
# Usage: tool/make_logo.sh   (run from the repo root)
set -euo pipefail
RES=android/app/src/main/res
OUT=assets/brand
BG='#05070D'
S=1024

# Mark drawn on a 100-unit grid: a diamond frame with a double chevron.
mark() { # $1=size  $2=colour  -> writes mark svg path list as magick draw args
  local k; k=$(awk "BEGIN{print $1/100}")
  echo "-fill $2 -stroke none -draw \"polygon $(awk -v k=$k 'BEGIN{printf "%f,%f %f,%f %f,%f %f,%f",50*k,5*k,95*k,50*k,50*k,95*k,5*k,50*k}')\""
}

draw_logo() { # $1 size $2 frame colour $3 chevron colour $4 hole colour, to stdout png
  local sz=$1 k; k=$(awk "BEGIN{print $sz/100}")
  magick -size ${sz}x${sz} xc:none \
    -fill "$2" -draw "polygon $(awk -v k=$k 'BEGIN{printf "%f,%f %f,%f %f,%f %f,%f",50*k,5*k,95*k,50*k,50*k,95*k,5*k,50*k}')" \
    -fill "$4" -draw "polygon $(awk -v k=$k 'BEGIN{printf "%f,%f %f,%f %f,%f %f,%f",50*k,12*k,88*k,50*k,50*k,88*k,12*k,50*k}')" \
    -fill "$3" -draw "polygon $(awk -v k=$k 'BEGIN{printf "%f,%f %f,%f %f,%f %f,%f %f,%f %f,%f",50*k,24*k,70*k,46*k,61*k,46*k,50*k,34*k,39*k,46*k,30*k,46*k}')" \
    -fill "$3" -draw "polygon $(awk -v k=$k 'BEGIN{printf "%f,%f %f,%f %f,%f %f,%f %f,%f %f,%f",50*k,46*k,70*k,68*k,61*k,68*k,50*k,56*k,39*k,68*k,30*k,68*k}')" \
    png:-
}

# Master: dark tile, soft glow behind the mark.
draw_logo $S '#3DA9FF' '#9ADBFF' "$BG" > /tmp/arise_mark.png
magick /tmp/arise_mark.png \( +clone -channel A -blur 0x28 -level 0,70% +channel -fill '#3DA9FF' -colorize 100 \) \
  +swap -background none -compose over -composite /tmp/arise_glow.png
magick -size ${S}x${S} xc:"$BG" /tmp/arise_glow.png -gravity center -compose over -composite "$OUT/logo_tile.png"
# Splash logo: the mark with glow on transparent, 512px.
magick /tmp/arise_glow.png -resize 512x512 "$OUT/logo.png"

# Adaptive icon foreground: art inside the 66/108 safe zone, per density.
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  name=${d%%:*}; px=${d##*:}
  art=$(( px * 58 / 100 ))
  mkdir -p "$RES/mipmap-$name"
  magick -size ${px}x${px} xc:none \( /tmp/arise_glow.png -resize ${art}x${art} \) -gravity center -composite \
    "$RES/mipmap-$name/ic_launcher_foreground.png"
  # Legacy / round fallbacks.
  magick "$OUT/logo_tile.png" -resize $(( px * 48 / 108 ))x$(( px * 48 / 108 )) "$RES/mipmap-$name/ic_launcher.png"
done
# Monochrome (themed icons) wants a flat alpha shape.
magick /tmp/arise_mark.png -fill white -colorize 100 -channel A -separate +channel \
  -alpha shape /tmp/arise_mono_a.png 2>/dev/null || true
magick -size 432x432 xc:none \( /tmp/arise_mark.png -resize 250x250 -fill white -colorize 100 \) -gravity center -composite \
  "$RES/drawable-nodpi/ic_launcher_monochrome.png" 2>/dev/null || { mkdir -p "$RES/drawable-nodpi"; magick -size 432x432 xc:none \( /tmp/arise_mark.png -resize 250x250 -fill white -colorize 100 \) -gravity center -composite "$RES/drawable-nodpi/ic_launcher_monochrome.png"; }
# Android 12+ system splash icon (drawn inside a circle mask ~ 2/3 of 288dp).
mkdir -p "$RES/drawable-nodpi"
magick -size 960x960 xc:none \( /tmp/arise_glow.png -resize 560x560 \) -gravity center -composite "$RES/drawable-nodpi/splash_icon.png"
echo done
