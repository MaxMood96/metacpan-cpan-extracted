/*
LemonLDAP::NG WebAuthn verify script
*/
var check, setMsg, setupConditional, trySetupConditional;

setMsg = function(msg, level) {
  $('#msg').attr('trspan', msg);
  $('#msg').html(window.translate(msg));
  $('#color').removeClass('message-positive message-warning message-danger alert-success alert-warning alert-danger');
  $('#color').addClass(`message-${level}`);
  if (level === 'positive') {
    level = 'success';
  }
  return $('#color').addClass(`alert-${level}`);
};

check = function() {
  var e, request;
  if (!webauthnJSON.supported()) {
    setMsg('webAuthnUnsupported', 'warning');
    return;
  }
  if (window.webauthnAbort) {
    console.debug("Aborting conditional mediation");
    window.webauthnAbort.abort();
  }
  e = jQuery.Event("webauthnAttempt");
  $(document).trigger(e);
  if (!e.isDefaultPrevented()) {
    setMsg('webAuthnBrowserInProgress', 'warning');
    request = {
      publicKey: window.datas.request
    };
    return webauthnJSON.get(request).then(function(response) {
      e = jQuery.Event("webauthnSuccess");
      $(document).trigger(e, [response]);
      if (!e.isDefaultPrevented()) {
        $('#credential').val(JSON.stringify(response));
        return $('#credential').closest('form').submit();
      }
    }).catch(function(error) {
      e = jQuery.Event("webauthnFailure");
      $(document).trigger(e, [error]);
      if (!e.isDefaultPrevented()) {
        setMsg('webAuthnBrowserFailed', 'danger');
      }
      return trySetupConditional();
    });
  }
};

// This function is exported so that custom JS code can call it
// Do not remove without a deprecation notice
window.webauthn_start = check;

trySetupConditional = function() {
  if (PublicKeyCredential.isConditionalMediationAvailable) {
    return PublicKeyCredential.isConditionalMediationAvailable().then(function(result) {
      if (result) {
        return setupConditional();
      }
    });
  }
};

setupConditional = function() {
  var request;
  console.debug("Setting up conditional mediation");
  window.webauthnAbort = new AbortController();
  request = {
    publicKey: window.datas.request,
    mediation: "conditional",
    signal: window.webauthnAbort.signal
  };
  return webauthnJSON.get(request).then(function(response) {
    var e;
    e = jQuery.Event("webauthnSuccess");
    $(document).trigger(e, [response]);
    if (!e.isDefaultPrevented()) {
      $('#credential').val(JSON.stringify(response));
      return $('#credential').closest('form').submit();
    }
  }).catch(function(error) {
    var e;
    e = jQuery.Event("webauthnFailure");
    $(document).trigger(e, [error]);
    if (!e.isDefaultPrevented()) {
      // do nothing ?
      return true;
    }
  });
};

$(document).on("portalLoaded", {}, function(event, info) {
  return $(document).ready(function() {
    $('#retrybutton').on('click', check);
    $('.webauthnclick').on('click', check);
    trySetupConditional();
    if (window.datas.webauthn_autostart) {
      return setTimeout(check, 1000);
    }
  });
});