#!/usr/bin/perl -w

use strict;

my $n;
use Test::More tests => ($n = 42) * 6 + 4;
use lib "t/lib";
use Test::FloatNear;

BEGIN { use_ok("MPEG::Audio::Frame") };

my $s = 0;
for (1 .. $n){
	isa_ok(my $frame = MPEG::Audio::Frame->read(*DATA), "MPEG::Audio::Frame", "frame $_");
	ok($frame->mpeg1, "MPEG1");
	ok($frame->layer3, "layer III");
	ok(!$frame->broken, "frame is not broken");
	is($frame->sample, 44100, "sample rate");
	is($frame->length, length("$frame"), "actual length eq calculated length");
	$s += $frame->seconds;
}

is_near($s, 1.09714285714, "total length");

is(MPEG::Audio::Frame->read(*DATA), undef, "nothing left on __DATA__");
ok(eof(DATA), "eof(DATA)")

__DATA__
��P�  
d�S�	 p�lO1�  
  ��`@(    /@pu� �Y���{>з���� bp���o�P��M����+�����7��.8��r��Ā 
  ����A{�U3[�k�U� *�T
xFDȶ:����۔�%���csiK�ŧ�nP���ZHc�hJ��0���5�J���P4%	EU��a������Y���R���t�R� 	Q+ �a)�$��Ic�V]�@H�k�6zx�*&#�	}5=�ΰ��K��g�b7K.v^��vE&c9ޣ���Tv��a:�X������dpTfT��$�7��� Fn\����2�Gi!�H���ܧ�6�C(gL�]-���cP�C3�&���Pf� B�zZ�V�"'etm���xv��i�
0�A��R��� �Lk)II�*B���#���ť�'�����|4���e�e�NM�N$�O��gqS��5��L@��ۻ����`l�4�d9��ov���0%�I���T	�D��XT���I��W��-_�j���:4��YG���6���$i�Q�U6��j����   n���ˈ��J���L�̼ص��aG����a��0�
��(��R�  �PY� ��3� �ا�e��=c*�`��WY�44���u��!�*���
3��"q
�.v�P���ݗ �� ���sMu>��7�ÅiR�T$n�#

"��7�zz]XSa���Qi��q��!�Ad�'[L�"_����%"
����v/��Rkܗ�jU��D�;��>��7������/���R�
��R� 	N��i)9������v���r1��Jx��=��<2PU5��u�Lo>4j*r5�1E�(��c5�_t�C:%�k������3f-�51{�U�b���&yM?N��8��n�<H��/;� ۩(�4��q+�n��܌E%��t��]�!񹋤�Y��]�b�(�� A5�&_�Z��8]4���%%&�|��R� 
��R��	�*5���r��0����>�Q��K1"R�E�U��t�᧿�U�q�0��-a�(�^u(V�l��t�r�M��ICP0R��.���,�E�R���%��l�2�4��*��2tj8f	�t��$�!�eeC� �8��`.pU�a��z��'fv���Ɣلeo�7����)t?u彦p�� E�,h0����!y��R���P� 	G�i³� ڕ��W'����jDDd�W�%4�M�쁡�3�#�����k+]R����p����)�����M�j��S���7m���O���ǿV�6���7M��X��18������	�P�
�w;��[s�m�4VyU�Ly����Y�C��-�g��t{d�C�� �OA�D
a��8:����2_Cs1 J���R�� �H��>�*ñ���
S��Yч1 ���O�q�H��gFHj1L�9j2c"G$֖� f�~�1��d��`�4�k!�ߕ�4f�~cvQ���wf�;Ń+�
T!.� і�KKi_Xv�����1s��P��e)jF��[�a������ݞV���ع��)�B���u�r�q�*������L �8eZëġ�:�[��R��L�Tk)AC�j��e)*��3fr��N��Lqػ�tR������zd�dR���r�@}�lB�	�|*U����eM�X�d�g�0(�P����(�����r�Ħ�)dĂ�� 8J9�z&�F�9gGc�ײ�	��fU=\��Ojip� �n�9i�!���B@�R�8 b\e�����G��RG�o�b���S�l�!46g��P��R�ʔ�TkIA=�+��*L����nM2�YIR�V���}��L��l�J��,eh?��P��N�бgS�m2�a��	T=S\`I�=^S���b,���}��e̠W�������}�c��ˍ/�s��p��RXinc�e� �R7��<IRe%s�S������x�m^�g{S�p��XE����� �L�:��h���47�eE�  V ��R�+ 
<�V��	���O3�   t��Kb�
�MA��x-S� 5�L�`P<����Df��d1It	*ͦQۈ����&�Da�**B��2ɶfP��+&�2��-|=�a��t���+H�i C+W��D|��`�H+:<
��l�A{��J�����d���$ql/r��p"		DcF��� [E��С���' 0T�:N��R�*�H�N9� ��3�Ԉ�b05Ӊ�k�c��{��Y�!ӝ� �92bS�	
�L�yd�:a��C&�oط&��
�������qsB硸6�)�L��A0 ]�~��B�WX.܍��ʋ8l;�	),��[\��Y������f2j* �&@d@�%`�� �*
��VB�L�� �a힐�[)�Dc垀.�$� ���R���L� C��C����-�P��k����a��~�4�A�c�I�H��,1�6�$��#��?
�A��ZO>����C��.��H���#�䶎?.�ˣ̹1�![��P�0�$�FS9=�,�iٍW|#�ǽ�t��h�$n[�nk�.f�E����v����Q��fXM�����)zp�71E�
�=IXfN�˼lk�Ө����R��ʈ�T�)It)���(���_�Mri��*��+KI��5��JY{��H�!YC$}�P�~�;@1	eH!�K�����3�5,_�RZO���K�  J���a1�itl!`aZ�j5~�V<��z�ԒU*�Cٸ�P�0�ԁ��R�d����31k�y�r*R�Ùl�J����B��)ԕW��DQC���hb���k��%���ZzlݘM|5���R��ʀ�LkIIJi@�i(71E+kr/Z��"U⑁pb����G_8݊j���Q '�:��[E�T2���A�J��d#}"4�w#5u�id�9ouj�G�,�#E��,q���9d��U+�gw�^�hlZ�|֚hdQPWʂK5�͚e�?IcF?�9��4�Y��?bܻ<,�'����W꿊�i�Gbss�ҸjHB�p`�
S~��R�#�X�JkiAF�)�m)Q۽�ݵֵ��U�L����PY͕Z�³�L�M=1�,bH*8�~jIv�[6���E�/Mյ =d����Ԏ�?�C�@��-��2��S�H2;up*�0�P-�4��j��2�(y�B��֝qPS-S;�m��V{R�oMY�a��m�`&=���Ug��ՠXIci�\��K�l������R��lC= %� :��R�.��t�H�II����)�|I�p+���F�@,���@^m�D��bʱ���-��;�le��1�_VDPc	'V�$�Ȍ�H�L-0r��� �����,ɣ[��U�a�X�&䌀�X�<I۳��M�7�!b�A���%�P}��S_M�V���\��PAt}��c8��y�0 !9�|��3�ʪ��ȱ�����'�M��,4��R�0��,�H�iIAh��i)�M�+"F ddU��̢�s��8n�uoW���,��@�ܮԊ�$C���U�%��#5>���� (�"rS�KgZ�t_n�e�(a�D�GR��C�ɞ��aR���g(�]��Mk%�UTe�b��*��r�Jߙ��Q�Z��?T��������!��h�7C$�gh_��e�NVZ!�fՃ�y��Y��f���R�=��d�F�iAk����m):�/62�ľYL��:\q��Jt�CP�ݤ��*l���rܔ�p�S\�|���h{t�ܩ2��C�J>B�Z��:L.ݭ5��_���o	$�׺���Z���'��`�қS��d�YL G�E�]I�Q�L�cqN�I�?�A&^Pp� �!������կ��-��|�ך�Sؙ"�#Uq��U��R�D���JkIII(���)Ca�.�aa�����Le{��K��
Z���H�0�N�����kRva�SM{�D/P�a�Z'R�>Z��)l���V���"�ej�X�%u��1��zM�3FcR��,���2�w ��A��QA^iM�Hv�,��J{r��$E��zY1w4sya�)�s|�A��Rc�lm7Q�Dk���mMW�YBYف$���,�~��V��<���R�Q�ʀ�F�IAE)��)oju��a��$��~Q5F�Z�@XScx�yȇL�ԕ��^j�t���U�Ls�b�ך�^��'���`Z�ܐ^ؔ;AV7^�	i��~U2�Ņ�wɶٮʢ�;~Wu�_�J��k@�S�H����U�����q��h�$�Q�;;.��� �S6-I����L��N�1*4�Xh8$d������R��R�\���DkIAD)U��(eJ`�A-��0�/�s��k���u�ֱOb�9�D���Co=��8Ë��k�KZ�5^�tg��{;�j��x!jdc|H��{�1I3q��#�[ΰ"�]��C/5LlS\ζN���������Ь�v%��)J|%"��)l����*� �w*1�Z'����)���wsM(��!��⁃�b0�{���1����R�e��T�H�IIF�)�m)�\��a��g��kW�!d����z����Q	Yҍ%�V�ZJIѐ,%q�{?>���j��c��y�kc-T�\�)3����󣚷c��[����}�ڧ��n �1�{��1��!i�Qb`����r������u�5)�
=V��˹d���������	�`	�\\�4p��c�q�q�ٻj�4�{O�U��
o���R�q���F�iIG�(��i(r�q�X�4�;���D����;���A�2u8��&Z��z���C�*g/kf%`ZC�W�Z�7k� ���������+Y�K*�v��E�k�ES��v�gd��Y�ڡE��,d"���L���1o�|�z�+
!�u諧�-�\�:�u�{h�7mg��a)Zi���������B&t#IeH�����R�z�P�H�iA]���i(h�[�"G��Ku���_W:j
��� b2.v�[�\(�i�n�g{�y[�M���ɧ�P�K��<��e�����F$ f�l�����9��]���bO�[��H�T��e��y�:��}\�b�^f�F6e�^�|�g��#A��\a�l	Q�@�LpX=�Y0A�u8c�2��!��W̽����Ră�(�F�iII�)V�� ~�T�������`���0��|��)L��6, 8��,�Ʋ7O1f�7��)@`dg�<��Zf��ڭ��ɡtX�M��+&���H�g�`B�mF�`19�������?ݥ���
�a_�ߢ[�J�C�=�q�����aS�>�*�aH�;��:@S�4�U��'�<y�J�vi[���4'���:$���d��Rď $�H����iC3� �ұ$S/ph`��p�ȍ�5�  ς
�|a<���������yE�@g����0   �����=-o�R���G=<b�,��<�:x�%�a�r�SODV���e;5��&�\�����@s���\��8UG��������  +�ƺY5��5Rj���@2�;�gH (�w�j�w�Sʡ��j�l���f���RĀ |�F��G��#���j̱�x� �1�r%�{��hP�ˁ�)�jFZ%_Ή=�I�9J���α�)1� Z���=��!��)�E2���]q:F���:x������������-#4�t���*���?
��F.�z,�l�43��V*�;_��#���������0 .S7�rv����r�j��2�F'}يLUs�籟+g�����R�{ 
��H�����C3� �h�Yש�f:�cR(�vwq��X�A�2�%T�ݡ�mԁ�T- w�>��b�kK5��;�$�00�M��d�$% <��XW�f�=g���V�"��������${9Kw]FXoW�Zkt��+�Y�(m�!�:�u�򅅆qͻ��h�	�xS��j�(a�Z;Ο̼���έ$�HF,P��#Xǣ��k�(��R�q��<�H�� 	O�(���(��C�9zY��V���[;� �Rw�8�$.5G���K���<LV,A %�����3]�ZܗȦg� :��Y��cƺ�bU*)
����5�
$B �12��g�ڇ&bF ��Ն����i` �e��*��Rʰw�]�6"���b0��"��_*,�[�4��ʽ}a�[�(s*�j�&�����	8_b�����R�|��|�D�iI|�'���(��G�w��JG�ǰ ��|y�Je
�b�X>tg�M0'����,9ч��UF	&8�l:\�\Ų�׏!mn���p��2^� ����a�!"8����Cӱ0�
`��+��Ʊ�ۢ����R���k_nYZD�3i�Ӝ�5-�x���T�0LNp����a+��j9/�m�B#�9�'�q����Rā 
,�D�� 	ᓧ3� 
51	�:ҙ;�//K�-��J1�zf�H�-���,D�|�*fk�z�����v6Pa�K�p���*SZU�IU��vj�I�z,�L�����)�\*y|(BH��|bqHź��L�r�z��|�W��a@C!*E  �_0aFР�� H�_�X���RHӁL�X�b��*@Y�"���t0]�)�����R�z�<�:� 	H��B���E,ѕ6P��I ���8Z`����D`Q+(8��1��$���
ъ�22�! )@��0�X#v�@ ����� a   j��x�ۇ�m��6��w��<^d5:i<���<p۝	wa��Q��DD����D��I�J��%Zﺨ������KAl���G_Q��d��g�(4����RĂ �&����g1� U90@q�0�	�DP��՘�����W,@�� �:4�4�̈a0�2�1��@d�r(,h((:/*�2RÀ(��	R�!-L#(�a�{��Zb��C��,y�\u���K�quZt�\!�����l���,S9\1o������E��a#�z0�����3Xb�	�����e_��R�]���"� X���7� B�(�d��@�	� ֆ%*b�T��XA1�hIp$�	ƺd�����r� �CN��5�I�4`��BɎ�."�G$m�p�2�R��zRi�P�P+�a�g.3�h�#L(:�����o-tb���tm!ќ�`g�۶��!�"��N<5�#�'C�.0"�<9�:6ã�w�2!s*��R�%��̀   4��  #0CsZo8	�㫧^s��"�
�6r�b�L�;!��U���nhg�j���%�0�#CD��!��@¹V���_���.ULAME3.89 (beta)UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��R�7� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULAME3.89 (beta)UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��Rĕ� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULAME3.89 (beta)UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��R��� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULAME3.89 (beta)UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��R���� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUULAME3.89 (beta)UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��R���� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU��R���� �      4�   UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU
