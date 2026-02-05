# Custom JavaScript for Plack::Middleware::ProofOfWork

## Overview

The middleware allows using a custom JavaScript file for Proof-of-Work calculation. This enables customization of look & feel, additional features, or integration with existing systems.

**Important:**
- API parameters (DIFFICULTY, POW_COOKIE_NAME, etc.) are automatically inserted as a prefix before your JavaScript code
- `getSourceValue()` function is provided by the middleware
- JavaScript file must exist (no inline fallback)

**For complete API documentation see: `JAVASCRIPT_API.md`**

## Standard JavaScript

The bundled `share/pow.js` file is automatically used if no other file is specified.

## Using a Custom JavaScript File

```perl
builder {
    enable "ProofOfWork",
        js_file => '/path/to/my/pow.js';
    $app;
};
```

## Requirements for the JavaScript File

### Must Implement

Your JavaScript file MUST implement these functions:

#### 1. `sha256(message)`

SHA-256 hash calculation using Web Crypto API.

```javascript
async function sha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
```

#### 2. `hasLeadingZeros(hash, full, div)`

Checks if a hash has the required leading zeros (with fractional difficulty support).

```javascript
function hasLeadingZeros(hash, full, div) {
  if (hash.startsWith('0'.repeat(full))) {
    var hexValue = parseInt(hash[full], 16);
    return hexValue < div;
  }
  return false;
}
```

- `full`: Number of integer leading zeros (e.g. 4 for 4.5)
- `div`: Threshold for next hex character (e.g. 8 for 4.5)

#### 3. `setCookie(name, value, days)`

Sets the cookie after successful PoW calculation.

```javascript
function setCookie(name, value, days) {
  const date = new Date();
  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
  const expires = 'expires=' + date.toUTCString();
  document.cookie = name + '=' + value + ';' + expires + ';path=/;SameSite=Strict';
}
```

#### 4. `computeProofOfWork()`

Main function for PoW calculation.

```javascript
async function computeProofOfWork() {
  const SOURCE_VALUE = getSourceValue();  // From Perl
  let nonce = 0;
  
  const full = parseInt(DIFFICULTY);
  const div = 16 - (16 * (DIFFICULTY - full));
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    const hash = await sha256(input);
    
    if (hasLeadingZeros(hash, full, div)) {
      return btoa(nonce.toString());
    }
    
    nonce++;
    
    // Optional: UI updates
    if (nonce % 50000 === 0) {
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  }
}
```

### Available Constants

**Provided by middleware** - do NOT define these in your pow.js:

```javascript
DIFFICULTY        // Number: number of leading zeros (e.g. 4 or 4.5)
POW_COOKIE_NAME   // String: cookie name (e.g. "pow")
COOKIE_DURATION   // Number: validity in days (e.g. 5)
```

Fractional difficulty (e.g. 4.5) is supported for fine-grained control.

### Available Functions

**Provided by middleware**:

```javascript
getSourceValue()  // Returns: String with User-Agent|Timestamp|Language|Host
```

**IMPORTANT:** Always use `getSourceValue()` - do NOT implement this function yourself.

### Main Function

Your JavaScript file should execute the main logic in an IIFE:

```javascript
(async function() {
  try {
    await new Promise(resolve => setTimeout(resolve, 50));
    const powToken = await computeProofOfWork();
    setCookie(POW_COOKIE_NAME, powToken, COOKIE_DURATION);
    
    console.log('Cookie set, reloading page...');
    
    setTimeout(function() {
      window.location.reload();
    }, 100);
    
  } catch (error) {
    console.error('Error during Proof of Work:', error);
  }
})();
```

## Customization Examples

### 1. Custom Styling with Progress Bar

```javascript
function updateProgress(percent) {
  const bar = document.getElementById('progress-bar');
  if (bar) {
    bar.style.width = percent + '%';
  }
}

async function computeProofOfWork() {
  const SOURCE_VALUE = getSourceValue();
  const estimatedAttempts = Math.pow(16, DIFFICULTY);
  let nonce = 0;
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    const hash = await sha256(input);
    
    if (hasLeadingZeros(hash, full, div)) {
      return btoa(nonce.toString());
    }
    
    nonce++;
    
    if (nonce % 5000 === 0) {
      const progress = Math.min((nonce / estimatedAttempts) * 100, 99);
      updateProgress(progress);
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  }
}
```

### 2. Logging to Custom Monitoring System

```javascript
async function computeProofOfWork() {
  const SOURCE_VALUE = getSourceValue();
  const startTime = Date.now();
  let nonce = 0;
  
  const full = parseInt(DIFFICULTY);
  const div = 16 - (16 * (DIFFICULTY - full));
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    const hash = await sha256(input);
    
    if (hasLeadingZeros(hash, full, div)) {
      const duration = Date.now() - startTime;
      
      // Log to custom system
      fetch('/api/pow-stats', {
        method: 'POST',
        body: JSON.stringify({
          difficulty: DIFFICULTY,
          attempts: nonce,
          duration: duration,
          timestamp: Date.now()
        })
      });
      
      return btoa(nonce.toString());
    }
    
    nonce++;
  }
}
```

### 3. Custom Branding

```javascript
// Add custom branding to the UI
(async function() {
  const container = document.querySelector('.spinner-container');
  const logo = document.createElement('img');
  logo.src = '/logo.png';
  logo.style.cssText = 'max-width: 200px; margin-bottom: 20px;';
  container.insertBefore(logo, container.firstChild);
  
  // Rest of PoW logic...
  const powToken = await computeProofOfWork();
  setCookie(POW_COOKIE_NAME, powToken, COOKIE_DURATION);
  window.location.reload();
})();
```

## Testing

Test your custom JavaScript file:

```bash
# 1. Create file
vim /var/www/myapp/custom-pow.js

# 2. Configure in Plack
# app.psgi:
# enable "ProofOfWork", js_file => '/var/www/myapp/custom-pow.js';

# 3. Start server
plackup app.psgi

# 4. Open browser and monitor Developer Console
firefox http://localhost:5000
```

## Debugging Tips

```javascript
// Verbose logging
async function computeProofOfWork() {
  console.log('Starting PoW computation');
  console.log('Difficulty:', DIFFICULTY);
  console.log('Source:', getSourceValue());
  
  const SOURCE_VALUE = getSourceValue();
  let nonce = 0;
  
  const full = parseInt(DIFFICULTY);
  const div = 16 - (16 * (DIFFICULTY - full));
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    const hash = await sha256(input);
    
    // Debug: show hash values
    if (nonce < 10) {
      console.log(`Nonce ${nonce}: ${hash}`);
    }
    
    if (hasLeadingZeros(hash, full, div)) {
      console.log('Found valid hash!');
      console.log('Final nonce:', nonce);
      console.log('Final hash:', hash);
      return btoa(nonce.toString());
    }
    
    nonce++;
  }
}
```

## Security Notes

- Always use Web Crypto API for SHA-256 (don't implement yourself)
- Set cookie with `SameSite=Strict`
- Validate inputs (though controlled by server)
- Avoid external dependencies (XSS risk)
- No sensitive data in JavaScript

## Complete Example

See `share/pow.js` in the distribution for the complete standard implementation.

## See Also

- `JAVASCRIPT_API.md` - Complete API reference
- `share/pow.js` - Reference implementation
- POD documentation in `ProofOfWork.pm`
