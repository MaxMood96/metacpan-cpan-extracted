use strict;
use warnings;
use Test2::V0;
use utf8;

plan 4;

use Net::Correios;

my $api = Net::Correios->new(
  username => 'foo',
  password => 'bar',
  cartao   => 1234,
  contrato => 4321
);

can_ok $api, 'sro';
ok my $ppn = $api->prepostagens, 'got the ppn object';
isa_ok $ppn, 'Net::Correios::Prepostagens';

# avoid making the token() request.
my $mocked_token = 'thisISaMOCk3dT0k3N.weUSE1tf0RtESt1nGTheACtu4lOn3ISmUChbiGG3R';
$api->{token_cartao} = $mocked_token;

subtest 'criar()' => sub {
    plan 5;
    can_ok $ppn, 'criar';    
    my $raw_response_data = {
      objetos => [
          {
        },
        {
            codObjeto => 'BB222222222BR',
            mensagem  => 'SRO-020: Objeto n�o encontrado na base de dados dos Correios.',
        },
      ],
    };
    my $mocked_ua = mock 'HTTP::Tiny' => (
      override => [
        request => sub {
          my ($self, $method, $url, $args) = @_;
          is $method, 'POST', 'proper criar method';
          is $url, 'https://api.correios.com.br/prepostagem/v1/prepostagens', 'proper ppn url';
          like $args, {
            headers => { Authorization => 'Bearer ' . $mocked_token },
            content => qr/\{.+\}/,
          }, 'proper header and some body';
          return { success => 1, content => JSON::encode_json($raw_response_data) };
        },
      ],
    );

    my $res = $ppn->criar({
        remetente     => {},
        destinatario  => {},
        codigoServico => '11111',
        listaServicoAdicional => [{
            codigoServicoAdicional => '019',
            valorDeclarado         => 11, # soh se o servico for v.d.
        }],
        itensDeclaracaoConteudo => {},
        emiteDCe => "S",
        pesoInformado => 300,
        codigoFormatoObjetoInformado => "2",
        alturaInformada         => 20,
        larguraInformada        => 20,
        comprimentoInformado    => 20,
        cienteObjetoNaoProibido => "1",
        modalidadePagamento     => "2", # a faturar
        logisticaReversa        => "N",
    });
    is $res, $raw_response_data, 'properly decoded data from API';
};