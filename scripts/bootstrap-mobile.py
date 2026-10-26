"""Import the locally prepared prototype assets. Never prints credentials or prompts."""
import copy
import json
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / '.local'
env = {}
for line in (ROOT / '.env').read_text().splitlines():
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        try: env[k] = json.loads(v)
        except ValueError: env[k] = v

def api(path, data=None, method=None):
    body = json.dumps(data, ensure_ascii=False).encode() if data is not None else None
    request = Request('http://127.0.0.1:3000' + path, data=body, method=method,
                      headers={'Authorization': 'Bearer ' + env['AUTH_API_KEYS'], 'Content-Type': 'application/json'})
    try:
        with urlopen(request, timeout=180) as response: return json.load(response)
    except HTTPError as e:
        detail = json.loads(e.read())
        raise RuntimeError(f'{path}: {e.code} {detail.get("error", {}).get("code", "unknown")}') from None

if __name__ == '__main__':
    if (LOCAL / 'assets.json').exists():
        result = json.loads((LOCAL / 'assets.json').read_text())
        api('/characters/' + result['characterId'])
        print('Assets already imported; keeping existing IDs.')
    else:
        card = json.loads((LOCAL / 'character.json').read_text())
        original = json.loads((LOCAL / 'preset.json').read_text())
        preset = copy.deepcopy(original)
        preset['openai_max_context'] = 1048576
        preset['openai_max_tokens'] = 65536
        # SillyTavern's normal character chat uses track 100001; upstream selects 100000.
        active = next(x for x in preset['prompt_order'] if x['character_id'] == 100001)
        preset['prompt_order'] = [{'character_id': 100000, 'order': active['order']}]
        for entry in preset['prompts']:
            if entry.get('role') == 'model': entry['role'] = 'assistant'
        existing = next((c for c in api('/characters')['data'] if c['name'] == card['data']['name']), None)
        char = {'character_id': existing['id']} if existing else api('/import/character', {'payload': card, 'create_session': False})['data']
        found = next((p for p in api('/presets')['data'] if p['name'] == '夏瑾 天琴座 · 移动兼容'), None)
        pre = found or api('/import/preset', {'name': '夏瑾 天琴座 · 移动兼容', 'data': preset})['data']
        regexes = copy.deepcopy(original['extensions']['regex_scripts'])
        for rule in regexes:
            for field in ('minDepth', 'maxDepth'):
                if rule.get(field) is None: rule[field] = -1
        regex = api('/import/regex', {'name': '夏瑾 · 原始预设正则', 'data': regexes})['data']
        world = api('/import/worldbook', {'name': card['data']['name'] + ' · 内嵌世界书', 'data': card['data']['character_book']})['data']
        warnings = [
            '原型仅适配当前角色卡与行动选项，不提供完整酒馆助手 API。',
            '预设四处 model 角色名已规范化为 assistant；正则无限制深度 null 映射为 -1。',
            '已将单角色轨道 100001 映射为后端活动轨道，保留其中 59 项顺序与开关。',
            '预设两组正则中有 3 条查找规则不同；采用 regex_scripts，未叠加 SPreset 规则。',
            '预设声明 200 万上下文和 65535 输出；真实请求受模型限制，原型单次输出上限设为 4096。',
        ]
        result = dict(characterId=char['character_id'], presetId=pre['id'], regexProfileId=regex['id'], worldbookProfileId=world['id'], warnings=warnings)
        (LOCAL / 'assets.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
        (LOCAL / 'regex-compat.json').write_text(json.dumps(regex, ensure_ascii=False, indent=2))
        session = api('/sessions', {'character_id': result['characterId'], 'preset_id': result['presetId'], 'regex_profile_id': result['regexProfileId'], 'worldbook_profile_id': result['worldbookProfileId'], 'prompt_mode': 'compat_strict', 'title': card['data']['name'], 'user_snapshot': {'name': '旅人'}})['data']
        (LOCAL / 'session.json').write_text(json.dumps(session, ensure_ascii=False, indent=2))
        print('Imported character, preset, regex profile and 7-entry worldbook; created session.')
    # Migrate this prototype's imported copy only; preserve prompt order and source assets.
    path = '/presets/' + result['presetId']
    document = api(path + '/editor')['data']
    top = document['editor']['top_level']
    original = json.loads((LOCAL / 'preset.json').read_text())
    active_order = next(x['order'] for x in original['prompt_order'] if x['character_id'] == 100001)
    active_ids = [x['identifier'] for x in active_order if x['enabled']]
    current_ids = [e['identifier'] for e in document['editor']['entries'] if e['enabled']]
    if top.get('openai_max_context') != 1048576 or top.get('openai_max_tokens') != 65536 or current_ids != active_ids:
        top['openai_max_context'] = 1048576
        top['openai_max_tokens'] = 65536
        # The upstream editor appends entries absent from prompt_order as enabled.
        # Keep those entries available but explicitly disabled when saving defaults.
        rank = {item['identifier']: index for index, item in enumerate(active_order)}
        for entry in document['editor']['entries']:
            entry['enabled'] = entry['identifier'] in active_ids
        document['editor']['entries'].sort(key=lambda entry: rank.get(entry['identifier'], len(rank)))
        api(path, {'name': document['name'], 'editor': document['editor'],
                   'expected_version': document['version']}, method='PUT')
        print('Prototype preset defaults updated: context 1048576; output 65536 tokens.')
    saved = api(path)['data']['data']
    selected = next(t['order'] for t in saved['prompt_order'] if t['character_id'] == 100000)
    assert [x['identifier'] for x in selected if x['enabled']] == active_ids, 'Enabled prompt order changed'
    public = ROOT / 'apps/mobile/public'
    public.mkdir(parents=True, exist_ok=True)
    (public / 'prototype.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
