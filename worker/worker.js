// this is AI slop, werks tho

const LOGO_URL = 'https://raw.githubusercontent.com/eiffelbeef/scyphomote/refs/heads/main/assets/scyphomote.png';

function html(title, body) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title} - Scyphomote</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans",Helvetica,Arial,sans-serif;background:#0d1117;color:#e6edf3;display:flex;justify-content:center;align-items:center;min-height:100vh;padding:16px;font-size:14px;line-height:1.5}
.box{background:#161b22;border:1px solid #30363d;border-radius:6px;width:100%;max-width:480px;padding:32px;text-align:center}
.logo{display:block;width:48px;height:48px;border-radius:50%;border:1px solid #30363d;margin:0 auto 16px}
h1{font-size:20px;font-weight:600;color:#f0f6fc;margin-bottom:6px}
p{color:#848d97;font-size:14px;margin-bottom:20px}
.key{background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:12px;font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace;font-size:13px;word-break:break-all;color:#7ee787;margin:16px 0;text-align:left;user-select:all}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;padding:10px 16px;font-size:14px;font-weight:500;border-radius:6px;cursor:pointer;border:1px solid rgba(240,246,252,0.1);background:#238636;color:#fff;text-decoration:none;transition:background .15s}
.btn:hover{background:#2ea043}
.btn-secondary{background:#21262d;color:#c9d1d9;border-color:#30363d;margin-top:12px}
.btn-secondary:hover{background:#30363d}
.steps{margin-top:24px;padding-top:16px;border-top:1px solid #21262d;text-align:left}
.steps h2{font-size:12px;font-weight:600;color:#848d97;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px}
.steps ol{padding-left:20px;color:#848d97;font-size:13px}
.steps li{margin-bottom:4px}
.steps strong{color:#e6edf3}
.note{margin-top:16px;padding:8px 12px;border-radius:6px;background:rgba(56,139,253,0.1);border-left:3px solid #2f81f7;font-size:12px;color:#848d97;text-align:left}
</style>
</head>
<body>
<div class="box">
<img src="${LOGO_URL}" alt="Scyphomote" class="logo">
${body}
</div>
</body>
</html>`;
}

async function generateKey(id, privB64) {
  const norm = id.trim().toLowerCase();
  const priv = Uint8Array.from(atob(privB64), c => c.charCodeAt(0));
  const prefix = new Uint8Array([0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20]);
  const pkcs8 = new Uint8Array(prefix.length + priv.length);
  pkcs8.set(prefix, 0);
  pkcs8.set(priv, prefix.length);
  const key = await crypto.subtle.importKey('pkcs8', pkcs8, { name: 'Ed25519' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'Ed25519' }, key, new TextEncoder().encode(norm));
  const b64 = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${norm}.${b64}`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET') {
      if (url.pathname === '/auth/login') {
        const redirectUri = `${url.origin}/auth/callback`;
        const authUrl = `https://github.com/login/oauth/authorize?client_id=${env.GH_CLIENT_ID}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=read:user`;
        return Response.redirect(authUrl, 302);
      }

      if (url.pathname === '/auth/callback') {
        const code = url.searchParams.get('code');
        if (!code) {
          return new Response(html('Authentication Error', `
            <h1>Authorization Failed</h1>
            <p>GitHub did not provide an authorization code.</p>
            <a href="/auth/login" class="btn">Try Again</a>
          `), { status: 400, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
        }

        const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Scyphomote-License-Worker',
          },
          body: JSON.stringify({
            client_id: env.GH_CLIENT_ID,
            client_secret: env.GH_CLIENT_SECRET,
            code,
          }),
        });
        const tokenData = await tokenRes.json();
        if (!tokenData.access_token) {
          return new Response(html('Authentication Error', `
            <h1>Login Failed</h1>
            <p>${tokenData.error_description || 'Unable to authenticate with GitHub.'}</p>
            <a href="/auth/login" class="btn">Try Again</a>
          `), { status: 401, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
        }

        const userRes = await fetch('https://api.github.com/user', {
          headers: {
            'Authorization': `Bearer ${tokenData.access_token}`,
            'User-Agent': 'Scyphomote-License-Worker',
          },
        });
        const userData = await userRes.json();
        const username = userData.login;
        const maintainer = env.GH_MAINTAINER || 'eiffelbeef';

        let isSponsor = username.toLowerCase() === maintainer.toLowerCase();

        if (!isSponsor) {
          const checkToken = env.GH_PAT || tokenData.access_token;
          const gqlQuery = `query($maintainer: String!) {
            user(login: $maintainer) {
              sponsorshipForViewerAsSponsor(activeOnly: true) { isActive }
            }
          }`;
          const gqlRes = await fetch('https://api.github.com/graphql', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${checkToken}`,
              'Content-Type': 'application/json',
              'User-Agent': 'Scyphomote-License-Worker',
            },
            body: JSON.stringify({ query: gqlQuery, variables: { maintainer } }),
          });
          const gqlData = await gqlRes.json();
          isSponsor = !!gqlData.data?.user?.sponsorshipForViewerAsSponsor?.isActive;
        }

        if (!isSponsor) {
          return new Response(html('Sponsorship Required', `
            <h1>Sponsorship Not Found</h1>
            <p>Signed in as <strong>@${username}</strong>.<br>No active GitHub sponsorship was found for <strong>@${maintainer}</strong>.</p>
            <a href="https://github.com/sponsors/${maintainer}" class="btn" target="_blank">Sponsor @${maintainer} on GitHub</a>
            <a href="/auth/login" class="btn btn-secondary">Try Another Account</a>
          `), { status: 403, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
        }

        const licenseKey = await generateKey(username, env.PRIVATE_KEY_B64);
        return new Response(html('Your License Key', `
          <h1>Thank you, @${username}!</h1>
          <p>Your sponsorship is active. Here is your offline Premium license key:</p>
          <div class="key" id="k">${licenseKey}</div>
          <button class="btn" id="b" onclick="navigator.clipboard.writeText(document.getElementById('k').innerText).then(()=>{b=document.getElementById('b');b.innerText='Copied!';b.style.background='#1f6feb'})">Copy License Key</button>
          <div class="steps">
            <h2>How to activate in Scyphomote:</h2>
            <ol>
              <li>Open <strong>Scyphomote</strong></li>
              <li>Go to <strong>Settings</strong> &gt; <strong>Premium</strong></li>
              <li>Tap <strong>Enter License Key</strong> and paste</li>
              <li>Tap <strong>Activate</strong></li>
            </ol>
          </div>
          <div class="note">You can revisit this page anytime to view your key again.</div>
        `), { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
      }

      return new Response(html('Scyphomote Premium', `
        <h1>Scyphomote Premium</h1>
        <p>Sign in with your GitHub account to verify your sponsorship and claim your offline license key.</p>
        <a href="/auth/login" class="btn">
          <svg height="16" width="16" viewBox="0 0 16 16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>
          Sign in with GitHub
        </a>
      `), { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }

    // Admin-only manual key generation (requires WEBHOOK_SECRET to be configured)
    if (request.method === 'POST') {
      if (!env.WEBHOOK_SECRET) {
        return new Response(JSON.stringify({ error: 'WEBHOOK_SECRET not configured' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
      const token = url.searchParams.get('token') || request.headers.get('x-webhook-token');
      if (token !== env.WEBHOOK_SECRET) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { 'Content-Type': 'application/json' } });
      }
      const data = await request.json().catch(() => ({}));
      const id = (data.sponsorship?.sponsor?.login || data.from_name || data.username || data.email || data.identifier || '').trim().toLowerCase();
      if (!id) {
        return new Response(JSON.stringify({ error: 'No identifier found' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
      }
      const licenseKey = await generateKey(id, env.PRIVATE_KEY_B64);
      return new Response(JSON.stringify({ success: true, identifier: id, licenseKey }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    return new Response('Method Not Allowed', { status: 405 });
  },
};
