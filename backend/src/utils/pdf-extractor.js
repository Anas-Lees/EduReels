const pdfParse = require('pdf-parse');

/**
 * Extract text from a PDF buffer page by page.
 * Returns an array of { pageNum, text } for pages with >= 100 chars of text.
 */
async function extractPages(pdfBuffer) {
  const pages = [];

  // Custom page render to capture per-page text
  let currentPage = 0;
  const options = {
    pagerender: function (pageData) {
      currentPage++;
      return pageData.getTextContent().then(function (textContent) {
        const text = textContent.items.map(item => item.str).join(' ').trim();
        if (text.length >= 100) {
          pages.push({ pageNum: currentPage, text });
        }
        return text;
      });
    }
  };

  await pdfParse(pdfBuffer, options);
  return pages;
}

module.exports = { extractPages };
