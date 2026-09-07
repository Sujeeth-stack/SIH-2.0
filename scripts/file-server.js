// Serves the built APKs for download.
//
// Python's http.server is HTTP/1.0 and single-threaded, which truncates large
// files through a tunnel — a half-written APK fails to install with a useless
// error. Express streams properly, keeps the connection alive and supports
// range requests, so an interrupted phone download can resume.
const express = require('express');
const path = require('path');

const DIST = path.join(__dirname, '..', 'dist');
const PORT = Number(process.env.PORT || 8000);

const app = express();

app.use((req, _res, next) => {
  console.log(new Date().toISOString(), req.method, req.url);
  next();
});

app.use(
  express.static(DIST, {
    acceptRanges: true,          // resumable downloads
    cacheControl: true,
    maxAge: '1h',
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.apk')) {
        res.type('application/vnd.android.package-archive');
        res.set('Content-Disposition',
          `attachment; filename="${path.basename(filePath)}"`);
      }
    },
  })
);

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SANGAM — download</title>
<style>
 body{font-family:system-ui,sans-serif;max-width:34rem;margin:3rem auto;padding:0 1rem;
      color:#1b1f24;line-height:1.5}
 a.btn{display:block;background:#1f5fbf;color:#fff;text-decoration:none;padding:1rem;
       border-radius:10px;text-align:center;font-weight:600;margin:.75rem 0}
 small{color:#5b6470}
</style>
<h1>SANGAM</h1>
<p>Report civic problems in Jharkhand.</p>
<a class="btn" href="/sangam.apk">Download for Android</a>
<a class="btn" href="/sangam-old-phones.apk" style="background:#fff;color:#1b1f24;border:1px solid #e3e6ea">
  Older phones (32-bit)</a>
<p><small>Android will ask you to allow installs from your browser. The app
connects to the SANGAM server automatically — no setup needed.</small></p>`);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`file server on http://0.0.0.0:${PORT} serving ${DIST}`);
});
