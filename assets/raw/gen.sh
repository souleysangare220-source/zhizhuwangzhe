#!/bin/bash
# v3：cd 进目录后全程相对路径（v2 中文路径传给原生 curl.exe 编码损坏，文件写不出）
KEY="${GPT_IMAGE_KEY:?请先 export GPT_IMAGE_KEY}"
URL="${GPT_IMAGE_URL:?请先 export GPT_IMAGE_URL}"
cd "$(dirname "$0")" || exit 1

declare -A PROMPTS
PROMPTS[template]="Ornate playing card face template for a dark fantasy pixel art card game, vertical portrait orientation, completely EMPTY face with NO text NO numbers NO suit symbols, elegant dark indigo-violet ornate border frame with silver filigree corner decorations, inner area is a subtle darker empty panel, flat even lighting, 16-bit SNES era pixel art style, clean chunky pixels, game asset, no text, no watermark|1024x1536"
PROMPTS[spider]="Pixel art bust portrait of a spider queen noble for a playing card court character, elegant woman with spider traits and small crown, deep purple and violet palette with silver accents, dark simple background, front facing bust composition filling most of frame, 16-bit SNES era pixel art style, clean chunky pixels, game asset, no text, no watermark|1024x1024"
PROMPTS[moth]="Pixel art bust portrait of a moth-winged noblewoman for a playing card court character, elegant woman with large crimson moth wings and antenna, red and crimson palette with gold accents, dark simple background, front facing bust composition filling most of frame, 16-bit SNES era pixel art style, clean chunky pixels, game asset, no text, no watermark|1024x1024"
PROMPTS[beetle]="Pixel art bust portrait of a beetle knight for a playing card court character, armored warrior with iridescent blue beetle shell armor and horned helm, blue and steel palette, dark simple background, front facing bust composition filling most of frame, 16-bit SNES era pixel art style, clean chunky pixels, game asset, no text, no watermark|1024x1024"
PROMPTS[centipede]="Pixel art bust portrait of a centipede charmer for a playing card court character, mysterious figure with green centipede segments wrapping shoulders and hood, green and emerald palette, dark simple background, front facing bust composition filling most of frame, 16-bit SNES era pixel art style, clean chunky pixels, game asset, no text, no watermark|1024x1024"

PY="${PYTHON:-python}"

for name in template spider moth beetle centipede; do
  [ -s "$name.png" ] && echo "SKIP $name (已存在)" && continue
  IFS='|' read -r prompt size <<< "${PROMPTS[$name]}"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    echo "[$(date +%H:%M:%S)] $name 尝试 $attempt..."
    curl -s --max-time 180 "$URL" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"model\":\"gpt-image-2\",\"prompt\":\"$prompt\",\"size\":\"$size\",\"n\":1}" -o "$name.json"
    ls -la "$name.json"
    "$PY" - "$name.json" "$name.png" << 'PYEOF'
import json, base64, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    with open(src, 'r', encoding='utf-8') as f:
        d = json.load(f)
    if 'error' in d:
        print('ERR', d['error'].get('message', '?')[:80])
        sys.exit(1)
    b64 = d['data'][0]['b64_json']
    with open(dst, 'wb') as f:
        f.write(base64.b64decode(b64))
    print('OK', len(b64))
except Exception as e:
    print('ERR', e)
    sys.exit(1)
PYEOF
    if [ $? -eq 0 ]; then echo "$name 生成成功"; rm -f "$name.json"; break; fi
    sleep 40
  done
done
echo "=== ALL DONE ==="
ls -la *.png 2>/dev/null
