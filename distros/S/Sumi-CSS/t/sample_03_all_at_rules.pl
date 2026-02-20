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
        "\@import url(\"theme.css\") screen and (min-width: 900px)"
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@namespace svg url(http://www.w3.org/2000/svg)"
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@import url(\"utilities.css\") layer(utilities)"
      ],
      "style" => undef
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@media (min-width: 600px) and (max-width: 1200px)"
      ],
      "style" => [
        bless( {
          "selector" => [
            "\@supports (display: flex)"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".container"
              ],
              "style" => "{ display: flex; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "body"
      ],
      "style" => "{ font-family: \"OpenSans\", sans-serif; margin: 0; padding: 0; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "h1"
      ],
      "style" => "{ color: teal; animation: slidein 2s ease-in-out; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".card"
      ],
      "style" => "{ padding: 1rem; border: 1px solid #ccc; border-radius: 0.5rem; }"
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )