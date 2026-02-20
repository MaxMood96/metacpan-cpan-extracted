bless( {
  "rules" => [
    bless( {
      "selector" => [
        "body"
      ],
      "style" => "{ margin: 0; font-family: sans-serif; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button"
      ],
      "style" => "{ padding: 0.5rem 1rem; background: steelblue; color: white; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@media (max-width: 600px)"
      ],
      "style" => [
        bless( {
          "selector" => [
            "body"
          ],
          "style" => "{ font-size: 14px; }"
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            "\@supports (display: grid)"
          ],
          "style" => [
            bless( {
              "selector" => [
                ".grid"
              ],
              "style" => "{ display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }"
            }, 'Sumi::CSS::Rule' )
          ]
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )