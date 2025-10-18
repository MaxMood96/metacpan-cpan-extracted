/*
LemonLDAP::NG Password 2FA registration script
*/
var displayError, register, setMsg;

setMsg = function(msg, level) {
  $('#msg').attr('trspan', msg);
  $('#msg').html(window.translate(msg));
  $('#color').removeClass('message-positive message-warning message-danger alert-success alert-warning alert-danger');
  $('#color').addClass(`message-${level}`);
  if (level === 'positive') {
    level = 'success';
  }
  $('#color').addClass(`alert-${level}`);
  return $('#msg').attr('role', (level === 'danger' ? 'alert' : 'status'));
};

displayError = function(j, status, err) {
  var res;
  console.error('Error', err);
  res = JSON.parse(j.responseText);
  if (res && res.error) {
    res = res.error.replace(/.* /, '');
    console.error('Returned error', res);
    return setMsg(res, 'warning');
  }
};

register = function() {
  var password, passwordverify;
  password = $('#password2f').val();
  passwordverify = $('#password2fverify').val();
  if (!password) {
    setMsg('PE79', 'warning');
    return $('#password').focus();
  } else {
    return $.ajax({
      type: 'POST',
      url: `${scriptname}2fregisters/password/verify`,
      dataType: 'json',
      data: {
        password: password,
        passwordverify: passwordverify
      },
      headers: {
        "X-CSRF-Check": "1"
      },
      error: displayError,
      success: function(data) {
        var e;
        if (data.error) {
          if (data.error.match(/PE34/)) {
            return setMsg(data.error, 'warning');
          } else {
            return setMsg(data.error, 'danger');
          }
        } else {
          e = jQuery.Event("mfaAdded");
          $(document).trigger(e, [{
            "type": "password"
          }]);
          if (!e.isDefaultPrevented()) {
            return window.location.href = window.portal + "2fregisters?continue=1";
          }
        }
      }
    });
  }
};

// Register "click" events
$(document).ready(function() {
  return $('#register').on('click', register);
});