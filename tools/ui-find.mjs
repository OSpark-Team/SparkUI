// Print centre coordinates of on-screen nodes whose text matches a regex.
// Usage: devecocli ui layout --device <d> --format json | node tools/ui-find.mjs <regex>
let s = '';
process.stdin.on('data', (d) => (s += d)).on('end', () => {
  const re = new RegExp(process.argv[2]);
  const end = s.indexOf('\n]');
  const tree = JSON.parse(end > 0 ? s.slice(0, end + 2) : s);
  const out = [];
  const walk = (n) => {
    if (!n || typeof n !== 'object') return;
    if (typeof n.text === 'string' && re.test(n.text) && Array.isArray(n.bounds)) {
      const [l, t, r, b] = n.bounds;
      out.push(`${Math.round((l + r) / 2)} ${Math.round((t + b) / 2)}\t${n.text}`);
    }
    for (const k of Object.keys(n)) {
      const v = n[k];
      if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') walk(v);
    }
  };
  walk(tree);
  console.log(out.join('\n'));
});
