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
        "h1",
        "h2"
      ],
      "style" => "{ color: teal; font-weight: bold; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "p"
      ],
      "style" => "{ line-height: 1.5; color: #333; }"
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
            "h1",
            "h2"
          ],
          "style" => "{ color: darkcyan; }"
        }, 'Sumi::CSS::Rule' ),
        bless( {
          "selector" => [
            ".container"
          ],
          "style" => "{ padding: 10px; }"
        }, 'Sumi::CSS::Rule' )
      ]
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )