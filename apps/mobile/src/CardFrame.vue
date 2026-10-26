<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
const props = defineProps<{ html: string; disabled: boolean; direct: boolean }>();
const emit = defineEmits<{ select: [text: string, direct: boolean]; mode: [direct: boolean] }>();
const frame = ref<HTMLIFrameElement>();
const height = ref(360);
const closed = ref(false);
const token = crypto.randomUUID();
const source = computed(() => {
  // Only the known option card's layout is retained; all imported scripts are removed.
  const doc = new DOMParser().parseFromString(props.html.replace(/^```(?:html)?\s*|\s*```$/g, ''), 'text/html');
  doc.querySelectorAll('script,iframe,object,embed,base,meta[http-equiv],link').forEach(e => e.remove());
  doc.querySelectorAll('*').forEach(e => Array.from(e.attributes).forEach(a => { if (/^on/i.test(a.name) || ['srcdoc', 'action', 'formaction'].includes(a.name) || (['href', 'src'].includes(a.name) && /^\s*javascript:/i.test(a.value))) e.removeAttribute(a.name); }));
  const csp = doc.createElement('meta'); csp.httpEquiv = 'Content-Security-Policy';
  csp.content = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; connect-src 'none'; form-action 'none'; base-uri 'none'";
  doc.head.prepend(csp);
  const script = doc.createElement('script');
  script.textContent = `(() => {
    const token = ${JSON.stringify(token)};
    let direct = ${JSON.stringify(props.direct)};
    const disabled = ${JSON.stringify(props.disabled)};
    const send = (type, data = {}) => parent.postMessage({ channel: 'tavern-mobile-card', token, type, ...data }, '*');
    const status = document.getElementById('statusText');
    const toggle = document.getElementById('directSendToggle');
    function update() {
      toggle?.classList.toggle('is-active', direct); toggle?.setAttribute('aria-pressed', String(direct));
      document.getElementById('modeTitle').textContent = direct ? '直接发送' : '仅填入';
      document.getElementById('modeHint').textContent = disabled ? '历史选项或生成中，暂不可操作' : direct ? '点选后立即发出' : '点选后留在输入框';
    }
    const raw = document.getElementById('raw-data');
    const parsed = raw?.innerHTML.match(/<SUOT\\b[^>]*>([\\s\\S]*?)<\\/SUOT>/i);
    const list = document.getElementById('listRoot');
    let count = 0;
    for (const line of (parsed?.[1] || '').split(/\\r?\\n/)) {
      const template = document.createElement('template'); template.innerHTML = line;
      const text = template.content.textContent.trim().replace(/^\\s*\\d+\\s*[.、.)）:：]\\s*/, '');
      if (!text) continue; count++;
      const li = document.createElement('li'); const button = document.createElement('button');
      button.className = 'option-btn'; button.type = 'button'; button.disabled = disabled;
      const number = document.createElement('span'); number.className = 'option-index'; number.textContent = String(count).padStart(2, '0');
      const copy = document.createElement('span'); copy.className = 'option-text'; copy.textContent = text;
      button.append(number, copy); button.onclick = () => { if (disabled) return; if (direct) list.querySelectorAll('button').forEach(b => b.disabled = true); send('select', { text, direct }); };
      li.append(button); list?.append(li);
    }
    document.getElementById('optionCount').textContent = '共 ' + count + ' 条回应';
    if (!count && status) status.textContent = '未找到可解析的行动选项';
    toggle.disabled = disabled; toggle.onclick = () => { direct = !direct; update(); send('mode', { direct }); }; update();
    const resize = () => send('resize', { height: document.body.scrollHeight });
    new ResizeObserver(resize).observe(document.body); resize();
  })();`;
  doc.body.append(script);
  return '<!doctype html>' + doc.documentElement.outerHTML;
});
function receive(event: MessageEvent) {
  if (event.source !== frame.value?.contentWindow || event.origin !== 'null') return;
  const d = event.data;
  if (!d || d.channel !== 'tavern-mobile-card' || d.token !== token) return;
  if (d.type === 'resize' && Number.isFinite(d.height)) height.value = Math.max(100, Math.min(2000, d.height));
  if (props.disabled) return;
  if (d.type === 'select' && typeof d.text === 'string' && d.text.length > 0 && d.text.length < 10000 && typeof d.direct === 'boolean') emit('select', d.text, d.direct);
  if (d.type === 'mode' && typeof d.direct === 'boolean') emit('mode', d.direct);
  if (d.type === 'close') closed.value = true;
}
onMounted(() => window.addEventListener('message', receive));
onBeforeUnmount(() => window.removeEventListener('message', receive));
</script>
<template><iframe v-if="!closed" ref="frame" title="行动选项" sandbox="allow-scripts" referrerpolicy="no-referrer" :srcdoc="source" :style="{ height: height + 'px' }" /></template>
<style scoped>iframe{width:100%;border:0;display:block;border-radius:18px}</style>
