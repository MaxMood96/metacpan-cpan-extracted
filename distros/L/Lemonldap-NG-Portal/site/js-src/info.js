// Timer for information page
var _go, go, i, stop, timer;

i = 30;

_go = 1;

stop = function() {
  _go = 0;
  $('#divToHide').hide();
  return $('#wait').hide();
};

go = function() {
  if (_go) {
    return $("#form").submit();
  }
};

timer = function() {
  var h;
  h = $('#timer').html();
  if (i > 0) {
    i--;
  }
  h = h.replace(/\d+/, i);
  $('#timer').html(h);
  return window.setTimeout(timer, 1000);
};

//$(document).ready ->
$(window).on('load', function() {
  if (window.datas['activeTimer']) {
    window.setTimeout(go, 30000);
    window.setTimeout(timer, 1000);
  }
  return $("#wait").on('click', function() {
    return stop();
  });
});
