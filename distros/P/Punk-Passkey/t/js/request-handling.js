// Exercise the browser helper against a fake browser, driven by
// t/10-asset-js.t.
//
// The rule this pins: a browser allows ONE outstanding credential
// request. Conditional mediation (autofill) leaves one pending from
// page load, so a button press must abort it first - otherwise the
// second call is refused outright, which is a login button that does
// nothing while the passkey sits visibly in the password manager.
// The bug being fixed: conditional mediation leaves a credential request
// pending from page load, and a browser refuses a second one - so a
// button press has to abort the first.
const fs = require('fs');

function makeEnv() {
  const log = [];
  let getCalls = 0;
  const w = {
    AbortController: class {
      constructor() { this.signal = { aborted: false }; }
      abort() { this.signal.aborted = true; log.push('abort'); }
    },
    PublicKeyCredential: {
      isConditionalMediationAvailable: () => Promise.resolve(true),
    },
    navigator: { credentials: {} },
  };
  // the rule under test: one outstanding request at a time
  let outstanding = null;
  w.navigator.credentials.get = (req) => {
    getCalls++;
    log.push('get:' + (req.mediation || 'modal'));
    if (outstanding && !outstanding.signal.aborted) {
      log.push('REFUSED-CONCURRENT');
      return Promise.reject(new Error('A request is already pending.'));
    }
    outstanding = { signal: req.signal || { aborted: false } };
    return new Promise((resolve, reject) => {
      const t = setInterval(() => {
        if (req.signal && req.signal.aborted) {
          clearInterval(t);
          outstanding = null;
          reject(new Error('AbortError'));
        }
      }, 1);
      if (req.mediation !== 'conditional') {
        clearInterval(t);
        outstanding = null;
        resolve({ id: 'cred-id', response: {
          clientDataJSON: new Uint8Array([1]).buffer,
          authenticatorData: new Uint8Array([2]).buffer,
          signature: new Uint8Array([3]).buffer,
          userHandle: null,
        }});
      }
    });
  };
  global.window = w;
  Object.defineProperty(global, "navigator", { value: w.navigator, configurable: true, writable: true });
  global.document = { cookie: '' };
  global.atob = (s) => Buffer.from(s, 'base64').toString('binary');
  global.btoa = (s) => Buffer.from(s, 'binary').toString('base64');
  global.Uint8Array = Uint8Array;
  global.fetch = (url) => {
    log.push('fetch:' + url);
    return Promise.resolve({
      ok: true,
      json: () => Promise.resolve({
        challenge: 'AAAA', rpId: 'localhost', ok: 1,
      }),
    });
  };
  return { w, log, calls: () => getCalls };
}

const src = fs.readFileSync(process.argv[2], 'utf8');
const env = makeEnv();
new Function('window', src + '\n')(env.w);
// the helper attaches to the window it was handed
const PP = env.w.PunkPasskey;
if (!PP) { console.log('FAIL: helper did not attach'); process.exit(1); }

(async () => {
  // page load starts the autofill request
  PP.conditional('/login/passkey', () => env.log.push('conditional-ok'));
  await new Promise(r => setTimeout(r, 30));

  const before = env.log.slice();
  if (!before.some(e => e === 'get:conditional')) {
    console.log('FAIL: conditional never started');
    console.log(before.join(' | '));
    process.exit(1);
  }

  // now the button
  let err = null;
  try { await PP.login('/login/passkey'); }
  catch (e) { err = e; }
  await new Promise(r => setTimeout(r, 30));

  console.log('sequence: ' + env.log.join(' | '));
  const aborted = env.log.indexOf('abort');
  const modal   = env.log.indexOf('get:modal');
  const refused = env.log.includes('REFUSED-CONCURRENT');

  if (refused) { console.log('FAIL: the browser refused the second request'); process.exit(1); }
  if (aborted < 0) { console.log('FAIL: the pending request was never aborted'); process.exit(1); }
  if (!(aborted < modal)) { console.log('FAIL: aborted after the modal get, not before'); process.exit(1); }
  if (err) { console.log('FAIL: login rejected: ' + err.message); process.exit(1); }
  console.log('PASS: the button aborts the autofill request, then its own get succeeds');
})();
