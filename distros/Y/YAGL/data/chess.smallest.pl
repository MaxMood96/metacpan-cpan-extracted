my @items = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z/;

my @options = qw/acegikmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmoqsuxy
  acegilmpqsuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqsuxy
  acegikmoqtuxy
  acegikmoqtuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegikmpqsuxy
  acegilmpqsuxy
  acegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegilmpqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmpqsuxy
  adegikmoqsuxy
  acegikmoqsuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmpqsuwy
  acegikmoqsuxy
  acegilmoqsuxy
  acegilmpqsuxy
  acegilmoqsuxy
  acegilmpqsuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acegikmpqtuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acegikmoqsuxy
  acegilmprtuwy
  acegilmprtuxy
  acegilmprtuxy
  acegikmprtuxy
  acegikmprtuxy
  acegilmprtuwy
  acegikmprtuxy
  acegikmprtuxy
  acegiknoqsuwy
  acegilnoqsuwy
  acegjlnoqsuwy
  acegilnpqsuwy
  acegiknoqsuwy
  acegilnpqtuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegiknoqsuwy
  acegiknoqsuxy
  acegjknoqsuxy
  acegiknpqsuxy
  acegilnpqsuxy
  acegiknoqtuxy
  acegiknoqtuxy
  acegilnpqtuxy
  acegiknpqsuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegiknpqsuxy
  acegilnpqsuxy
  acegiknoqtuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknpqsuxy
  acegilnpqsuxy
  acegiknoqsuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknpqtuxy
  adegilnoqsuxy
  adegiknpqsuxy
  adegilnpqtuxy
  adegiknpqsuxy
  adegiknoqsuxy
  adegiknoqsuxy
  adegiknoqsuxy
  adegiknpqsuxy
  adegiknoqsuxy
  adegiknpqsuxy
  adegilnpqsuxy
  acegiknoqsuwy
  acegjknoqsuwy
  acegjlnoqsuwy
  acegiknpqsuwy
  acegilnpqsuwy
  acegiknoqsuwy
  acehiknoqsuwy
  acegjlnoqsuwy
  acegiknoqsuwy
  acegilnpqsuxy
  acegjknoqsuxy
  acegilnpqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegilnpqsuxy
  acegiknpqsuxy
  adegilnoqsuxy
  acegilnprtuwy
  acegiknprtuwy
  acegiknprtuxy
  acegiknprtuxy
  acegiknprtuxy
  acegiknprtuxy
  adegilnprtuxy
  acegiknprtuxy
  acegikmoqsuwy
  acegilmpqsuwy
  acegilmoqtuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acegilmoqtuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acfgikmoqsuwy
  acegilmoqtuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmpqsuwy
  acegikmoqtuwy
  acegilmprtuwy
  acegilmprtuwy
  acegikmoqsuwy
  acegiknoqsuwy
  acegilnoqsuwy
  acegjlnoqsuwy
  acegilnpqsuwy
  acegilnoqsuwy
  acegiknoqtuwy
  acegjlnoqtuwy
  acegiknpqtuwy
  acegilnpqtuwy
  acfgiknoqsuwy
  acegilnpqsuwy
  acegilnpqtuwy
  acegiknoqsuwy
  acegjlnoqsuwy
  acegilnpqsuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegilnoqsuwy
  acegiknoqsuwy
  acegiknoqtuwy
  acegilnprtuwy
  acegilnprtuwy
  acegikmoqsuwy
  acegilmpqsuwy
  acegilmoqtuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acegilmoqtuwy
  acegikmoqsuxy
  acegjlmoqsuxy
  acegilmpqsuxy
  acegilmoqtuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acegilmoqtuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  acegilmprtuwy
  acegikmprtuxy
  acegikmprtuxy
  acegikmprtuxy
  acegiknoqsuwy
  acegjknoqsuwy
  acegilnoqsuwy
  acegjlnoqsuwy
  acegilnpqsuwy
  acegilnoqsuwy
  acegilnoqtuwy
  acegiknpqtuwy
  acegiknoqsuwy
  acehiknoqsuwy
  acegilnpqsuwy
  acegiknoqsuwy
  acegilnpqtuwy
  acegjknoqsuxy
  acegilnoqsuxy
  acegilnpqsuxy
  acegjknoqtuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknpqtuxy
  acegiknpqsuxy
  acegiknoqsuxy
  acegiknpqsuxy
  adegiknoqsuxy
  adegiknoqsuxy
  adegilnpqsuxy
  adegiknpqsuxy
  adegiknoqsuxy
  adegiknoqsuxy
  acegjlnoqsuwy
  acegjknoqsuxy
  acegilnprtuwy
  acegiknprtuwy
  acegilnprtuwy
  acegiknprtuxy
  acegiknprtuxy
  acegiknoqsuwy
  acegiknoqsuwy
  acegiknoqtuxy
  acegiknoqsuxy
  acegilmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmpqtuwy
  acegikmoqtuwy
  acegilmprtuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegilnoqsuwy
  acegjlnoqsuwy
  acegilnoqsuwy
  acegilnoqtuwy
  acegilnpqtuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegiknoqtuwy
  acegilnoqsuwy
  acegilnprtuwy
  acegilnprtuwy
  acegiknoqtuwy
  acegikmoqsuwz
  acegikmoqtuxz
  acegikmoqsuwz
  acegikmoqsuwz
  acegikmoqsuxz
  acegiknoqsuwz
  acegiknpqsuxz
  acegiknoqsuwz
  acegikmoqsuwz
  acegikmoqsuwz
  acegikmoqtuwz
  acegikmoqtuwz
  acegiknoqtuwz
  acegiknoqsuwz
  acegikmoqtuwz
  acegiknoqsuwz
  acegiknoqsuwz
  acegikmoqtuwz
  acegiknoqsuwz
  acegiknoqsuwz
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmprtuwy
  acegiknoqsuwy
  acegiknpqsuwy
  acegilnpqsuwy
  acegiknoqsuwy
  acegilnoqsuwy
  acegiknoqsuwy
  acehiknoqsuwy
  acegiknpqsuwy
  acegiknoqsuwy
  acegilnprtuwy
  acegiknprtuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmprtuwy
  acegiknoqsuwy
  acegjlnoqsuwy
  acegilnpqsuwy
  acegilnoqsuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegilnoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegilnprtuwy
  acegilmoqsuwy
  acegilmpqsuwy
  acegikmoqsuwy
  acfgikmoqsuwy
  acegilmprtuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegilnpqsuwy
  acehiknoqsuwy
  acegilnpqsuwy
  acegiknprtuwy
  acegiknprtuwy
  acegilmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegjknoqsuwy
  acegilnpqsuwy
  acegiknoqsuwy
  acegiknoqtuwy
  acegikmoqsuwz
  acegiknoqsuwz
  acegiknoqsuwz
  acegikmoqtuwz
  acegikmoqsuwz
  acegiknoqsuwz
  acegiknoqsuwz
  acegikmoqsuwz
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acegikmoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegjlnoqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegilmoqsuwy
  acegilmoqsuwy
  acegiknoqsuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegilnpqsuwy
  acegilnoqsuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegikmoqtuwz
  acegiknoqsuwz
  acegiknoqsuwz
  acegikmoqsuwz
  acegiknoqsuwz
  acegikmoqsuwz
  acegiknoqsuwz
  acegikmoqsuwz
  acegiknoqsuwz
  acegikmoqtuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acegikmoqsuwy
  acegiknoqtuwy
  acegiknoqtuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegikmoqsuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acegikmoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegiknoqsuwy
  acegilmoqsvwy
  acegikmoqsvxy
  acegikmoqsvxy
  acegilmoqsvwy
  acegilmoqsvxy
  acegjlnoqsvwy
  acegiknpqsvxy
  acegiknoqsvxy
  acegikmoqsvwy
  acegikmoqsvwy
  acegilmoqsvwy
  acegilmoqsvxy
  acegilmoqsvxy
  acegikmoqsvwy
  acegilnoqsvwy
  acegiknoqsvwy
  acegilnoqsvxy
  acegiknoqsvxy
  acegiknoqsvxy
  acegikmoqsvwy
  acegilmoqsvwy
  acegilnoqsvwy
  acegiknoqsvwy
  acegikmoqsvwz
  acegiknoqsvwz
  acegikmoqsvwy
  acegikmoqsvwy
  acegiknoqsvwy
  acegikmoqsvwy
  acegilmpqsvwy
  acegikmoqsvwy
  acegikmoqsvwy
  acegikmoqsvwy
  acegiknoqsvwy
  acegiknoqsvwy
  acegiknoqsvwy
  acegikmoqsvwy
  acegikmoqsvwz
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegilmoqtuwy
  bcegilmoqsuwy
  bcegikmoqtuwy
  bcegjlmoqsuxy
  bcegikmoqsuxy
  bcegilmpqsuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegilmpqsuxy
  bcegikmoqtuxy
  bcegilmoqtuxy
  bcegikmoqtuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegikmoqtuxy
  bcegikmoqtuxy
  bcegikmoqsuxy
  bcegilmoqsuxy
  bcegikmoqsuwy
  bcegjlmoqsuxy
  bcegikmoqsuxy
  bcegilmpqsuwy
  bcegikmoqsuxy
  bcegikmpqsuxy
  bcegilmpqsuxy
  bcegikmoqsuxy
  bcegikmpqsuxy
  bcegikmpqsuxy
  bcegikmoqsuxy
  bcegilmpqsuxy
  bcegikmoqsuxy
  bcegikmprtuxy
  bcegikmprtuxy
  bcegilmprtuxy
  bcegilmprtuxy
  bcegilmprtuwy
  bcegikmprtuxy
  bcegikmoqsuxy
  bcegiknoqsuwy
  bcegiknoqsuwy
  bcegiknoqsuxy
  bcegiknpqsuxy
  bcegiknpqsuxy
  bcegiknoqsuxy
  bdegiknoqsuxy
  bcegjknoqsuwy
  bcegjknoqsuwy
  bcegilnpqsuwy
  bcegiknpqsuxy
  bcegilnprtuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegiknoqsuwy
  bcegiknoqsuwy
  bcegilnpqsuwy
  bcegiknpqsuwy
  bcegiknoqtuwy
  bcegiknoqsuwy
  bcegiknoqtuwy
  bcegiknoqsuwy
  bcegiknprtuwy
  bcegilnprtuwy
  bcegilnprtuwy
  bcegilmoqsuwy
  bcegikmoqtuwy
  bcegilmoqsuwy
  bcegikmoqsuwy
  bcegikmoqtuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegikmoqsuxy
  bcegjlmoqsuxy
  bcegilmpqsuxy
  bcegilmoqtuxy
  bcegilmoqsuxy
  bcegilmpqsuxy
  bcegilmoqtuxy
  bcegilmoqsuxy
  bcegilmoqsuxy
  bcegikmoqsuwy
  bcegilmoqsuxy
  bdegikmoqsuwy
  bcegilmprtuwy
  bcegilmprtuxy
  bcegikmoqsuwy
  bcegikmoqtuwy
  bcegikmoqtuwy
  bcegikmoqtuxy
  bcegiknoqsuwy
  bcegjlnoqsuwy
  bcegiknoqtuwy
  bcegiknoqsuwy
  bcegjknoqsuwy
  bcegilnpqsuwy
  bcegilnprtuwy
  bcegiknprtuwy
  bcegiknoqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegilmprtuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegjknoqsuwy
  bcegilnpqsuwy
  bcegilnpqtuwy
  bcehiknoqsuwy
  bcegiknoqsuwy
  bcegiknoqtuwy
  bcegiknoqsuwy
  bcegiknoqsuwz
  bcegikmoqtuwz
  bcegiknoqsuwz
  bcegikmoqsuwz
  bcegikmoqsuwz
  bcegiknoqsuwz
  bcegiknoqsuwz
  bcegikmoqsuwz
  bcegiknoqsuwz
  bcegikmoqtuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegjlnoqsuwy
  bcegilnpqtuwy
  bcegiknpqsuwy
  bcegiknprtuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegilmoqtuwy
  bcegikmoqsuwy
  bcegilmoqtuwy
  bcegikmoqtuwy
  bcegikmoqsuwy
  bcegiknoqsuwy
  bcegilnpqsuwy
  bcegiknoqsuwy
  bcegilnpqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegiknoqsuwy
  bcegilnpqsuwy
  bcegiknoqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegikmoqsuwy
  bcegiknoqsuwy
  bcegilnpqsuwy
  bcegiknoqsuwy
  bcegikmoqtuwz
  bcegikmoqsuwz
  bcegikmoqsuwz
  bcegiknoqsuwz
  bcegikmoqsvwy
  bcegilmpqsvwy
  bcegilmpqsvwy
  bcegikmoqsvwy
  bcegikmoqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegilmpqsvxy
  bcegikmoqsvxy
  bcegikmoqsvwy
  bcegikmpqsvwy
  bcegikmpqsvwy
  bcegikmoqsvxy
  bcegikmpqsvxy
  bcegilmpqsvxy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcfgikmoqsvwy
  bcfgikmoqsvwy
  bcfgikmoqsvxy
  bcfgikmoqsvxy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegilmprtvxy
  bcegikmprtvxy
  bcegikmprtvxy
  bcegikmoqsvwy
  bcegiknoqsvwy
  bcegiknpqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegjknoqsvwy
  bcegilnpqsvwy
  bcegiknoqsvwy
  bcegiknoqsvxy
  bcegilnpqsvxy
  bcehiknpqsvxy
  bcegiknpqsvxy
  bcegiknoqsvxy
  bcegiknpqsvxy
  bcegiknoqsvxy
  bcegiknoqsvxy
  bcegiknpqsvxy
  bcegiknoqsvxy
  bcegiknpqsvxy
  bcegilnpqsvxy
  bcfgiknoqsvwy
  bcfgiknoqsvwy
  bcfgiknoqsvxy
  bcegiknpqsvxy
  bcegilnortvwy
  bcegilnprtvwy
  bcegiknprtvwy
  bcegiknortvxy
  bcegilnortvxy
  bcegiknortvxy
  bcegiknortvxy
  bcegiknprtvxy
  bcegiknortvxy
  bcegiknortvxy
  bcegiknprtvxy
  bcegiknortvwy
  bcegilnortvwy
  bcegilnortvxy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcfgikmoqsvwy
  bcegikmprtvwy
  bcegiknoqsvwy
  bcegiknoqsvwy
  bcfgiknoqsvwy
  bcegilnortvwy
  bcegilnortvwy
  bcegiknortvwy
  bcegiknortvwy
  bcegilmpqsvwy
  bcegilmpqsvwy
  bcegikmoqsvwy
  bcegjlmoqsvxy
  bcegilmpqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegikmoqsvwy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegilmpqsvxy
  bcegikmpqsvxy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegilmprtvxy
  bcegilmprtvxy
  bcegikmoqsvxy
  bcegiknpqsvwy
  bcegiknoqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegiknoqsvxy
  bcegilnpqsvxy
  bcegiknpqsvxy
  bcegiknoqsvxy
  bcegiknpqsvxy
  bcegilnpqsvxy
  bcegjknoqsvxy
  bcegilnpqsvxy
  bcegiknpqsvxy
  bcegiknoqsvxy
  bcegiknoqsvxy
  bcegilnortvwy
  bcegilnprtvwy
  bcegilnortvwy
  bcegiknortvxy
  bcegilnprtvxy
  bcegiknprtvxy
  bcegiknortvxy
  bcegiknoqsvwy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegilmprtvwy
  bcegiknoqsvwy
  bcegiknoqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegjknoqsvwy
  bcegilnortvwy
  bcegiknoqsvwy
  bcegikmoqsvwz
  bcegikmoqsvwz
  bcegiknoqsvwz
  bcegikmoqsvwz
  bcegikmoqsvwz
  bcegikmoqsvwz
  bcegiknoqsvwz
  bcegiknoqsvwz
  bcegikmoqsvwz
  bcegiknoqsvwz
  bcegiknoqsvwz
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegiknoqsvwy
  bcegiknprtvwy
  bcegikmoqsvwy
  bcegilmpqsvwy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegikmoqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegiknortvwy
  bcegiknortvwy
  bcegilmpqsvwy
  bcegiknoqsvwy
  bcegilnpqsvwy
  bcegiknortvwy
  bcegiknortvwy
  bcegilmpqsvwy
  bcegikmoqsvwy
  bcegiknoqsvwy
  bcegiknoqsvwy
  bcegikmoqsvwz
  bcegiknoqsvwz
  bcegikmoqsvwz
  bcegikmoqsvwz
  bcegikmoqsvwz
  adegikmoqsuxy
  adfgikmoqsuxy
  adegilmoqtuxy
  adegikmoqsuxy
  adegjlmoqsuxy
  adegilmoqtuxy
  adegjlmoqsuxy
  adfgikmoqsuxy
  adegilmprtuxy
  acegikmoqsuxy
  acegilnpqtuxy
  adegjknoqsuxy
  adehilnpqsuxy
  adegilnpqtuxy
  adegilnoqsuxy
  adegilnpqtuxy
  adegilnpqtuxy
  acegilnprtuxy
  acegjknprtuxy
  acegjlnprtuwy
  adegilnprtuxy
  adegilnprtuxy
  adegilnprtuxy
  adegilnprtuxy
  acegilnprtuwy
  acegiknoqsuxy
  acegilmprtuwy
  acegikmoqsuwy
  acegikmoqtuwy
  acegjlnoqtuwy
  acegjlnprtuwy
  acegilnprtuwy
  acegikmoqsuxy
  acegikmoqtuxy
  acegilmpqsuxy
  acegilmoqtuxy
  adegilmoqtuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  adegikmoqsuxy
  acegikmoqsuxy
  acfgikmoqsuxy
  acegikmoqsuxy
  acegilmpqsuxy
  acfgikmoqsuxy
  acfgikmoqsuxy
  acegilmpqsuxy
  acfgikmoqsuwy
  acegikmoqsuxy
  acegikmoqsuxy
  acegikmoqtuxy
  acegikmpqtuxy
  acegilmpqsuxy
  acegikmoqtuxy
  acegjlmoqtuxy
  adegjlmoqsuxy
  adegilmoqtuxy
  adfgikmoqsuxy
  acegikmoqsuxy
  acegikmprtuxy
  acegikmprtuxy
  acegikmprtuxy
  adegilmprtuxy
  adegikmprtuxy
  acegikmprtuxy
  acegikmprtuxy
  acegikmprtuxy
  acegikmoqsuxy
  adegikmoqsuxy
  acegiknoqsuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acfgiknoqsuxy
  acegiknpqsuxy
  acegiknpqtuxy
  acegiknoqtuxy
  acegjknoqsuxy
  acegilnpqsuxy
  acegiknoqtuxy
  acegiknpqtuxy
  acegilnpqtuxy
  adfgjknoqsuxy
  adegilnoqtuxy
  adfgjknoqsuxy
  adegilnpqtuxy
  adegiknoqsuxy
  adegiknoqsuxy
  adegilnpqtuxy
  adfgjknoqsuxy
  adegilnpqtuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknpqsuxy
  acfgiknoqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknpqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acegiknoqtuxy
  acegiknpqtuxy
  acegiknoqsuxy
  acegiknoqtuxy
  acegiknpqtuxy
  adegilnoqsuxy
  acegiknprtuxy
  acegiknprtuxy
  acegiknprtuxy
  acegiknprtuxy
  acegjknprtuxy
  acegjknprtuxy
  adegjknprtuxy
  adegilnprtuxy
  adegilnprtuxy
  adegjknprtuxy
  adegilnprtuxy
  acegiknprtuxy
  acegiknprtuxy
  acegjknprtuxy
  acegjknprtuxy
  adegilnprtuxy
  adegilnprtuxy
  adegilnprtuxy
  adegiknoqsuxy
  acegilmprtuwy
  acfhiknoqsuwy
  acegjlnoqtuwy
  acegilnprtuwy
  acegikmoqsuxz
  acegiknpqsuxz
  acegiknpqtuxz
  acegikmoqtuxz
  adegikmoqsuxz
  acegikmoqsuxz
  acegikmprtuxz
  adegikmprtuxz
  acegikmoqsuxz
  acegikmoqsuxz
  acegikmoqtuxz
  acegikmoqsuxz
  acegikmoqtuxz
  acegikmoqtuxz
  adegiknpqsuxz
  acegiknpqsuxz
  acegiknpqtuxz
  acegiknpqtuxz
  acegiknpqtuxz
  acegiknpqtuxz
  acegiknpqsuxz
  acehilnpqsuwy
  acfgiknoqsuwy
  acegjlnprtuwy
  acegilmoqtuwy
  acegikmpqtuwy
  acegilmprtuwy
  acegilmprtuwy
  acegikmoqsuwy
  acehiknoqsuwy
  acehilnpqsuwy
  acegjlnoqsuwy
  acegjlnoqsuwy
  acegjlnprtuwy
  acegjlnprtuwy
  acegjlnprtuwy
  acegilnprtuwy
  acegikmoqsuwy
  acegilmprtuwy
  acfhiknoqsuwy
  acehiknpqsuwy
  acfgjknoqsuwy
  acehiknoqsuwy
  acegjlnoqsuwy
  acegiknoqtuwy
  acegilnpqtuwy
  acegilnprtuwy
  acegilnprtuwy
  acegilnprtuwy
  acegikmoqtuwz
  acegikmoqsuwz
  acegilmoqsuwz
  acegikmoqtuwz
  acegiknoqtuwz
  acegikmoqsvxy
  acegilmprtvxy
  acegikmoqsvxy
  acegikmoqsvwy
  acegjlnoqsvwy
  acegilnprtvxy
  acegiknoqsvwy
  acegjlnoqsvwy
  acegikmoqsvxy
  acegikmoqsvxy
  acegikmoqsvxy
  acegikmoqsvxy
  acegikmoqsvxy
  acegikmoqsvxy
  acegikmoqsvxy
  acegilmpqsvxy
  acfgikmoqsvxy
  acegikmoqsvwy
  acegjkmoqsvwy
  acegikmoqsvxy
  acegikmoqsvxy
  acfgikmoqsvxy
  acegikmprtvxy
  acegikmprtvwy
  adehikmprtvxy
  acegiknoqsvxy
  acegiknpqsvxy
  acegiknoqsvxy
  acegiknoqsvxy
  acegilnpqsvxy
  acegiknoqsvxy
  acegjknoqsvxy
  acfgiknoqsvxy
  acegiknoqsvxy
  acegjknoqsvxy
  acegjknprtvxy
  acegjknprtvxy
  acegikmoqsvxz
  acegiknoqsvwz
  acehikmpqsvwz
  acegjkmprtvwz
  acegiknpqsvxz
  acegikmoqsvwz
  acegilmoqsvwy
  acegilmoqsvwy
  acegikmoqsvwy
  acegilmprtvwy
  acegiknoqsvwy
  acegilnoqsvwy
  acegjlnoqsvwy
  acegjlnoqsvwy
  acegilnprtvwy
  acegjlnprtvwy
  acegilmoqsvwy
  acfgikmoqsvwy
  acegikmoqsvwy
  acegikmoqsvwy
  acegilmoqsvwy
  acehilmprtvwy
  acegilnpqsvwy
  acegiknoqsvwy
  acegiknoqsvwy
  acegjknoqsvwy
  acfgiknoqsvwy
  acegjlnoqsvwy
  acegiknoqsvwy
  acegjlnprtvwy
  acegikmoqsvwz
  acegikmoqsvwz
  acegikmoqsvwz
  acegikmoqsvwz
  acfgikmoqsvwz
  acegikmoqsvwz
  acegikmoqsvwz
  acegiknoqsvwz
  acegikmoqsuwy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqtuxy
  acegilmoqtuxy
  acegikmoqsuxy
  acegikmoqsuxy
  acegilmoqsuxy
  acegilmoqtuxy
  acfgikmoqtuxy
  acegikmoqtuxy
  acegikmoqsuxy
  acegilmoqsuxy
  acegilmoqsuxy
  acegikmoqsuxy
  acegilmoqsuxy
  acegilmoqsuxy
  acegikmoqtuxy
  acfgikmoqtuxy
  acfgikmoqtuxy
  acegikmoqtuxy
  acfgilmoqtuwy
  acfgilmoqtuwy
  acfgjkmoqtuwy
  acfgikmoqtuwy
  acfgilmoqtuwy
  acegikmoqsuxy
  acfgikmoqtuxy
  acfgikmoqtuxy
  acegikmoqsuxy
  acegjlmoqsuxy
  acegjlmoqsuxy
  acfgilmoqtuxy
  acfgikmoqtuxy
  acegiknoqtuxy
  acegiknoqtuxy
  acegiknoqtuxy
  acegiknoqtuxy
  adegilnoqtuxy
  adegilnoqtuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqsuxy
  acegiknoqtuxy
  acfgjknoqtuxy
  acegiknoqtuxy
  acegiknoqsuxy
  acegilnpqsuxy
  acfgjknoqtuxy
  acfgjknoqtuxy
  adegjknoqsuxy
  adegilnoqsuxy
  adehiknoqsuxy
  adegjknoqsuxy
  acegikmoqsuwy
  acegikmoqtuwy
  acfgikmoqtuwy
  acfgiknoqsuwy
  acegjlnoqsuwy
  acfgiknoqtuwy
  acfgiknoqtuwy
  acegikmoqsuwz
  acegikmoqtuwz
  acegikmoqtuwz
  acegikmoqsuwz
  acfgikmoqtuwz
  acegiknoqtuwz
  acegilmoqsuwy
  acegikmoqtuwy
  acegilmoqsuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acegikmoqtuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acegikmoqtuwy
  acfgilmoqtuwy
  acfgikmoqtuwy
  acfgikmoqsuwy
  acegilmoqsuwy
  acegikmoqsuwy
  acegilmoqsuwy
  acfgikmoqtuwy
  acfgikmoqtuwy
  acegikmoqtuwy
  acfgiknoqsuwy
  acegiknoqsuwy
  acegjknoqsuwy
  acehiknoqsuwy
  acegilnpqsuwy
  acegjknoqsuwy
  acegjlnoqsuwy
  acegiknoqsuwy
  acegilnpqsuwy
  acegjlnoqsuwy
  acfgiknoqtuwy
  acfgjlnoqtuwy
  acfgjlnoqtuwy
  acegiknoqtuwy
  acegikmoqsuwz
  acegikmoqtuwz
  acegiknoqsuwz
  acegikmoqsuwz
  acfgikmoqtuwz
  acegiknoqsuwz
  bcegikmoqsvwy
  bcegikmpqsvwy
  bcegikmoqsvxy
  bcegikmprtvxy
  bcegilmprtvxy
  bcegjlmprtvwy
  bcehilmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bdehilmprtvxy
  bdegilmprtvxy
  bdegjlmprtvxy
  bdegjkmprtvxy
  bdegilmprtvxy
  bdehikmprtvxy
  bdegikmprtvxy
  bdegilmprtvxy
  bdehikmprtvxy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcegikmoqsvwy
  bcegikmprtvwy
  bcehiknpqsvxy
  bcehilnpqsvxy
  bcegiknortvxy
  bcegiknprtvxy
  bcegjknprtvxy
  bcegjlnprtvwy
  bcegiknoqsvxy
  bcegiknoqsvwy
  bcehilmprtvwy
  bcehilmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bcegikmoqsvwy
  bcegilnortvwy
  bcegilnprtvwy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcfgikmoqsvwy
  bcfgikmoqsvwy
  bcfgikmoqsvxy
  bcegikmoqsvxy
  bcegikmoqsvxy
  bcfgikmoqsvxy
  bcegikmoqsvwy
  bcegikmpqsvwy
  bcegikmpqsvwy
  bcfgikmoqsvwy
  bcfgikmoqsvwy
  bcfgikmoqsvwy
  bcfgikmoqsvxy
  bcfgikmoqsvxy
  bcfgikmoqsvxy
  bcfgikmoqsvxy
  bcfgikmoqsvxy
  bcegikmprtvxy
  bcegikmprtvxy
  bcegilmprtvxy
  bcegikmprtvwy
  bcegilmprtvxy
  bcegilmprtvwy
  bdegjkmprtvxy
  bdegilmprtvxy
  bdegikmprtvxy
  bdegilmprtvxy
  bdegikmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegikmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegikmprtvxy
  bdegikmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegikmprtvxy
  bcehilmprtvwy
  bcehikmprtvwy
  bcegjlmprtvwy
  bdehilmprtvxy
  bdehikmprtvxy
  bdehikmprtvxy
  bdegjlmprtvxy
  bdegjlmprtvxy
  bdehikmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdegilmprtvxy
  bdehikmprtvxy
  bdegjlmprtvxy
  bdegjlmprtvxy
  bdegilmprtvxy
  bcegikmoqsvxy
  bcfgiknoqsvxy
  bcehiknpqsvxy
  bcegiknoqsvxy
  bcegiknoqsvxy
  bcegilnpqsvxy
  bcfgjknoqsvxy
  bcfgiknoqsvxy
  bcfgiknoqsvxy
  bcfgjknoqsvwy
  bcegiknortvxy
  bcegiknortvxy
  bcegiknprtvxy
  bcegiknortvxy
  bcegiknprtvxy
  bcegjknprtvwy
  bcegilnortvxy
  bcegilnortvxy
  bcegilnortvxy
  bcegjknprtvxy
  bcegjkmprtvwy
  bcegikmprtvwy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegjkmprtvwy
  bcegilmprtvwy
  bcfgjknoqsvwy
  bcegilnortvwy
  bcegikmoqsvxz
  bcegikmoqsvxz
  bcegikmprtvxz
  bcegiknpqsvxz
  bcfgikmoqsvwz
  bcegikmprtvxz
  bcegikmprtvxz
  bcegikmoqsvxz
  bcegikmprtvwz
  bcegiknpqsvxz
  bcegiknpqsvxz
  bcegiknpqsvxz
  bcfgikmoqsvwz
  bcegjkmprtvwy
  bcegjlmprtvwy
  bcegilmprtvwy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegilnortvwy
  bcegilmpqsvwy
  bcehilmprtvwy
  bcegjlmprtvwy
  bcegjlmprtvwy
  bcegilmprtvwy
  bcehjlmprtvwy
  bcegikmoqsvwy
  bcegjknoqsvwy
  bcehilnpqsvwy
  bcegiknortvwy
  bcegilnortvwy
  bcegikmprtvwy
  bcegikmprtvwy
  bcegjkmprtvwy
  bcegjlmprtvwy
  bcegilmprtvwy
  bcegilnortvwy
  bcfgikmoqsvwy
  bcfgikmoqsvwy
  bcegjkmprtvwy
  bcegilmprtvwy
  bcegikmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bcegilmprtvwy
  bcegjkmprtvwy
  bcegjlmprtvwy
  bcegjkmprtvwy
  bcegjlmprtvwy
  bcegilmprtvwy
  bcfgiknoqsvwy
  bcehiknpqsvwy
  bcfgiknoqsvwy
  bcfgiknoqsvwy
  bcegiknortvwy
  bcegilnortvwy
  bcegilnprtvwy
  bcegjknprtvwy
  bcegilnortvwy
  bcegiknoqsvwz
  bcfgikmoqsvwz
  bcegikmpqsvwy
  bcegikmpqsvwz
  bcegilmoqtuxy
  bcegilmoqtuxy
  bcegilmoqtuxy
  bcegikmoqsuwy
  bcegikmoqtuwy
  bcegikmpqtuwy
  bdegikmoqsuwy
  bdegikmoqsuwy
  bcegilmprtuxy
  bcegilmprtuxy
  bcegilmprtuxy
  bcegilmprtuwy
  bcegikmprtuwy
  bdehikmoqsuxy
  bdegjkmoqsuxy
  bdehikmoqsuxy
  bdegjkmoqsuxy
  bcehilnpqsuwy
  bdehiknoqsuxy
  bdehiknpqsuxy
  bdehiknpqsuxy
  bcegjlnprtuwy
  bdegjlnprtuxy
  bdegjlnprtuxy
  bcegikmoqtuwy
  bcegilmprtuwy
  bcehilnpqsuwy
  bcegjlnoqsuwy
  bcegilnprtuwy
  bcegilnprtuwy
  bcegilnprtuwy
  bcegilmoqtuxy
  bcegilmoqtuxy
  bcegilmoqtuwy
  bcfgikmoqsuwy
  bcegilmoqtuwy
  bcegikmoqsuxy
  bcegikmoqtuxy
  bcegikmoqsuxy
  bcfgikmoqsuxy
  bcfgikmoqsuxy
  bcegikmoqtuxy
  bcegilmoqtuwy
  bcfgikmoqsuwy
  bdfgikmoqsuwy
  bdegikmoqsuwy
  bdegikmpqsuwy
  bdegikmoqsuwy
  bdegilmoqtuwy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegikmoqsuxy
  bcegilmpqsuxy
  bcegikmoqsuxy
  bcegjlmoqsuxy
  bcfgikmoqsuwy
  bcfgikmoqsuwy
  bcegikmoqtuwy
  bcegikmoqtuwy
  bcegikmoqtuwy
  bdfgikmoqsuwy
  bdegilmoqtuwy
  bcegikmprtuxy
  bcegikmprtuxy
  bcegikmprtuxy
  bcegilmprtuxy
  bcegikmprtuxy
  bcegikmprtuwy
  bcegikmprtuwy
  bdfhikmoqsuwy
  bdfgjkmoqsuwy
  bcegiknpqsuxy
  bcegjknoqsuxy
  bcfgiknoqsuxy
  bcfgiknoqsuxy
  bcegjknoqsuxy
  bcegilnpqsuxy
  bcegilnpqsuxy
  bdegjknoqsuxy
  bdehiknpqsuxy
  bdegilnpqtuxy
  bdehiknoqsuxy
  bdegjknoqsuxy
  bcfgiknoqsuxy
  bcegiknoqsuxy
  bcegjknoqsuxy
  bcegiknpqsuxy
  bcegilnpqsuxy
  bcegilnpqsuxy
  bcegjknoqsuxy
  bcegiknpqtuxy
  bdehiknoqsuxy
  bdehiknpqsuxy
  bdehiknoqsuxy
  bdehiknpqsuxy
  bcegiknprtuxy
  bcegiknprtuxy
  bcegiknprtuxy
  bcegiknprtuxy
  bcegjlnprtuwy
  bdegilnprtuxy
  bcegiknprtuxy
  bcegjknprtuxy
  bcegjlnprtuwy
  bdegjlnprtuxy
  bdegjlnprtuxy
  bdegiknoqsuxy
  bcegilmprtuwy
  bcegilmprtuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegilnpqtuwy
  bcegilnprtuwy
  bcegilnprtuwy
  bcegikmoqsuxz
  bcegikmoqtuxz
  bcegikmprtuxz
  bcegikmprtuwz
  bcegikmoqtuwz
  bcegikmoqtuxz
  bcegikmoqsuxz
  bcegikmprtuxz
  bcegikmoqsuxz
  bcegikmoqtuxz
  bcegikmoqsuxz
  bcegikmprtuxz
  bcegikmprtuwz
  bcegikmprtuxz
  bdegjkmprtuwz
  bcegiknpqsuxz
  bcegilmprtuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegiknoqtuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegilnprtuwy
  bcegilnprtuwy
  bcegilmoqsuwy
  bcegikmoqtuwy
  bcegilmoqtuwy
  bcegikmpqtuwy
  bcegilmpqsuwy
  bcegilmoqtuwy
  bcegilmprtuwy
  bcegilmprtuwy
  bcegiknoqtuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegjlnoqtuwy
  bcegjlnoqtuwy
  bcegilnpqtuwy
  bcegjlnprtuwy
  bcegjlnprtuwy
  bcegjlnprtuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegilmprtuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegilnpqsuwy
  bcegilnprtuwy
  bcegikmoqsuwy
  bcfgikmoqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegikmoqtuwy
  bcegikmoqsuwy
  bcegikmoqsuwy
  bcegilmoqsuwy
  bcegilmpqsuwy
  bcegilmoqtuwy
  bcegilmprtuwy
  bcegilmprtuwy
  bcegikmoqsuwy
  bcegjlnoqsuwy
  bcegjlnoqsuwy
  bcegiknpqsuwy
  bcegjlnoqtuwy
  bcegilnpqtuwy
  bcfgiknoqsuwy
  bcegilnpqsuwy
  bcegiknoqtuwy
  bcegjlnoqsuwy
  bcegjlnoqtuwy
  bcegiknpqtuwy
  bcegilnprtuwy
  bcegiknprtuwy
  bcegilnprtuwy
  bcegiknprtuwy
  bcegjlnprtuwy
  bcegikmoqsuwz
  bcegikmoqtuwz
  bcegikmoqsuwz
  bcegikmoqtuwz
  bcegilmoqsuwz
  bcegikmoqtuwz
  bcegikmoqsuwz
  bcegiknoqtuwz
  bcegikmoqsuwy
  bcegikmpqsuwy
  bdegikmpqsuwy
  bcegikmoqsuwy
  bcegilmpqsuwy
  bcegjkmoqsuwy
  bcegikmpqsuwy
  bcegjkmoqsuwy
  bcegilmpqtuwy
  bcegjkmoqsuwy
  bcegikmprtuwy
  bcegikmpqsuwy
  bdegikmpqsuwy
  bdegikmpqsuwz
  bdegikmpqsuwz
  bdegilmpqtuwz
  bdegilmpqtuwz
  bcegjkmprtuwz
  bcegikmpqsuwz
  bdegikmpqsuwz
  bdehikmpqsuwz/;

return (\@items, \@options);
