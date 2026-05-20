const escapeText = (value) => String(value || '');

const inlineNodes = (text) => {
  const source = String(text || '');
  const nodes = [];
  let rest = source;
  while (rest) {
    const boldStart = rest.indexOf('**');
    if (boldStart < 0) {
      nodes.push({ type: 'text', text: escapeText(rest) });
      break;
    }
    if (boldStart > 0) nodes.push({ type: 'text', text: escapeText(rest.slice(0, boldStart)) });
    const afterStart = rest.slice(boldStart + 2);
    const boldEnd = afterStart.indexOf('**');
    if (boldEnd < 0) {
      nodes.push({ type: 'text', text: escapeText(rest.slice(boldStart)) });
      break;
    }
    nodes.push({
      name: 'strong',
      children: [{ type: 'text', text: escapeText(afterStart.slice(0, boldEnd)) }]
    });
    rest = afterStart.slice(boldEnd + 2);
  }
  return nodes;
};

export const markdownToNodes = (markdown = '') => {
  const lines = String(markdown || '').split(/\r?\n/);
  const nodes = [];
  lines.forEach((line) => {
    const text = line.trimEnd();
    if (!text.trim()) {
      nodes.push({ name: 'br' });
      return;
    }
    const heading = /^(#{1,3})\s+(.+)$/.exec(text);
    if (heading) {
      nodes.push({
        name: heading[1].length === 1 ? 'h2' : 'h3',
        attrs: { class: 'md-heading' },
        children: inlineNodes(heading[2])
      });
      return;
    }
    const quote = /^>\s*(.+)$/.exec(text);
    if (quote) {
      nodes.push({
        name: 'blockquote',
        attrs: { class: 'md-quote' },
        children: inlineNodes(quote[1])
      });
      return;
    }
    const list = /^[-*]\s+(.+)$/.exec(text);
    if (list) {
      nodes.push({
        name: 'p',
        attrs: { class: 'md-list' },
        children: [{ type: 'text', text: '• ' }, ...inlineNodes(list[1])]
      });
      return;
    }
    nodes.push({ name: 'p', attrs: { class: 'md-p' }, children: inlineNodes(text) });
  });
  return nodes;
};
