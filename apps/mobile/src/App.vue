<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { createTavernClient, type CharacterListItem, type SessionRecord } from '@tavern/sdk';
import { buildTimelineMessages, createInitialRespondStreamState, reduceRespondStream, type TimelineMessageView } from '@tavern/client-helpers';
import { applyRegexScriptsWithTrace } from '../../../packages/adapters-sillytavern/src/regex/regex-engine';
import type { STRegexScript } from '@tavern/adapters-sillytavern';
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';
import CardFrame from './CardFrame.vue';
type Assets = { characterId: string; presetId: string; regexProfileId: string; worldbookProfileId: string; warnings: string[] };
const baseUrl = ref(localStorage.getItem('mobile.base') || '/api');
const apiKey = ref(sessionStorage.getItem('mobile.key') || '');
const player = ref(localStorage.getItem('mobile.player') || '旅人');
const direct = ref(localStorage.getItem('mobile.direct') !== 'false');
const settings = ref(!apiKey.value);
const error = ref(''); const notice = ref(''); const connected = ref(false); const connecting = ref(false);
const characters = ref<CharacterListItem[]>([]); const sessions = ref<SessionRecord[]>([]);
const characterId = ref(''); const current = ref<SessionRecord>(); const messages = ref<TimelineMessageView[]>([]);
const rules = ref<STRegexScript[]>([]); const draft = ref(''); const sending = ref(false); const recovering = ref(false);
const stream = ref(createInitialRespondStreamState()); const optimistic = ref(''); const assets = ref<Assets>();
const list = ref<HTMLElement>(); let epoch = 0; let poll: ReturnType<typeof setTimeout> | undefined; let controller: AbortController | undefined;
const client = () => createTavernClient({ baseUrl: new URL(baseUrl.value, window.location.origin).href.replace(/\/$/, ""), getHeaders: () => ({ Authorization: `Bearer ${apiKey.value}` }) });
const locked = computed(() => sending.value || recovering.value || connecting.value);
const markdown = new MarkdownIt({ html: false, breaks: true });
const lastAssistant = computed(() => [...messages.value].reverse().find(m => m.role === 'assistant')?.id);
const lastMessage = computed(() => messages.value.at(-1));
const canRegenerate = computed(() => !locked.value && lastMessage.value?.role === 'assistant' && lastMessage.value.floorNo > 0 && lastMessage.value.floorState === 'committed');
const rendered = computed(() => messages.value.filter(m => m.role !== 'system').map((m, index, all) => {
  const trace = applyRegexScriptsWithTrace(m.content, rules.value, m.role === 'user' ? 1 : 2, { channel: 'display', depth: all.length - 1 - index });
  const html = trace.text;
  const cards: string[] = [];
  const body = html.replace(/```(?:html)?\s*(<!DOCTYPE html>[\s\S]*?<\/html>)\s*```/gi, (_match, card: string) => { cards.push(card); return ''; });
  const invalid = trace.skippedRules.filter(r => r.reason === 'invalid_regex').map(r => r.ruleName);
  return { ...m, empty: m.role === 'assistant' && !m.content.trim(), body: DOMPurify.sanitize(markdown.render(body)), cards, invalid, incompleteOptions: m.role === 'assistant' && /<SUOT\b/i.test(body) && !/<\/SUOT>/i.test(body) };
}));
async function scroll() { await nextTick(); list.value?.scrollTo({ top: list.value.scrollHeight, behavior: 'smooth' }); }
function describe(e: unknown) { return e instanceof Error ? e.message : String(e); }
async function connect() {
  if (connecting.value || sending.value) return;
  connecting.value = true; error.value = '';
  try {
    if (baseUrl.value !== '/api' && !/^https?:\/\//.test(baseUrl.value)) throw new Error('请输入 /api 或完整的 HTTP(S) 服务地址');
    const api = client(); characters.value = await api.characters.list(); sessions.value = await api.sessions.list({ sortBy: 'updated_at', sortOrder: 'desc', status: 'active' });
    const config = await fetch('/prototype.json'); if (!config.ok) throw new Error('尚未导入原型资产，请先运行 bootstrap'); assets.value = await config.json();
    characterId.value = assets.value?.characterId || characters.value[0]?.id || '';
    localStorage.setItem('mobile.base', baseUrl.value); localStorage.setItem('mobile.player', player.value); sessionStorage.setItem('mobile.key', apiKey.value);
    connected.value = true; settings.value = false;
    const saved = localStorage.getItem('mobile.session'); const session = sessions.value.find(s => s.id === saved) || sessions.value[0];
    if (session) await openSession(session);
  } catch (e) { error.value = describe(e); connected.value = false; } finally { connecting.value = false; }
}
async function openSession(session: SessionRecord) {
  if (sending.value) return;
  const id = ++epoch; clearTimeout(poll); recovering.value = false; current.value = session; messages.value = []; rules.value = []; error.value = ''; notice.value = '';
  localStorage.setItem('mobile.session', session.id);
  try {
    const api = client();
    const [timeline, profile, run] = await Promise.all([api.sessions.timeline({ sessionId: session.id }), session.regexProfileId ? api.regexProfiles.getDetail({ profileId: session.regexProfileId }) : Promise.resolve(null), api.sessions.getActiveRun({ sessionId: session.id })]);
    if (id !== epoch) return;
    rules.value = (profile?.data || []) as STRegexScript[]; messages.value = buildTimelineMessages(timeline.floors);
    recovering.value = Boolean(run.activeRun?.busy);
    if (recovering.value) { notice.value = '服务器仍在生成，正在恢复会话；不会重复发送。'; scheduleRecovery(session.id, id); }
    else if (messages.value.at(-1)?.floorState === 'failed') notice.value = '上一轮生成失败，可查看历史并重新操作。';
    await scroll();
  } catch (e) { if (id === epoch) error.value = describe(e); }
}
function scheduleRecovery(sessionId: string, id: number) {
  poll = setTimeout(async () => {
    if (id !== epoch) return;
    try {
      const api = client(); const [run, timeline] = await Promise.all([api.sessions.getActiveRun({ sessionId }), api.sessions.timeline({ sessionId })]);
      if (id !== epoch) return; messages.value = buildTimelineMessages(timeline.floors);
      recovering.value = Boolean(run.activeRun?.busy);
      if (recovering.value) scheduleRecovery(sessionId, id); else notice.value = '会话已恢复';
      await scroll();
    } catch (e) { if (id === epoch) { recovering.value = false; error.value = '恢复失败：' + describe(e) + '。请点刷新会话重试。'; } }
  }, 1500);
}
async function newSession() {
  if (locked.value || !assets.value || !characterId.value) return;
  sending.value = true; error.value = '';
  try {
    const a = assets.value; const session = await client().sessions.create({ characterId: characterId.value, title: characters.value.find(c => c.id === characterId.value)?.name || '新的旅程', userSnapshot: { name: player.value }, presetId: a.presetId, regexProfileId: a.regexProfileId, worldbookProfileId: a.worldbookProfileId, promptMode: 'compat_strict' });
    if (!session) throw new Error('创建会话未返回结果'); sessions.value.unshift(session); sending.value = false; await openSession(session);
  } catch (e) { error.value = describe(e); } finally { sending.value = false; }
}
async function generate(regenerate = false) {
  const session = current.value; const text = draft.value.trim();
  if (!session || locked.value || (!regenerate && !text) || (regenerate && !canRegenerate.value)) return;
  sending.value = true; error.value = ''; notice.value = ''; optimistic.value = regenerate ? '' : text; stream.value = createInitialRespondStreamState();
  if (!regenerate) draft.value = ''; controller = new AbortController(); await scroll();
  try {
    const api = client(); const common = { sessionId: session.id, config: { enableDirector: false, enableVerifier: false, enableMemoryConsolidation: false }, generationParams: { maxOutputTokens: 65536 } };
    if (regenerate) { notice.value = '正在重新生成…'; const result = await api.sessions.regenerate(common); if (!result.generatedText.trim()) throw new Error('模型未返回正文，可能已用尽推理预算'); }
    else await api.sessions.respondStream({ ...common, message: text, signal: controller.signal, onEvent: event => { stream.value = reduceRespondStream(stream.value, event); void scroll(); } });
    if (stream.value.warnings.length) notice.value = stream.value.warnings.map(w => w.message).join('；');
  } catch (e) { error.value = '生成中断：' + describe(e) + '。正在核对服务端记录，不会自动重发。'; }
  finally {
    controller = undefined; optimistic.value = ''; stream.value = createInitialRespondStreamState(); sending.value = false;
    const failure = error.value; await openSession(session); if (failure) error.value = failure;
    try { sessions.value = await client().sessions.list({ sortBy: 'updated_at', sortOrder: 'desc', status: 'active' }); } catch { /* Timeline remains available. */ }
  }
}
function select(text: string, send: boolean) { if (locked.value) return; draft.value = text; if (send) void generate(); }
function mode(value: boolean) { direct.value = value; localStorage.setItem('mobile.direct', String(value)); }
onMounted(() => { if (apiKey.value) void connect(); });
onBeforeUnmount(() => { ++epoch; clearTimeout(poll); controller?.abort(); });
</script>
<template>
  <div class="shell">
    <header><div><span class="eyebrow">LYRA · PRIVATE TAVERN</span><h1>天琴 <small>把故事带在身边</small></h1></div><button @click="settings = !settings" :disabled="locked">连接设置</button></header>
    <form v-if="settings" class="settings" @submit.prevent="connect">
      <label>服务地址<input v-model="baseUrl" placeholder="/api"></label><label>访问密钥<input v-model="apiKey" type="password" autocomplete="off" placeholder="本地 API Key"></label><label>你的名字<input v-model="player" maxlength="60"></label><button :disabled="locked || !apiKey">{{ connecting ? '连接中…' : '保存并连接' }}</button><small>访问密钥只保留在当前浏览器会话中。模型密钥保存在后端。原型默认：上下文 1M（1,048,576 token），输出 64K（65,536 token，含推理预算）。</small>
    </form>
    <div v-if="error" class="alert" role="alert">{{ error }}</div>
    <div v-if="notice" class="notice" role="status">{{ notice }}</div>
    <details v-if="assets?.warnings.length" class="diagnostics"><summary>兼容性说明（{{ assets.warnings.length }}）</summary><p v-for="w in assets.warnings" :key="w">{{ w }}</p></details>
    <div v-if="connected" class="workspace">
      <aside><label>角色<select v-model="characterId" :disabled="locked"><option v-for="c in characters" :value="c.id" :key="c.id">{{ c.name }}</option></select></label><button class="primary" @click="newSession" :disabled="locked">＋ 开始新的故事</button><label>继续会话<select :value="current?.id || ''" :disabled="locked" @change="openSession(sessions.find(s => s.id === ($event.target as HTMLSelectElement).value)!)"><option v-for="s in sessions" :key="s.id" :value="s.id">{{ s.title || '未命名会话' }}</option></select></label><p class="muted">独立后端 · 原始消息保存<br>卡面在隔离环境中运行</p></aside>
      <section class="conversation"><div class="conversation-head"><span>{{ current?.title || '选择角色，开始一段故事' }}</span><button :disabled="locked || !current" @click="current && openSession(current)">刷新会话</button></div>
        <main ref="list" aria-live="polite"><div v-if="!messages.length && !sending" class="empty">窗外的风景正在等你。<small>开始新故事，或选择一个已有会话。</small></div>
          <article v-for="m in rendered" :key="m.id" :class="['message', m.role]"><span class="speaker">{{ m.role === 'user' ? player : current?.title }}</span><div class="prose" v-html="m.body"></div><p v-if="m.empty" class="alert">模型没有返回正文，可能已用尽输出预算。请重新生成或降低预设的字数、推理要求。</p><p v-if="m.incompleteOptions" class="alert">行动选项输出未闭合，可能已达到模型输出上限。请重新生成或降低预设字数要求。</p><p v-if="m.invalid.length" class="alert">正则无法执行：{{ m.invalid.join('、') }}</p><CardFrame v-for="(html, i) in m.cards" :key="m.id + ':' + i" :html="html" :direct="direct" :disabled="locked || m.id !== lastAssistant || m.id !== lastMessage?.id || m.floorState !== 'committed'" @select="select" @mode="mode" /></article>
          <article v-if="optimistic" class="message user"><span class="speaker">{{ player }}</span><p>{{ optimistic }}</p></article>
          <article v-if="sending" class="message assistant"><span class="speaker">正在续写…</span><div class="prose" v-html="DOMPurify.sanitize(markdown.render(stream.content))"></div></article>
        </main>
        <form class="composer" @submit.prevent="generate()"><textarea v-model="draft" aria-label="消息" placeholder="写下你的回应…" :disabled="locked || !current" rows="3" @keydown.ctrl.enter.prevent="generate()" @keydown.meta.enter.prevent="generate()"></textarea><div><span>{{ recovering ? '恢复生成状态中' : sending ? '生成中，请稍候' : 'Ctrl / ⌘ + Enter 发送' }}</span><button type="button" :disabled="!canRegenerate" @click="generate(true)">重新生成</button><button class="primary" :disabled="locked || !current || !draft.trim()">发送</button></div></form>
      </section>
    </div>
    <div v-else-if="!connecting" class="welcome"><h2>故事，从一次连接开始。</h2><p>填入本地访问密钥，连接你的私人酒馆。</p></div>
  </div>
</template>
