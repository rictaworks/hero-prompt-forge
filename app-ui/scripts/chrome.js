// 全画面で共通の外枠を組み立てる。
//
// Claude Design 側では HPFAppBar / HPFMockLinks が dc-import される部品で、
// 画面リストは HPFMockLinks の renderVals() が持つ配列 1 本だった。
// ここでも同じく SCREENS を唯一の情報源とし、実装済みかどうかもここで持つ。
// 画面を実装したら file を埋めるだけで、全ページの導線が同時に開く。
(function () {
  'use strict';

  var SCREENS = [
    { no: '01', en: 'Landing',     ja: 'ランディング', mock: 'Landing.dc.html',     file: 'index.html' },
    { no: '02', en: 'Projects',    ja: '履歴・一覧',   mock: 'Projects.dc.html',    file: null },
    { no: '03', en: 'New Request', ja: '入力フォーム', mock: 'NewRequest.dc.html',  file: null },
    { no: '04', en: 'Generating',  ja: '生成中',       mock: 'Generating.dc.html',  file: null },
    { no: '05', en: 'Result',      ja: '結果3案',      mock: 'Result.dc.html',      file: null },
    { no: '06', en: 'Evaluation',  ja: '評価メモ',     mock: 'Evaluation.dc.html',  file: null },
    { no: '07', en: 'Presets',     ja: 'プリセット',   mock: 'Presets.dc.html',     file: null },
    { no: '08', en: 'Degraded',    ja: '縮退・エラー', mock: 'Degraded.dc.html',    file: 'degraded.html' },
    { no: '09', en: 'Admin',       ja: '規則辞書',     mock: 'Admin.dc.html',       file: null }
  ];

  function screenBy(en) {
    return SCREENS.filter(function (s) { return s.en === en; })[0] || null;
  }

  // 未実装の画面へは 404 を出さないよう href を張らず、本来の遷移先だけ属性に残す。
  function applyTarget(el, en) {
    var s = screenBy(en);
    if (s && s.file) {
      el.setAttribute('href', s.file);
    } else {
      el.setAttribute('href', '#');
      el.setAttribute('title', en + '（未実装）');
    }
    if (s) el.setAttribute('data-mock-target', s.mock);
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  // ── HPFAppBar ──────────────────────────────────────────
  function renderAppBar(host) {
    var active = host.getAttribute('data-active') || 'None';
    var plan = host.getAttribute('data-plan') || 'PLAN · ACTIVE';
    var user = host.getAttribute('data-user') || '@ao_design';

    var left = el('div', 'hpf-appbar__left');

    var logo = el('a', 'vd-logo');
    logo.href = 'index.html';
    var disc = el('span', 'vd-logo__disc');
    disc.innerHTML = '<i class="fa-solid fa-dragon" aria-hidden="true"></i>';
    logo.appendChild(disc);
    logo.appendChild(el('span', null, 'Veyra Dragon'));
    left.appendChild(logo);

    var nav = el('nav', 'hpf-appbar__nav');
    [['Projects', 'プロジェクト'], ['Presets', 'プリセット'], ['Admin', '管理']].forEach(function (item) {
      var link = el('a', 'hpf-appbar__navlink' + (active === item[0] ? ' hpf-appbar__navlink--active' : ''));
      applyTarget(link, item[0]);
      if (active === item[0]) link.setAttribute('aria-current', 'page');
      link.appendChild(el('span', 'hpf-appbar__navlink-en', item[0]));
      link.appendChild(el('span', 'hpf-appbar__navlink-ja', item[1]));
      nav.appendChild(link);
    });
    left.appendChild(nav);

    var right = el('div', 'hpf-appbar__right');
    right.appendChild(el('span', 'hpf-appbar__plan', plan));
    right.appendChild(el('span', 'hpf-appbar__user', user));

    var cta = el('a', 'vd-btn vd-btn--solid');
    applyTarget(cta, 'New Request');
    cta.innerHTML = '<i class="fa-solid fa-plus" aria-hidden="true"></i>';
    cta.appendChild(el('span', null, '新規生成'));
    right.appendChild(cta);

    host.appendChild(left);
    host.appendChild(right);
  }

  // ── HPFMockLinks ───────────────────────────────────────
  function renderMockLinks(host) {
    var current = host.getAttribute('data-current') || '';

    host.appendChild(el('span', 'hpf-mocklinks__label', 'MOCK INDEX — 全9画面'));

    var list = el('div', 'hpf-mocklinks__list');
    SCREENS.forEach(function (s) {
      var item;
      if (s.file) {
        item = el('a', 'hpf-mocklink');
        item.href = s.file;
        if (s.en === current) item.setAttribute('aria-current', 'page');
      } else {
        item = el('span', 'hpf-mocklink hpf-mocklink--pending');
        item.title = s.en + '（未実装）';
      }
      item.setAttribute('data-mock-target', s.mock);
      item.appendChild(el('span', 'hpf-mocklink__no', s.no));
      item.appendChild(el('span', 'hpf-mocklink__en', s.en));
      item.appendChild(el('span', 'hpf-mocklink__ja', s.ja));
      list.appendChild(item);
    });
    host.appendChild(list);
  }

  document.querySelectorAll('[data-chrome="appbar"]').forEach(renderAppBar);
  document.querySelectorAll('[data-chrome="mocklinks"]').forEach(renderMockLinks);
  document.querySelectorAll('[data-screen-link]').forEach(function (node) {
    applyTarget(node, node.getAttribute('data-screen-link'));
  });
})();
