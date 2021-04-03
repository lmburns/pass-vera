#!/usr/bin/env bash

# Sync pass-vera with the homebrew tap

GREEN=$(tput setaf 2) MAGENTA=$(tput setaf 5) RESET=$(tput sgr0)

cd $(dirname $0)
printf "%b\n" "${MAGENTA}$(pwd)${RESET}"

tag="$(git describe)"
outfile="taps/pass-vera-${tag}.tar.gz"

# Download latest release
curl -sL "https://github.com/lmburns/pass-vera/archive/refs/tags/${tag}.tar.gz" --output "$outfile" &&
  tar -xf "$outfile" -C "${outfile%/*}"

checksum="$(sha256sum "$outfile" | cut -d' ' -f1)"
printf " . %b%s\n" "${GREENt}tag" "= $tag"
printf " . %b%s\n" "${GREEN}checksum" "= $checksum"

# Clone repo
clone_out="${outfile%/*}/homebrew-pass-vera"
[[ -e "$clone_out" ]] && rm -rf "$clone_out"
git clone https://github.com/lmburns/homebrew-pass-vera.git "$clone_out"
cd "$clone_out"

printf "%b\n" "${MAGENTA}$(pwd)${RESET}"

# Compile template
IFS=''
while read line; do
  REPLACE1=${line//TAG/$tag}
  REPLACE2=${REPLACE1//CHECKSUM/$checksum}
  echo $REPLACE2
done < ../../tap_template > Formula/pass-vera.rb

# Push to tap
git add Formula/pass-vera.rb
git commit -S -m "$tag"
git push --set-upstream origin master
