/* Progressive enhancement: highlight the heading nearest the reading position. No dependencies. */
(() => {
  const toc = document.querySelector('.zeta-has-toc .article-toc');
  const body = document.querySelector('.zeta-has-toc .article-body');
  if (!toc || !body) return;
  const links = [...toc.querySelectorAll('a[href^="#"]')];
  const items = links.map(link => {
    const id = decodeURIComponent(link.getAttribute('href').slice(1));
    return { link, heading: document.getElementById(id) };
  }).filter(item => item.heading && body.contains(item.heading));
  if (!items.length) return;
  let scheduled = false;
  function update() {
    scheduled = false;
    const offset = Math.max(96, window.innerHeight * .2);
    let current = items[0];
    for (const item of items) {
      if (item.heading.getBoundingClientRect().top <= offset) current = item;
      else break;
    }
    for (const item of items) {
      if (item === current) item.link.setAttribute('aria-current', 'location');
      else item.link.removeAttribute('aria-current');
    }
  }
  function schedule() {
    if (!scheduled) { scheduled = true; window.requestAnimationFrame(update); }
  }
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  window.addEventListener('hashchange', schedule);
  update();
})();
