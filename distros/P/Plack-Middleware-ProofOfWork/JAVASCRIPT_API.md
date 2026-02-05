# JavaScript API for Plack::Middleware::ProofOfWork

## Overview

The `pow.js` script automatically receives constants and functions from the middleware. These are provided as an "API prefix" before the actual JavaScript code.

## API Provided by the Middleware

### Constants

These constants are automatically set by Perl and available in JavaScript:

```javascript
const DIFFICULTY        // Number: difficulty (e.g. 4 or 4.5)
const POW_COOKIE_NAME   // String: cookie name (e.g. "pow")
const COOKIE_DURATION   // Number: cookie validity in days (e.g. 5)
```

**Example values:**
```javascript
DIFFICULTY = 4.5
POW_COOKIE_NAME = "pow"
COOKIE_DURATION = 5
```

### Functions

#### getSourceValue()

Returns the source value for PoW calculation.

**Signature:**
```javascript
function getSourceValue(): string
```

**Return value:**
```javascript
"Mozilla/5.0...|1738540800|en-US,de|example.com"
```

**Format:** `UserAgent|Timestamp|AcceptLanguage|Host`

**Components:**
- **UserAgent**: Browser User-Agent string
- **Timestamp**: Rounded Unix timestamp (to cookie duration)
- **AcceptLanguage**: Accept-Language header
- **Host**: HTTP Host header

**Usage in pow.js:**
```javascript
const SOURCE_VALUE = getSourceValue();
const input = SOURCE_VALUE + ':' + nonce;
```

## Required Functions in pow.js

The `pow.js` script MUST implement the following functions:

### 1. sha256(message)

SHA-256 hash calculation using Web Crypto API.

**Signature:**
```javascript
async function sha256(message: string): Promise<string>
```

**Implementation:**
```javascript
async function sha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
```

**Return value:** Hex string (64 characters)

### 2. hasLeadingZeros(hash, full, div)

Checks if a hash has the required leading zeros (with fractional difficulty).

**Signature:**
```javascript
function hasLeadingZeros(hash: string, full: number, div: number): boolean
```

**Parameters:**
- `hash`: The hash to check (hex string)
- `full`: Number of integer leading zeros
- `div`: Threshold for the next hex character

**Implementation:**
```javascript
function hasLeadingZeros(hash, full, div) {
  if (hash.startsWith('0'.repeat(full))) {
    var hexValue = parseInt(hash[full], 16);
    return hexValue < div;
  }
  return false;
}
```

**Example:**
```javascript
// Difficulty 4.5
const full = 4;
const div = 8;  // 16 - (16 * 0.5)

hasLeadingZeros("00007abc...", 4, 8)  // true  (7 < 8)
hasLeadingZeros("00008def...", 4, 8)  // false (8 >= 8)
```

### 3. setCookie(name, value, days)

Sets the Proof-of-Work cookie.

**Signature:**
```javascript
function setCookie(name: string, value: string, days: number): void
```

**Implementation:**
```javascript
function setCookie(name, value, days) {
  const date = new Date();
  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
  const expires = 'expires=' + date.toUTCString();
  document.cookie = name + '=' + value + ';' + expires + ';path=/;SameSite=Strict';
}
```

**Usage:**
```javascript
setCookie(POW_COOKIE_NAME, powToken, COOKIE_DURATION);
```

### 4. computeProofOfWork()

Main function for Proof-of-Work calculation.

**Signature:**
```javascript
async function computeProofOfWork(): Promise<string>
```

**Return value:** Base64-encoded nonce

**Implementation:**
```javascript
async function computeProofOfWork() {
  const SOURCE_VALUE = getSourceValue();  // Use API function
  let nonce = 0;
  let hash = '';
  
  const full = parseInt(DIFFICULTY);
  const div = 16 - (16 * (DIFFICULTY - full));
  
  while (true) {
    const input = SOURCE_VALUE + ':' + nonce;
    hash = await sha256(input);
    
    if (hasLeadingZeros(hash, full, div)) {
      return btoa(nonce.toString());
    }
    
    nonce++;
  }
}
```

### 5. Main IIFE (Immediately Invoked Function Expression)

The script MUST contain an immediately invoked function that:
1. Starts the PoW calculation
2. Sets the cookie
3. Reloads the page

**Implementation:**
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

## Optional UI Functions

### updateStatus(message)

Optional: Displays status updates in the UI.

```javascript
function updateStatus(message) {
  const status = document.getElementById('status');
  if (status) {
    status.textContent = message;
  }
  console.log(message);
}
```

**Usage:**
```javascript
updateStatus('Computing proof of work...');
updateStatus('Proof of work found!');
```

## Complete Example

See `share/pow.js` for the complete reference implementation.

## Workflow

```
1. Middleware generates HTML with API prefix
   - DIFFICULTY = 4.5
   - POW_COOKIE_NAME = "pow"
   - COOKIE_DURATION = 5
   - getSourceValue() = "..."

2. Browser loads HTML
   - pow.js script executes

3. computeProofOfWork() is called
   - Uses getSourceValue() API
   - Uses DIFFICULTY constant
   - Calculates hash until valid

4. setCookie() sets cookie
   - Uses POW_COOKIE_NAME
   - Uses COOKIE_DURATION

5. Page reloads

6. Middleware validates cookie
   - Request passes through
```

## Best Practices

### Do's

- Use `getSourceValue()` instead of your own implementation
- Use provided constants (DIFFICULTY, etc.)
- Implement all required functions
- Use Web Crypto API for SHA-256
- Provide UI feedback during calculation

### Don'ts

- Don't override constants
- Don't implement `getSourceValue()` yourself
- Don't use browser storage APIs (localStorage, etc.)
- Don't include external libraries unnecessarily

## Testing

```javascript
// Test if API is available
console.log('DIFFICULTY:', DIFFICULTY);
console.log('POW_COOKIE_NAME:', POW_COOKIE_NAME);
console.log('COOKIE_DURATION:', COOKIE_DURATION);
console.log('Source Value:', getSourceValue());

// Test calculation
const testHash = "00007abc...";
console.log('Valid?', hasLeadingZeros(testHash, 4, 8));
```

## Error Handling

```javascript
(async function() {
  try {
    // Check if API is available
    if (typeof DIFFICULTY === 'undefined') {
      throw new Error('DIFFICULTY not defined - API missing');
    }
    if (typeof getSourceValue !== 'function') {
      throw new Error('getSourceValue() not available - API missing');
    }
    
    // Normal PoW calculation
    const powToken = await computeProofOfWork();
    setCookie(POW_COOKIE_NAME, powToken, COOKIE_DURATION);
    window.location.reload();
    
  } catch (error) {
    console.error('Error during Proof of Work:', error);
    alert('PoW Error: ' + error.message);
  }
})();
```

## See Also

- `share/pow.js` - Reference implementation
- `CUSTOM_JAVASCRIPT.md` - Guide for custom implementations
- POD documentation in `ProofOfWork.pm`
