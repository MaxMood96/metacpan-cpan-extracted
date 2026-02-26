IBGE-Municipios
===============

Este módulo oferece uma interface simples para obtenção do código IBGE
de municípios brasileiros, necessários para a criação de notas fiscais
eletrônicas (NF-e). Os dados foram extraídos do
[site oficial do IBGE](https://www.ibge.gov.br/explica/codigos-dos-municipios.php).


Instalação:
-----------

    cpanm IBGE::Municipios

Uso:
----

```perl

    use IBGE::Municipios;

    my $codigo = IBGE::Municipios::codigo( 'Castanheiras', 'RO' );

    say $codigo; # 1100908
```

