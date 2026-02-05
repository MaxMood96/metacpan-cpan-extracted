// Plack::Middleware::ProofOfWork - pow.js
// 
// This script is loaded by the middleware and automatically receives
// the following API (as a prefix before this code):
//
// Constants:
//   - DIFFICULTY        (Number): difficulty, e.g. 4 or 4.5
//   - POW_COOKIE_NAME   (String): cookie name
//   - COOKIE_DURATION   (Number): cookie validity in days
//
// Functions:
//   - getSourceValue()  (Function): returns source value for PoW
//
// See JAVASCRIPT_API.md for complete API documentation.
// ============================================================================

function updateStatus(message) {
  const status = document.getElementById('status');
  if (status) {
    status.textContent = message;
  }
  console.log(message);
}

async function sha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

function hasLeadingZeros(hash, full, div) {
  if (hash.startsWith('0'.repeat(full))) {
    var hexValue = parseInt(hash[full], 16);
    return hexValue < div;
  }
  return false;
}

function setCookie(name, value, days) {
  const date = new Date();
  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
  const expires = 'expires=' + date.toUTCString();
  document.cookie = name + '=' + value + ';' + expires + ';path=/;SameSite=Strict';
}

async function computeProofOfWork() {
  const SOURCE_VALUE = getSourceValue();
  let nonce = 0;
  let hash = '';
  
  updateStatus('Computing proof of work (difficulty: ' + DIFFICULTY + ')...');
  const startTime = Date.now();
  
  const full = parseInt(DIFFICULTY);
  const div = 16 - (16 * (DIFFICULTY - full));
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    hash = await sha256(input);
    
    if (hasLeadingZeros(hash, full, div)) {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      updateStatus('Proof of work found! (Duration: ' + duration + 's)');
      console.log('Proof of Work found!');
      console.log('Nonce: ' + nonce);
      console.log('Hash: ' + hash);
      console.log('Duration: ' + duration + 's');
      
      return btoa(nonce.toString());
    }
    
    nonce++;
    
    if (nonce % 50000 === 0) {
      updateStatus('Computing... (' + nonce.toLocaleString() + ' attempts)');
      console.log('Attempts: ' + nonce + '...');
      // Give browser time for UI updates
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  }
}

// Main function
(async function() {
  try {
    await new Promise(resolve => setTimeout(resolve, 50));
    const powToken = await computeProofOfWork();
    setCookie(POW_COOKIE_NAME, powToken, COOKIE_DURATION);
    
    updateStatus('Verification complete. Reloading...');
    console.log('Cookie set, reloading page...');
    
    setTimeout(function() {
      window.location.reload();
    }, 100);
    
  } catch (error) {
    console.error('Error during Proof of Work:', error);
    updateStatus('Error: ' + error.message);
  }
})();
