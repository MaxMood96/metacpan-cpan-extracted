bless( {
  "rules" => [
    bless( {
      "selector" => [
        "\@charset \"UTF-8\""
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@import url(\"theme.css\")"
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@namespace svg url(\"http://www.w3.org/2000/svg\")"
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@font-face"
      ],
      "style" => "{ font-family: \"GnarlyFont\"; src: url(\"gnarly.woff2\") format(\"woff2\"); }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@counter-style funky-counter"
      ],
      "style" => "{ system: cyclic; symbols: \"\342\234\277\" \"\342\235\200\" \"\342\234\276\"; suffix: \" \"; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@property --main-color"
      ],
      "style" => "{ syntax: \"<color>\"; initial-value: #ff00ff; inherits: true; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@media (max-width: 1200px)",
        "(orientation: portrait)"
      ],
      "style" => [
        bless( {
          "selector" => [
            "body"
          ],
          "style" => "{ font-size: 16px; }"
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            "\@supports (display: grid)"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".grid-container",
                ".wrapper"
              ],
              "style" => "{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            "\@layer components"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".card",
                ".panel"
              ],
              "style" => "{ border-radius: 0.5rem; padding: 1rem; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            "\@scope (.dialog)"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".header",
                ".footer"
              ],
              "style" => "{ background: rgba(0,0,0,0.05); }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@layer utilities"
      ],
      "style" => [
        bless( {
          "selector" => [
            ".clearfix::after"
          ],
          "style" => "{ content: \"\"; display: table; clear: both; }"
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@scope (.modal)"
      ],
      "style" => [
        bless( {
          "selector" => [
            ".close-button"
          ],
          "style" => "{ cursor: pointer; }"
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@media (min-width: 800px)"
      ],
      "style" => [
        bless( {
          "selector" => [
            "\@supports (display: flex)"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".flex-container"
              ],
              "style" => "{ display: flex; flex-wrap: wrap; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            "\@layer layout"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".sidebar",
                ".content"
              ],
              "style" => "{ float: left; width: 50%; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "ul#menu li:first-child > a:hover",
        "ul#menu li:last-child > a:active",
        "#footer",
        ".footer p:nth-of-type(2)"
      ],
      "style" => "{ color: hotpink !important; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "div",
        "span",
        "a"
      ],
      "style" => "{ margin:0  ; padding:0; }"
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )