(function () {
  'use strict';

  function _toConsumableArray(arr) {
    return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _unsupportedIterableToArray(arr) || _nonIterableSpread();
  }
  function _arrayWithoutHoles(arr) {
    if (Array.isArray(arr)) return _arrayLikeToArray(arr);
  }
  function _iterableToArray(iter) {
    if (typeof Symbol !== "undefined" && iter[Symbol.iterator] != null || iter["@@iterator"] != null) return Array.from(iter);
  }
  function _unsupportedIterableToArray(o, minLen) {
    if (!o) return;
    if (typeof o === "string") return _arrayLikeToArray(o, minLen);
    var n = Object.prototype.toString.call(o).slice(8, -1);
    if (n === "Object" && o.constructor) n = o.constructor.name;
    if (n === "Map" || n === "Set") return Array.from(o);
    if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen);
  }
  function _arrayLikeToArray(arr, len) {
    if (len == null || len > arr.length) len = arr.length;
    for (var i = 0, arr2 = new Array(len); i < len; i++) arr2[i] = arr[i];
    return arr2;
  }
  function _nonIterableSpread() {
    throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
  }

  var barWidth, bootstrapClasses, displayEntropyBar, displayEntropyBarMsg;
  bootstrapClasses = new Map([["Err", "bg-danger"], ["0", "bg-danger"], ["1", "bg-warning"], ["2", "bg-info"], ["3", "bg-primary"], ["4", "bg-success"]]);
  barWidth = new Map([["Err", "0"], ["0", "20"], ["1", "40"], ["2", "60"], ["3", "80"], ["4", "100"]]);

  // display entropy bar with correct level
  displayEntropyBar = function displayEntropyBar(level) {
    // Remove all classes from progressbar and restore default progress-bar class
    $("#entropybar div").removeClass();
    $("#entropybar div").addClass('progress-bar');
    // set width
    $("#entropybar div").width(barWidth.get(level) + '%');
    // set color
    $("#entropybar div").addClass(bootstrapClasses.get(level));
    // display percentage width inside the bar
    return $("#entropybar div").html(barWidth.get(level) + '%');
  };

  // display custom message if any, else remove hide div block
  displayEntropyBarMsg = function displayEntropyBarMsg(msg) {
    $("#entropybar-msg").html(msg);
    if (msg.length === 0) {
      return $("#entropybar-msg").addClass("entropyHidden");
    } else {
      return $("#entropybar-msg").removeClass("entropyHidden");
    }
  };
  $(document).on('checkpassword', function (event, context) {
    var entropyrequired, entropyrequiredlevel, newpasswordVal, setResult;
    context.password;
    context.evType;
    setResult = context.setResult;
    // if checkEntropy is enabled
    if ($('#ppolicy-checkentropy-feedback').length > 0) {
      newpasswordVal = $("#newpassword").val();
      entropyrequired = $("span[trspan='checkentropyLabel']").attr("data-checkentropy_required");
      entropyrequiredlevel = $("span[trspan='checkentropyLabel']").attr("data-checkentropy_required_level");
      if (newpasswordVal.length === 0) {
        // restore default empty bar
        displayEntropyBar("Err");
        displayEntropyBarMsg("");
        setResult('ppolicy-checkentropy-feedback', "unknown");
      }
      if (newpasswordVal.length > 0) {
        // send a request to checkentropy endpoint
        return $.ajax({
          dataType: "json",
          url: "".concat(scriptname, "checkentropy"),
          method: "POST",
          data: {
            "password": btoa(String.fromCharCode.apply(String, _toConsumableArray(new TextEncoder().encode(newpasswordVal))))
          },
          context: document.body,
          success: function success(data) {
            var level, msg;
            level = data.level;
            msg = data.message;
            if (level !== void 0) {
              if (parseInt(level) >= 0 && parseInt(level) <= 4) {
                // display entropy bar with correct level
                displayEntropyBar(level);
                displayEntropyBarMsg(msg);
                // set a warning if level < required level and prevent form validation
                if (entropyrequired === "1" && entropyrequiredlevel.length > 0) {
                  if (parseInt(level) >= parseInt(entropyrequiredlevel)) {
                    setResult('ppolicy-checkentropy-feedback', "good");
                  } else {
                    setResult('ppolicy-checkentropy-feedback', "bad");
                  }
                }
                // entropy criteria is set to ok if entropy check is not required
                if (entropyrequired !== "1") {
                  return setResult('ppolicy-checkentropy-feedback', "good");
                }
              } else if (parseInt(level) === -1) {
                // error when computing entropy: display entropy bar with error level
                displayEntropyBar(level);
                displayEntropyBarMsg(msg);
                return setResult('ppolicy-checkentropy-feedback', "bad");
              } else {
                // unexpected error: display entropy bar with error level
                displayEntropyBar(level);
                displayEntropyBarMsg(msg);
                return setResult('ppolicy-checkentropy-feedback', "unknown");
              }
            }
          },
          error: function error(j, status, err) {
            var res;
            if (err) {
              console.debug('checkentropy: frontend error: ', err);
            }
            if (j) {
              res = JSON.parse(j.responseText);
            }
            if (res && res.error) {
              console.debug('checkentropy: returned error: ', res);
            }
          }
        });
      }
    }
  });

})();
