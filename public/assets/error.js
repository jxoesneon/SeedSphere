'use strict';
(function () {
  function qs(name) { try { const u = new URL(window.location.href); return u.searchParams.get(name) || ''; } catch (_) { return ''; } }
  function set(id, text) { const el = document.getElementById(id); if (el) el.textContent = text; }
  function addAction(text) { const ul = document.getElementById('actions'); if (!ul) return; const li = document.createElement('li'); li.textContent = text; ul.appendChild(li); }

  const code = (qs('code') || 'unknown_error').trim();
  const reason = (qs('reason') || '').trim();
  const seedlingId = (qs('seedling_id') || '').trim();
  const gardenerId = (qs('gardener_id') || '').trim();
  const detail = (qs('detail') || '').trim();

  set('code', code || 'unknown_error');

  // Basic mapping for titles and descriptions
  const map = {
    unauthorized: { title: 'Unauthorized', desc: 'You are not signed in on this origin or the current session is invalid.' },
    seedling_revoked: { title: 'Seedling revoked', desc: 'This installation was revoked and can no longer be used.' },
    seedling_invalid_signature: { title: 'Invalid link', desc: 'The link signature is invalid or expired. Please reopen Configure after signing in.' },
    account_no_binding: { title: 'No binding found', desc: 'There is no secure link between this Gardener and Seedling.' },
    account_invalid_signature: { title: 'Invalid signature', desc: 'The signature verification failed for this request.' },
    account_missing_identities: { title: 'Missing identities', desc: 'Required identities were not provided in the request.' },
    db_error: { title: 'Temporary server issue', desc: 'We ran into a server-side hiccup. Please try again shortly.' },
    // Auth & OAuth
    invalid_token: { title: 'Invalid token', desc: 'The provided token is invalid.' },
    invalid_or_expired: { title: 'Invalid or expired', desc: 'The sign-in link is invalid or has expired. Request a new one.' },
    server_not_configured: { title: 'Server not configured', desc: 'Authentication is not configured on this server.' },
    google_not_configured: { title: 'Google auth not configured', desc: 'Google OAuth is not configured on this server.' },
    oauth_error: { title: 'Sign-in error', desc: 'An error occurred during sign-in. Please try again.' },
    missing_code: { title: 'Missing code', desc: 'The authorization code was not provided.' },
    missing_verifier: { title: 'Missing verifier', desc: 'The PKCE verifier was not provided or has expired.' },
    missing_id_token: { title: 'Missing ID token', desc: 'The identity token was not returned by the provider.' },
    unknown_error: { title: 'Something went wrong', desc: 'We could not complete this action.' },
  };
  const meta = map[code] || map.unknown_error;
  set('title', meta.title);
  set('desc', meta.desc);

  // Contextual actions
  switch (code) {
    case 'unauthorized':
      addAction('Sign in using Start to create a session on this origin.');
      break;
    case 'seedling_revoked':
      addAction('Reinstall or mint a new seedling from the Account page.');
      break;
    case 'seedling_invalid_signature':
    case 'account_invalid_signature':
      addAction('Reopen Configure after signing in.');
      break;
    case 'account_no_binding':
      addAction('Auto-link your Gardener and Seedling from the Start page.');
      break;
    default:
      addAction('Open Start and follow the on-screen instructions.');
  }
  addAction('Check your seedlings and gardeners on the Account page.');

  // Quick links preserve context where possible
  const start = document.getElementById('startLink');
  const account = document.getElementById('accountLink');
  const params = new URLSearchParams();
  if (seedlingId) params.set('seedling_id', seedlingId);
  if (start) start.href = params.size ? `/#/start?${params}` : '/#/start';
  if (account) account.href = '/#/account';

  // Technical details
  if (detail || reason || seedlingId || gardenerId) {
    const lines = [];
    if (reason) lines.push(`reason: ${reason}`);
    if (detail) lines.push(`detail: ${detail}`);
    if (seedlingId) lines.push(`seedling_id: ${seedlingId}`);
    if (gardenerId) lines.push(`gardener_id: ${gardenerId}`);
    set('details', lines.join('\n'));
  }
})();
