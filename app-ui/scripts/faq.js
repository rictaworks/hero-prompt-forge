// FaqItem のアコーディオン。
// Claude Design 側は React の useState で開閉している（各項目が独立、初期値は閉）。
// ここでは同じ挙動を素の DOM で再現する。
(function () {
  'use strict';

  document.querySelectorAll('.vd-faq-item__question').forEach(function (button) {
    button.addEventListener('click', function () {
      var answer = document.getElementById(button.getAttribute('aria-controls'));
      if (!answer) return;

      var willOpen = button.getAttribute('aria-expanded') !== 'true';
      button.setAttribute('aria-expanded', String(willOpen));
      answer.classList.toggle('is-open', willOpen);
    });
  });
})();
