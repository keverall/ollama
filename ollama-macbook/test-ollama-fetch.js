const urls = [
  'http://127.0.0.1:11434/api/tags',
  'http://localhost:11434/api/tags',
  'http://[::1]:11434/api/tags'
];

async function testFetch() {
  for (const url of urls) {
    try {
      console.log(`Testing fetch to: ${url}`);
      const res = await fetch(url, { method: 'GET' });
      console.log(`SUCCESS for ${url}: ${res.status}`);
    } catch (e) {
      console.error(`FAILED for ${url}: ${e.message}`);
    }
  }
}

testFetch();
