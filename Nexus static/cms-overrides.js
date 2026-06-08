(function () {
  function applyContent(content) {
    if (!content || typeof content !== 'object') return;

    document.querySelectorAll('[data-cms-key]').forEach(function (node) {
      var key = node.getAttribute('data-cms-key');
      var value = content[key];
      if (typeof value !== 'string' || !value.trim()) return;

      var attr = node.getAttribute('data-cms-attr');
      if (attr) node.setAttribute(attr, value);
      else node.textContent = value;
    });
  }

  fetch('/api/cms', {
    headers: { Accept: 'application/json' },
    cache: 'no-store'
  })
    .then(function (response) {
      if (!response.ok) throw new Error('CMS unavailable');
      return response.json();
    })
    .then(function (payload) {
      if (payload && payload.success) applyContent(payload.content);
    })
    .catch(function () {
      // The static site should remain usable if the CMS API is unavailable.
    });
})();
