"""Prepare private local assets/config for the mobile prototype; prints no secrets."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import secrets
import shutil

root = Path(__file__).resolve().parents[1]
args = argparse.ArgumentParser()
args.add_argument('--card', type=Path, required=True, help='Original character card PNG')
args.add_argument('--preset', type=Path, required=True, help='Original chat-completion preset JSON')
args.add_argument('--sillytavern-data', type=Path, default=root.parent / 'SillyTavern-Launcher/SillyTavern/data/default-user')
a = args.parse_args()
local = root / '.local'
local.mkdir(exist_ok=True, mode=0o700)
blob = a.card.read_bytes()
if blob[:8] != b'\x89PNG\r\n\x1a\n': raise SystemExit('Expected PNG character card')
i = 8
card = None
while i + 12 <= len(blob):
    size = int.from_bytes(blob[i:i+4], 'big'); kind = blob[i+4:i+8]; data = blob[i+8:i+8+size]; i += size + 12
    if kind == b'tEXt' and data.startswith((b'chara\0', b'ccv3\0')):
        card = json.loads(base64.b64decode(data.split(b'\0', 1)[1])); break
if card is None: raise SystemExit('PNG has no character metadata')
(local / 'character.json').write_text(json.dumps(card, ensure_ascii=False, indent=2))
shutil.copyfile(a.preset, local / 'preset.json')
if not (root / '.env').exists():
    settings = json.loads((a.sillytavern_data / 'settings.json').read_text())['oai_settings']
    if settings.get('chat_completion_source') != 'deepseek' or settings.get('reverse_proxy'):
        raise SystemExit('This importer only supports the currently verified direct DeepSeek connection; configure .env manually.')
    stored = json.loads((a.sillytavern_data / 'secrets.json').read_text()).get('api_key_deepseek')
    key = stored if isinstance(stored, str) else next((item.get('value') for item in stored or [] if item.get('active')), None)
    if not key: raise SystemExit('No active DeepSeek key')
    backend = (a.sillytavern_data.parents[1] / 'src/endpoints/backends/chat-completions.js').read_text()
    match = re.search(r"const API_DEEPSEEK = '([^']+)'", backend)
    if not match: raise SystemExit('Cannot determine original DeepSeek endpoint')
    env = dict(LLM_PROVIDER='openai-compatible', LLM_API_KEY=key, LLM_BASE_URL=match[1], LLM_MODEL=settings.get('deepseek_model', 'deepseek-flash'), OPENAI_API_MODE='chat', PORT='3000', AUTH_MODE='api_key', AUTH_API_KEYS=secrets.token_urlsafe(32), DATABASE_URL='data/mobile-prototype.db', ENABLE_SSE_CHAT='true', ENABLE_PROMPT_DRY_RUN='true', ENABLE_MEMORY='false', ENABLE_MEMORY_CONSOLIDATION='false', ENABLE_ASYNC_MEMORY_INGEST='false', LLM_DEFAULT_TIMEOUT_MS='180000', GENERATION_QUEUE_MODE='reject')
    (root / '.env').write_text('\n'.join(k+'='+json.dumps(v) for k,v in env.items())+'\n')
    os.chmod(root / '.env', 0o600)
print('Prepared private assets. Existing .env is preserved. Start API, then run bootstrap-mobile.py.')
