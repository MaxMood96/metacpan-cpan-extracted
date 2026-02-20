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
        "\@import url(\"other.css\")"
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
      "style" => "{ font-family: X; src: url(x.woff); }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@counter-style fancy"
      ],
      "style" => "{ system: fixed; symbols: A B C; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "\@property --main-color"
      ],
      "style" => "{ syntax: \"<color>\"; initial-value: red; inherits: false; }"
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )