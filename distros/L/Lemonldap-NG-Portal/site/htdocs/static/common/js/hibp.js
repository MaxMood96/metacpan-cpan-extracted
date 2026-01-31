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

  $(document).on('checkpassword', function (event, context) {
    var evType, newpasswordVal, setResult;
    context.password;
    evType = context.evType;
    setResult = context.setResult;
    // if checkHIBP is enabled
    if ($('#ppolicy-checkhibp-feedback').length > 0) {
      newpasswordVal = $("#newpassword").val();
      if (newpasswordVal.length >= 5) {
        // don't check HIBP at each keyup, but only when input focuses out
        if (evType === "focusout") {
          setResult('ppolicy-checkhibp-feedback', "waiting");
          return $.ajax({
            dataType: "json",
            url: "".concat(scriptname, "checkhibp"),
            method: "POST",
            data: {
              "password": btoa(String.fromCharCode.apply(String, _toConsumableArray(new TextEncoder().encode(newpasswordVal))))
            },
            context: document.body,
            success: function success(data) {
              var code, msg;
              code = data.code;
              msg = data.message;
              if (code !== void 0) {
                if (parseInt(code) === 0) {
                  // password ok
                  return setResult('ppolicy-checkhibp-feedback', "good");
                } else if (parseInt(code) === 2) {
                  // password compromised
                  return setResult('ppolicy-checkhibp-feedback', "bad");
                } else {
                  // unexpected error
                  console.error('checkhibp: backend error: ', msg);
                  return setResult('ppolicy-checkhibp-feedback', "unknown");
                }
              }
            },
            error: function error(j, status, err) {
              var res;
              if (err) {
                console.error('checkhibp: frontend error: ', err);
              }
              if (j) {
                res = JSON.parse(j.responseText);
              }
              if (res && res.error) {
                console.error('checkhibp: returned error: ', res);
              }
            }
          });
        }
      } else {
        // Check not performed yet
        return setResult('ppolicy-checkhibp-feedback', "unknown");
      }
    }
  });

})();
