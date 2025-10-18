/*
LemonLDAP::NG Notifications script
*/
var displayError, msg, setMsg, toggle, toggle_explorer, toggle_eye, viewNotif;

msg = $('#msg').attr('trspan');

setMsg = function(msg, level) {
  $('#msg').html(window.translate(msg));
  $('#color').removeClass('message-positive message-warning alert-success alert-warning');
  $('#color').addClass(`message-${level}`);
  if (level === 'positive') {
    level = 'success';
  }
  $('#color').addClass(`alert-${level}`);
  return $('#color').attr("role", "status");
};

displayError = function(j, status, err) {
  setMsg('notificationRetrieveFailed', 'warning');
  console.error('Error:', err, 'Status:', status);
};

toggle_eye = function(slash) {
  if (slash) {
    $("#icon-explorer-button").removeClass('fa-eye');
    return $("#icon-explorer-button").addClass('fa-eye-slash');
  } else {
    $("#icon-explorer-button").removeClass('fa-eye-slash');
    return $("#icon-explorer-button").addClass('fa-eye');
  }
};

toggle_explorer = function(visible) {
  if (visible) {
    $('#explorer').hide();
    $('#color').hide();
    return toggle_eye(0);
  } else {
    $('#explorer').show();
    $('#color').show();
    return toggle_eye(1);
  }
};

toggle = function(button, notif, epoch) {
  setMsg(msg, 'positive');
  $(".btn-danger").each(function() {
    $(this).removeClass('btn-danger');
    return $(this).addClass('btn-success');
  });
  $(".fa-eye-slash").each(function() {
    $(this).removeClass('fa-eye-slash');
    return $(this).addClass('fa-eye');
  });
  $(".verify").each(function() {
    $(this).text(window.translate('verify'));
    return $(this).attr('trspan', 'verify');
  });
  if (notif && epoch) {
    button.removeClass('btn-success');
    button.addClass('btn-danger');
    $(`#icon-${notif}-${epoch}`).removeClass('fa-eye');
    $(`#icon-${notif}-${epoch}`).addClass('fa-eye-slash');
    $(`#text-${notif}-${epoch}`).text(window.translate('hide'));
    $(`#text-${notif}-${epoch}`).attr('trspan', 'hide');
    $("#myNotification").removeAttr('hidden');
    return toggle_eye(1);
  } else {
    $("#myNotification").attr('hidden', 'true');
    return $("#explorer-button").attr('hidden', 'true');
  }
};

// viewNotif function (launched by "verify" button)
viewNotif = function(notif, epoch, button) {
  console.debug('Ref:', notif, 'epoch:', epoch);
  if (notif && epoch) {
    console.debug('Send AJAX request');
    return $.ajax({
      type: "GET",
      url: `${scriptname}mynotifications/${notif}`,
      data: {
        epoch: epoch
      },
      dataType: 'json',
      error: displayError,
      success: function(resp) {
        var myDate;
        if (resp.result) {
          console.debug('Notification:', resp.notification);
          toggle(button, notif, epoch);
          $('#displayNotif').html(resp.notification);
          $('#notifRef').text(notif);
          myDate = new Date(epoch * 1000);
          $('#notifEpoch').text(myDate.toLocaleString());
          return $("#explorer-button").removeAttr('hidden');
        } else {
          return setMsg('notificationNotFound', 'warning');
        }
      }
    });
  } else {
    return setMsg('notificationRetrieveFailed', 'warning');
  }
};

// Register "click" events
$(document).ready(function() {
  $(".data-epoch").each(function() {
    var myDate;
    myDate = new Date($(this).text() * 1000);
    return $(this).text(myDate.toLocaleString());
  });
  $('#goback').attr('href', portal);
  $('body').on('click', '.btn-success', function() {
    return viewNotif($(this).attr('notif'), $(this).attr('epoch'), $(this));
  });
  $('body').on('click', '.btn-danger', function() {
    return toggle($(this));
  });
  return $('body').on('click', '.btn-info', function() {
    return toggle_explorer($('#explorer').is(':visible'));
  });
});