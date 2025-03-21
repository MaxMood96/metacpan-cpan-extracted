#!inc/bin/testml-cpan

*toml.pegex-toml-load.yaml == *yaml
  :"+ - Load with Pegex::TOML"
*toml.toml-parse.yaml == *yaml-t
  :"+ - Load with TOML.pm"

# From https://raw.githubusercontent.com/toml-lang/toml/master/tests/example.toml

=== Test 1
--- toml(<)
    # This is a TOML document. Boom.

    title = "TOML Example"

    [owner]
    name = "Tom Preston-Werner"
    organization = "GitHub"
    bio = "GitHub Cofounder & CEO\nLikes tater tots and beer."

    [database]
    server = "192.168.1.1"
    ports = [ 8001, 8001, 8002 ]
    connection_max = 5000
    enabled = true

--- yaml(<)
    ---
    - - - title: TOML Example
    - - - owner
      - - name: Tom Preston-Werner
        - organization: GitHub
        - bio: GitHub Cofounder & CEO\nLikes tater tots and beer.
    - - - database
      - - server: 192.168.1.1
        - ports:
          - - '8001'
            - '8001'
            - '8002'
        - connection_max: '5000'
        - enabled: 'true'

--- yaml-t(<)
    ---
    database:
      connection_max: 5000
      enabled: 'true'
      ports:
      - 8001
      - 8001
      - 8002
      server: 192.168.1.1
    owner:
      bio: |-
        GitHub Cofounder & CEO
        Likes tater tots and beer.
      name: Tom Preston-Werner
      organization: GitHub
    title: TOML Example



=== Test 2
--- SKIP
--- toml
# This is a TOML document. Boom.

title = "TOML Example"

[owner]
name = "Tom Preston-Werner"
organization = "GitHub"
bio = "GitHub Cofounder & CEO\nLikes tater tots and beer."
dob = 1979-05-27T07:32:00Z # First class dates? Why not?

[database]
server = "192.168.1.1"
ports = [ 8001, 8001, 8002 ]
connection_max = 5000
enabled = true

[servers]

  # You can indent as you please. Tabs or spaces. TOML don't care.
  [servers.alpha]
  ip = "10.0.0.1"
  dc = "eqdc10"

  [servers.beta]
  ip = "10.0.0.2"
  dc = "eqdc10"
  country = "中国" # This should be parsed as UTF-8

[clients]
data = [ ["gamma", "delta"], [1, 2] ] # just an update to make sure parsers support it

# Line breaks are OK when inside arrays
hosts = [
  "alpha",
  "omega"
]

# Products

  [[products]]
  name = "Hammer"
  sku = 738594937

  [[products]]
  name = "Nail"
  sku = 284758393
  color = "gray"

--- yaml
