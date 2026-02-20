bless( {
  "rules" => [
    bless( {
      "selector" => [
        "html",
        "body"
      ],
      "style" => "{ margin: 0; padding: 0; font-family: \"Segoe UI\", Arial, sans-serif; background: #f9fafb; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".container"
      ],
      "style" => "{ display: grid; grid-template-columns: 240px 1fr; min-height: 100vh; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".sidebar"
      ],
      "style" => "{ background: #1a202c; color: #fff; padding: 1rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".sidebar ul"
      ],
      "style" => "{ list-style: none; margin: 0; padding: 0; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".sidebar li + li"
      ],
      "style" => "{ margin-top: 0.5rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".sidebar a"
      ],
      "style" => "{ color: inherit; text-decoration: none; padding: 0.5rem 0.75rem; display: block; border-radius: 0.25rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".sidebar a:hover",
        ".sidebar a:focus"
      ],
      "style" => "{ background: #2d3748; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".main"
      ],
      "style" => "{ padding: 2rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".main h1"
      ],
      "style" => "{ font-size: 2rem; margin-bottom: 1rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".main p"
      ],
      "style" => "{ margin-bottom: 1rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".card"
      ],
      "style" => "{ background: #fff; border: 1px solid #e2e8f0; border-radius: 0.5rem; box-shadow: 0 2px 6px rgba(0,0,0,0.05); padding: 1.25rem; margin-bottom: 1.5rem; transition: transform 0.2s ease, box-shadow 0.2s ease; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".card:hover"
      ],
      "style" => "{ transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".card h2"
      ],
      "style" => "{ font-size: 1.25rem; margin-top: 0; margin-bottom: 0.75rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".card p"
      ],
      "style" => "{ margin: 0; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button"
      ],
      "style" => "{ display: inline-block; padding: 0.5rem 1rem; font-size: 0.95rem; border-radius: 0.375rem; cursor: pointer; text-align: center; text-decoration: none; transition: background-color 0.2s ease, color 0.2s ease; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button.primary"
      ],
      "style" => "{ background: #3182ce; color: #fff; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button.primary:hover"
      ],
      "style" => "{ background: #2b6cb0; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button.secondary"
      ],
      "style" => "{ background: #e2e8f0; color: #2d3748; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        ".button.secondary:hover"
      ],
      "style" => "{ background: #cbd5e0; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "input[type=\"text\"]",
        "textarea"
      ],
      "style" => "{ width: 100%; padding: 0.5rem; border: 1px solid #cbd5e0; border-radius: 0.375rem; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "input[type=\"text\"]:focus",
        "textarea:focus"
      ],
      "style" => "{ border-color: #3182ce; outline: none; box-shadow: 0 0 0 2px rgba(49,130,206,0.25); }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "blockquote"
      ],
      "style" => "{ position: relative; padding-left: 1.5rem; color: #555; font-style: italic; }"
    }, 'Sumi::CSS::Rule' ),
    bless( {
      "selector" => [
        "blockquote::before"
      ],
      "style" => "{ content: \"\342\200\234\"; position: absolute; left: 0; top: -0.25rem; font-size: 2rem; color: #ccc; }"
    }, 'Sumi::CSS::Rule' )
  ]
}, 'Sumi::CSS' )