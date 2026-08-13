#!/usr/bin/env bash
# Runs the review probes and every screen shot, and packs the lot into one
# archive.
#
#     bash tools/collect_review_bundle.sh
#
# Everything here is container work rather than model work: it takes an hour and
# costs nothing, which is the whole reason these three were chosen to run
# unattended. Sequential on purpose -- running a probe beside the test suite once
# starved it of CPU and it was killed at its timeout, which looked exactly like a
# hang.
set -u

GODOT="${GODOT:-/tmp/Godot_v4.7.1-stable_linux.x86_64}"
OUT="$(pwd)/review_bundle"
SHOTS="$OUT/screens"
USERDIR="$HOME/.local/share/godot/app_userdata"

rm -rf "$OUT"
mkdir -p "$SHOTS"

run_probe() {
	local scene="$1" name="$2"
	echo "=== $name"
	timeout 3000 xvfb-run -a "$GODOT" --path . "res://tools/$scene" \
		> "$OUT/$name.txt" 2>&1
	# Strip the driver noise so the file opens on the numbers.
	grep -vE "ALSA|libpulse|WARNING:|^ERROR:|^   at:|Godot Engine|OpenGL API|^$" \
		"$OUT/$name.txt" > "$OUT/$name.clean.txt" 2>/dev/null
	mv "$OUT/$name.clean.txt" "$OUT/$name.txt" 2>/dev/null
	echo "    -> $name.txt"
}

run_probe determinism_probe.tscn determinism
run_probe long_world_probe.tscn long_world

echo "=== screen renders"
for scene in tools/*_shot.tscn tools/*_plate.tscn tools/*_preview.tscn; do
	[ -e "$scene" ] || continue
	name="$(basename "$scene" .tscn)"
	echo "    $name"
	timeout 900 xvfb-run -a "$GODOT" --path . "res://$scene" \
		> "$OUT/render_log_$name.txt" 2>&1
done
# Shots write to user://, which is one directory regardless of which tool ran.
find "$USERDIR" -name "*.png" -exec cp {} "$SHOTS/" \; 2>/dev/null
echo "    -> $(ls "$SHOTS" | wc -l) images"

cp docs/review/clamp_inventory.txt "$OUT/" 2>/dev/null
cp docs/review/comment_audit.docx "$OUT/" 2>/dev/null
cp docs/review/prose_audit_findings.json "$OUT/" 2>/dev/null
rm -f "$OUT"/render_log_*.txt

cd "$(dirname "$OUT")" && zip -qr review_bundle.zip "$(basename "$OUT")"
echo ""
echo "packed: $(pwd)/review_bundle.zip"
du -h review_bundle.zip
