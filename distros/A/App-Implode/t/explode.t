use strict;
use warnings;
use Test::More;

my $script = 'bin/implode';
plan skip_all => "Cannot test without $script" unless -x $script;

$script = do $script or die "do $script: $@";
$script = bless {verbose => $ENV{HARNESS_IS_VERBOSE}}, $script;

ok !$App::implode::explodedir, 'no explodedir';
$script->exploder('test-mjaaccp1379132vhgv3');
my $dir = $App::implode::explodedir ? $$App::implode::explodedir : '/tmp/no-such-exploder-explodedir';
ok -d $dir, "got $dir";
ok -e "$dir/bin/implode", "got $dir/bin/implode";
ok -x "$dir/bin/implode", "can execute $dir/bin/implode";
like $ENV{PATH},     qr{^$dir/bin:},       'PATH';
like $ENV{PERL5LIB}, qr{^$dir/lib/perl5:}, 'PERL5LIB';

undef $App::implode::explodedir;
ok !-d $dir, "remove_tree $dir";

done_testing;

__END__
BZh91AY&SY���� �������������������c����w��=v��w� ��f  � �        ҦeOT3L"a�P0a4A�h�
�m�i�� F��OD���Sj����?TѦ14z��4�1I��&  �1M2`&    4bdɓ��`4�00L��4��  �A� � d� 2 ɦF�24  4 �4i�C��MQ頌      ��      ` &04��  �4��  �A� � d� 2 ɦF�24  4 �4i�C��@&M�C"���?�bLɥ6O*��=M�h��dA�=@� �� �z�CCO�]�z`�95�=���>�F�Ԃ����e�1��*���u��l��v8�Iх��L��t�1v�V��Q���1�k8���0�"1�,H���R!VT��P�T��A<,�E���{
F�e��Ԅ�cs��JV�A*�A!�51����@ӂtt�O�:$��v�����P��D�L�(��<�X�P���J���zD��8�3��D�Mq!��9�<��,�s�,H�Nd)kr��5ȹR�c�)��c��H�QU�Z�R)K(��K�)RR��ƥ�TU��E����0��J����0�k���ة��fQ))�h���-*)e����UJ��"�HsRI�ԉC��V�}O�}������ y��&̀� @ `u}��-�|Iv���i�;�;l�}�[� `"�\�%h �5H���&�~�wo9T�~�][C,�&�h���mv�Hm���H�ZߵN���@�fIC���E����� B���M�IK)�eD�)*��J%��T�J"~h��)y��NBtJP\����UF�u�ͮ��,�=c�;�u^${�BR]�<����s���YD�d�jv'5V�|S��0������>�#_����`>��+m���#�i�)����'�V�e&��K�9u.�u�!�Ve�a<��M	��z'�6����f�����p�f� �"�*�vjCܕ$���X��X����.�u����(��R�T�����"T���A   ��(��%=<ML    "@ @ @ A	����UURQ�f>�)C�T���C���ج��S�?A��6>c4�*e'e����ɠ��2T�)�K�,Һ��(�0M�
]b�9Vb��4��Y��CЉ�`�h�*�%�Z�y�k`��&����SK�"���d������3�O���]�}Nv���'�].Ѹ�4��5�����Q�N&�޳s�
�8�ɉ9T��C;0�	c���3����)�uML"�T���(������c�S%уK����J��b���UR~l��>��C[�i̳a��7S�r��9fa�T,��;Qwu��d�?-�5
q:f��hK7��:Z\L!��p�R�h����h��z��S��IK�j
l��l�foMc�nz	���d��V���M�i�1��C��Uf�fS�����ms�Z�L�S�Ƴ��|{��q6�lS�l�5Ζ�R��?V�0���b�znol�<i����&�h���렙�z���y�Qj�c�SsȺ�k��L!RE(~J��),�d�K�}u�?E�$]�g2�TJ�kT%�R�hQ��T��JG�L�%Sʦٹ�q�s��6�o��C��L5�)���SF��c#����o'`��9i_h]w�iY�1x�<��ae���C'��hjjS�3#�d�1jn����e|�Z�G:哢����'ؚ���EXj�r7�&0#ⶭ���w�+�&5*p�V�iӆ�3���5���o�oS��1Qg;������q���&ɾ`x٣�3��Q��r˪q7�r�̓z���Tާ�J�c,�����J�)�Y�L�.�`R�T���*;ҡ��������s���nWp��'TȻ�̺�E���ySA�����i��̻�g$���9�S�[��N<�ÝRc���k<1O�ZY8���j=&���{I��#�GӭS)gؔ�wL8�e�L�̱���Tr[M��׎Uӊ�fb�t�[�vf��ˬ��LW��������y�Juc�k�H����DfNМ�N��D���nz.+��o;��}��h.r��W�S-��|+mhZ�>�/�[~loi�F(ծ���J�JZ'�1��֡�	ȁ)�� �����sf<n�AauJKJb9����9!�T�TT�uӚ$�{�P�]$>IԷ�s1�z\�A����p��Ϣ����/�yR^d�XğY�,��I��*�L�Iw�F����$�FI�6���OY�%�a?R��|���{)���i|9'�-}����i�>���S�ML�D�b��f���zɘ��������s�0{�,S{�F��Ac23�����I�&�L���S�JTޗ�.�����t&��)��s5!���d��j���]��B|�f��gvYt충��t��ptM�k��~Ԏd�S���58�Y���˴�Y���ӝ����S��L̓���34��#�����LM��s�����h��ο)�4�	���R�S���-�]���l�W��
��Ȟf֦�����S�m{���&�����֜�=XT����;���9�R�旤m|	�gp�h��S2R�r}���:�>I��3�#cƖfP��O���J'�
珻����|��g4�I<�B����mDa5�����*`�L!Ψ�4H������5�;\�Ҥ�E*}���s�
���}��5L^����׈XZS��u.��w���,d��8���4��K�h��F�g�dS%�e܌�#;['qy���.��O:ӭg1����f���)d�2��2de
�5�n�`�&/m,Ԕ��J�e8�,���H�{,�pdFt�Sֆ�'#�,�Լ^Yfv�*`�R�L�l!��)�͋�S�)�Ƒ��c6:�jR��R��٪��)E/0�*�TŤ�2�*�-,�)>j�k��RaL�T��s�iC|LS&ɡv+<ld�˳��VN"I8�'���ɮ�q6�+k{J��UR����(�P��0�M*�L�Mk!�I�	7Gi����Z`���ͪN8��jQ�R0��Z&i]q���)R�R�)yyx֚�&�$��}.�jS��0�F��,�S�{I(\�}���#�Ύ�F�;�I�R�����)��K7�N��]�/<I�I��*��+r8L|�Rs����(��Fh��GY�O��
a�<S��#�����S���h�]��Nu䴰���!ƨ)*DR���E�b:*u�I�lO�<J�晨��I��lllu�ӷ�-�ἳY���31N�����\�4"JJ�/&�ę��i*Za�n�y �ZR�aF!x^T��܍
J�ҒfZE-
8I5�F�+!5�F/'�S��T�&i�5Dh��X�B|SK�4N���ٓ�S�T���I%�T���%��,�
CK�Y���3�D��u��]��p�Q�K���\�xǱ=���M�'ǉ�#�䞂��n��ydN��D�q��،dĠ��Q�[$�z�Ŧ+)f�%�Z�i{�Uk�YD��J�eE��t�KH�]f
���^�Wx˖;lN�ɲb5':���0x̞��g�?d�׃�#�8���J�IQ�ڑqyt0Sp����I�N^I%��]��^g�L�n��)s���rK��}���Jy'��<a��$�$��(s9&rM�/B�Ш���iY�tQ���,  �S�Zٱ���w�8/;��30�l��1R��.2��T���]�{�I�6��RNEL�,��0K<,����T�Jb�#�}B�lk��xY;����������s�
�J���T��2$wI�I���Ǚ�ܞێg�R&sa�C�w��UUUUUUUUUUUU]��ϙ���h�E���1�G���>Q�JG��X�SI�<��TC�O2D\藞��v�r��>iRk��!��&Լ�%LeEI,����
-N'S��>t�=���z��O	w�ib��]�q�Ҕ�u05ѷ%��°����"{��UJ�C���H�
�X 
