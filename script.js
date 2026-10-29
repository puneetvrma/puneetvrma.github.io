'use strict';
const controls = document.querySelector('.pub-controls');
if (controls) {
  controls.hidden = false;
  const search = document.querySelector('#pub-search');
  const year = document.querySelector('#pub-year');
  const publications = [...document.querySelectorAll('#publication-list .publication')];
  const count = document.querySelector('#pub-count');
  const empty = document.querySelector('#no-results');
  function filterPublications() {
    const terms = search.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
    let shown = 0;
    for (const publication of publications) {
      const text = publication.textContent.toLocaleLowerCase();
      const matches = (year.value === 'all' || publication.dataset.year === year.value) && terms.every(term => text.includes(term));
      publication.hidden = !matches;
      if (matches) shown++;
    }
    count.textContent = `${shown} ${shown === 1 ? 'publication' : 'publications'}${shown < publications.length ? ` of ${publications.length}` : ''}`;
    empty.hidden = shown !== 0;
  }
  search.addEventListener('input', filterPublications);
  year.addEventListener('change', filterPublications);
}
const printButton = document.querySelector('.print-button');
if (printButton) {
  printButton.hidden = false;
  printButton.addEventListener('click', () => window.print());
}
