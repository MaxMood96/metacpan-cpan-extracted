

package Graphics::ColorNames::Pantone;

require 5.008;
use strict;
use warnings;

our $VERSION = '0.54';

sub NamesRgbTable { {
  '100'   =>  0xFFFF7D,
  '101'   =>  0xFFFF36,
  '102'   =>  0xFFFC0D,
  '103'   =>  0xD1CB00,
  '104'   =>  0xB3AD00,
  '105'   =>  0x807C00,
  '106'   =>  0xFFFA4F,
  '107'   =>  0xFFF536,
  '108'   =>  0xFFF00D,
  '109'   =>  0xFFE600,
  '110'   =>  0xEDD100,
  '111'   =>  0xBAA600,
  '112'   =>  0x9E8E00,
  '113'   =>  0xFFED57,
  '114'   =>  0xFFEB45,
  '115'   =>  0xFFE833,
  '116'   =>  0xFFD600,
  '117'   =>  0xD9B200,
  '118'   =>  0xBA9900,
  '119'   =>  0x827200,
  '120'   =>  0xFFE86B,
  '1205'  =>  0xFFF2B0,
  '121'   =>  0xFFE34F,
  '1215'  =>  0xFFE88C,
  '122'   =>  0xFFD433,
  '1225'  =>  0xFFD461,
  '123'   =>  0xFFC20F,
  '1235'  =>  0xFFB517,
  '124'   =>  0xF0AD00,
  '1245'  =>  0xD19700,
  '125'   =>  0xBD8C00,
  '1255'  =>  0xA87B00,
  '126'   =>  0xA17800,
  '1265'  =>  0x7D5B00,
  '127'   =>  0xFFED80,
  '128'   =>  0xFFE359,
  '129'   =>  0xFFD63B,
  '130'   =>  0xFFB300,
  '131'   =>  0xE89E00,
  '132'   =>  0xB38100,
  '133'   =>  0x705A00,
  '134'   =>  0xFFE38C,
  '1345'  =>  0xFFDB87,
  '135'   =>  0xFFCF66,
  '1355'  =>  0xFFCC70,
  '136'   =>  0xFFBA3D,
  '1365'  =>  0xFFB547,
  '137'   =>  0xFFA61A,
  '1375'  =>  0xFF991A,
  '138'   =>  0xFC9200,
  '1385'  =>  0xED8500,
  '139'   =>  0xC47C00,
  '1395'  =>  0xA15F00,
  '140'   =>  0x755600,
  '1405'  =>  0x5E3C00,
  '141'   =>  0xFFCF7D,
  '142'   =>  0xFFB83D,
  '143'   =>  0xFFA626,
  '144'   =>  0xFF8500,
  '145'   =>  0xEB7C00,
  '146'   =>  0xAB6100,
  '147'   =>  0x705100,
  '148'   =>  0xFFD6A1,
  '1485'  =>  0xFFBA75,
  '149'   =>  0xFFC487,
  '1495'  =>  0xFFAB54,
  '150'   =>  0xFFA64D,
  '1505'  =>  0xFF943B,
  '151'   =>  0xFF850D,
  '152'   =>  0xFC7C00,
  '1525'  =>  0xE66000,
  '153'   =>  0xD17100,
  '1535'  =>  0x9E4A00,
  '154'   =>  0xA85B00,
  '1545'  =>  0x472200,
  '155'   =>  0xFFE0B8,
  '1555'  =>  0xFFC7A8,
  '156'   =>  0xFFC794,
  '1565'  =>  0xFFA882,
  '157'   =>  0xFF914D,
  '1575'  =>  0xFF8C47,
  '158'   =>  0xFF6308,
  '1585'  =>  0xFF701A,
  '159'   =>  0xED5100,
  '1595'  =>  0xF26300,
  '160'   =>  0xAD4200,
  '1605'  =>  0xB34F00,
  '161'   =>  0x5C2C00,
  '1615'  =>  0x914000,
  '162'   =>  0xFFD9C7,
  '1625'  =>  0xFFB0A1,
  '163'   =>  0xFFB08F,
  '1635'  =>  0xFF9C85,
  '164'   =>  0xFF8A45,
  '1645'  =>  0xFF8257,
  '165'   =>  0xFF690A,
  '1655'  =>  0xFF5E17,
  '166'   =>  0xFF5C00,
  '1665'  =>  0xFF5200,
  '167'   =>  0xD45500,
  '1675'  =>  0xB83D00,
  '168'   =>  0x692D00,
  '1685'  =>  0x8F2E00,
  '169'   =>  0xFFCCCC,
  '170'   =>  0xFF998F,
  '171'   =>  0xFF7852,
  '172'   =>  0xFF571F,
  '173'   =>  0xF54C00,
  '174'   =>  0xA33100,
  '175'   =>  0x662400,
  '176'   =>  0xFFBFD1,
  '1765'  =>  0xFF9EC9,
  '1767'  =>  0xFFBAE0,
  '177'   =>  0xFF8C99,
  '1775'  =>  0xFF87B5,
  '1777'  =>  0xFF6BA3,
  '178'   =>  0xFF6970,
  '1785'  =>  0xFF5480,
  '1787'  =>  0xFF3D66,
  '1788'  =>  0xFF291F,
  '179'   =>  0xFF3600,
  '1795'  =>  0xFF0F00,
  '1797'  =>  0xF50002,
  '180'   =>  0xE33000,
  '1805'  =>  0xC41200,
  '1807'  =>  0xB80007,
  '181'   =>  0x872300,
  '1815'  =>  0x7D0C00,
  '1817'  =>  0x570900,
  '182'   =>  0xFFBDE6,
  '183'   =>  0xFF8AC9,
  '184'   =>  0xFF5296,
  '185'   =>  0xFF173D,
  '186'   =>  0xF5002F,
  '187'   =>  0xCC002B,
  '188'   =>  0x800400,
  '189'   =>  0xFFA1E6,
  '1895'  =>  0xFFB8ED,
  '190'   =>  0xFF73C7,
  '1905'  =>  0xFF96E8,
  '191'   =>  0xFF3D9E,
  '1915'  =>  0xFF4ACC,
  '192'   =>  0xFF0052,
  '1925'  =>  0xFF0073,
  '193'   =>  0xDE004B,
  '1935'  =>  0xF20068,
  '194'   =>  0xAB003E,
  '1945'  =>  0xCF005B,
  '195'   =>  0x73002E,
  '1955'  =>  0xA10040,
  '196'   =>  0xFFBFF5,
  '197'   =>  0xFF8CE6,
  '198'   =>  0xFF38AB,
  '199'   =>  0xFF0061,
  '200'   =>  0xE00053,
  '201'   =>  0xB50043,
  '202'   =>  0x910039,
  '203'   =>  0xFFA8F7,
  '204'   =>  0xFF6BF7,
  '205'   =>  0xFF29E8,
  '206'   =>  0xF70099,
  '207'   =>  0xCF0076,
  '208'   =>  0xA10067,
  '209'   =>  0x78004F,
  '210'   =>  0xFF9CF0,
  '211'   =>  0xFF73EB,
  '212'   =>  0xFF47E3,
  '213'   =>  0xFF0DBA,
  '214'   =>  0xEB009B,
  '215'   =>  0xBA0079,
  '216'   =>  0x82074E,
  '217'   =>  0xFFB8FF,
  '218'   =>  0xFA63FF,
  '219'   =>  0xFC1FFF,
  '220'   =>  0xD400B8,
  '221'   =>  0xB30098,
  '222'   =>  0x69005E,
  '223'   =>  0xFF8AFF,
  '224'   =>  0xFC5EFF,
  '225'   =>  0xFC2BFF,
  '226'   =>  0xFF00FF,
  '227'   =>  0xCF00C0,
  '228'   =>  0x960090,
  '229'   =>  0x660057,
  '230'   =>  0xFFA8FF,
  '231'   =>  0xFC7AFF,
  '232'   =>  0xF754FF,
  '233'   =>  0xE300FF,
  '234'   =>  0xB100BD,
  '235'   =>  0x910099,
  '236'   =>  0xFCB3FF,
  '2365'  =>  0xFABAFF,
  '237'   =>  0xF782FF,
  '2375'  =>  0xE66EFF,
  '238'   =>  0xF05EFF,
  '2385'  =>  0xCF36FF,
  '239'   =>  0xE336FF,
  '2395'  =>  0xBA0DFF,
  '240'   =>  0xD10FFF,
  '2405'  =>  0xA800FF,
  '241'   =>  0xB600FA,
  '2415'  =>  0x9D00EB,
  '242'   =>  0x750082,
  '2425'  =>  0x7700BD,
  '243'   =>  0xF2B5FF,
  '244'   =>  0xE89EFF,
  '245'   =>  0xDB78FF,
  '246'   =>  0xB51AFF,
  '247'   =>  0xA300FF,
  '248'   =>  0x9600FA,
  '249'   =>  0x6E00B8,
  '250'   =>  0xF2D1FF,
  '251'   =>  0xDE9CFF,
  '252'   =>  0xC270FF,
  '253'   =>  0x910DFF,
  '254'   =>  0x8000FF,
  '255'   =>  0x5E00BF,
  '256'   =>  0xEDCCFF,
  '2562'  =>  0xCFA6FF,
  '2563'  =>  0xC7ABFF,
  '2567'  =>  0xB5A3FF,
  '257'   =>  0xDBA8FF,
  '2572'  =>  0xB387FF,
  '2573'  =>  0xB391FF,
  '2577'  =>  0x998CFF,
  '258'   =>  0x913DFF,
  '2582'  =>  0x8A47FF,
  '2583'  =>  0x8A5EFF,
  '2587'  =>  0x6957FF,
  '259'   =>  0x5F00D9,
  '2592'  =>  0x661AFF,
  '2593'  =>  0x631CFF,
  '2597'  =>  0x2600FF,
  '260'   =>  0x5B00BD,
  '2602'  =>  0x5C00F7,
  '2603'  =>  0x4D00FA,
  '2607'  =>  0x2D00ED,
  '261'   =>  0x500099,
  '2612'  =>  0x4F00DB,
  '2613'  =>  0x5000D9,
  '2617'  =>  0x2E00D9,
  '262'   =>  0x3F0073,
  '2622'  =>  0x3C008F,
  '2623'  =>  0x4700AD,
  '2627'  =>  0x2800B0,
  '263'   =>  0xE6DBFF,
  '2635'  =>  0xB8BAFF,
  '264'   =>  0xBDB8FF,
  '2645'  =>  0x99A3FF,
  '265'   =>  0x7570FF,
  '2655'  =>  0x7582FF,
  '266'   =>  0x361AFF,
  '2665'  =>  0x6166FF,
  '267'   =>  0x1C00FF,
  '268'   =>  0x2800E0,
  '2685'  =>  0x0900E6,
  '269'   =>  0x2600AB,
  '2695'  =>  0x0C0082,
  '270'   =>  0xB0BAFF,
  '2705'  =>  0x99B3FF,
  '2706'  =>  0xCFE8FF,
  '2707'  =>  0xD4F0FF,
  '2708'  =>  0xBDE6FF,
  '271'   =>  0x91A1FF,
  '2715'  =>  0x6E8CFF,
  '2716'  =>  0x8CB5FF,
  '2717'  =>  0xB5E0FF,
  '2718'  =>  0x5496FF,
  '272'   =>  0x6B85FF,
  '2725'  =>  0x3B52FF,
  '2726'  =>  0x3657FF,
  '2727'  =>  0x4A94FF,
  '2728'  =>  0x0A4FFF,
  '273'   =>  0x0009EB,
  '2735'  =>  0x000DFF,
  '2736'  =>  0x0017FF,
  '2738'  =>  0x0020FA,
  '274'   =>  0x0000B8,
  '2745'  =>  0x000BD9,
  '2746'  =>  0x0012E6,
  '2747'  =>  0x001ED9,
  '2748'  =>  0x001AD9,
  '275'   =>  0x030091,
  '2755'  =>  0x0005B3,
  '2756'  =>  0x000BB5,
  '2757'  =>  0x0020B3,
  '2758'  =>  0x0026BD,
  '276'   =>  0x020073,
  '2765'  =>  0x00048C,
  '2766'  =>  0x000887,
  '2767'  =>  0x001A75,
  '2768'  =>  0x001F8F,
  '277'   =>  0xBAEDFF,
  '278'   =>  0x9CDBFF,
  '279'   =>  0x52A8FF,
  '280'   =>  0x003BD1,
  '281'   =>  0x0031AD,
  '282'   =>  0x002675,
  '283'   =>  0xA6E8FF,
  '284'   =>  0x73CFFF,
  '285'   =>  0x1C91FF,
  '286'   =>  0x0055FA,
  '287'   =>  0x0048E0,
  '288'   =>  0x0041C4,
  '289'   =>  0x00246B,
  '290'   =>  0xBFFAFF,
  '2905'  =>  0x96FAFF,
  '291'   =>  0xABF7FF,
  '2915'  =>  0x69EDFF,
  '292'   =>  0x82E3FF,
  '2925'  =>  0x26C2FF,
  '293'   =>  0x006BFA,
  '2935'  =>  0x008AFF,
  '294'   =>  0x0055C9,
  '2945'  =>  0x0079DB,
  '295'   =>  0x0045A1,
  '2955'  =>  0x0058A1,
  '296'   =>  0x00294D,
  '2965'  =>  0x00395C,
  '297'   =>  0x82FCFF,
  '2975'  =>  0xB3FFF2,
  '298'   =>  0x4FEDFF,
  '2985'  =>  0x69FFF0,
  '299'   =>  0x26CFFF,
  '2995'  =>  0x1AE3FF,
  '300'   =>  0x008FFF,
  '3005'  =>  0x00A0FA,
  '301'   =>  0x0073D1,
  '3015'  =>  0x0089CC,
  '302'   =>  0x006080,
  '3025'  =>  0x00687D,
  '303'   =>  0x003B42,
  '3035'  =>  0x004744,
  '304'   =>  0xB3FFEB,
  '305'   =>  0x7DFFE8,
  '306'   =>  0x40FFED,
  '307'   =>  0x009CBA,
  '308'   =>  0x008087,
  '309'   =>  0x004741,
  '310'   =>  0x91FFE6,
  '3105'  =>  0x91FFE0,
  '311'   =>  0x5EFFE0,
  '3115'  =>  0x5EFFD1,
  '312'   =>  0x0AFFE3,
  '3125'  =>  0x2BFFC9,
  '313'   =>  0x00DECC,
  '3135'  =>  0x00E8C3,
  '314'   =>  0x00B3A2,
  '3145'  =>  0x00C49F,
  '315'   =>  0x009180,
  '3155'  =>  0x009E78,
  '316'   =>  0x00523C,
  '3165'  =>  0x005940,
  '317'   =>  0xD1FFEB,
  '318'   =>  0x9EFFD9,
  '319'   =>  0x7AFFCF,
  '320'   =>  0x00EDA4,
  '321'   =>  0x00C487,
  '322'   =>  0x00A66F,
  '323'   =>  0x008754,
  '324'   =>  0xB8FFE0,
  '3242'  =>  0xA1FFD1,
  '3245'  =>  0xA8FFCF,
  '3248'  =>  0x91FFC2,
  '325'   =>  0x70FFBD,
  '3252'  =>  0x87FFC2,
  '3255'  =>  0x82FFB8,
  '3258'  =>  0x69FFAB,
  '326'   =>  0x21FF9E,
  '3262'  =>  0x4AFFAB,
  '3265'  =>  0x4FFFA1,
  '3268'  =>  0x1AFF82,
  '327'   =>  0x00D477,
  '3272'  =>  0x00FF8F,
  '3275'  =>  0x0DFF87,
  '3278'  =>  0x00F26D,
  '328'   =>  0x00AD5F,
  '3282'  =>  0x00D975,
  '3285'  =>  0x00ED77,
  '3288'  =>  0x00CC5E,
  '329'   =>  0x008A4A,
  '3292'  =>  0x008A46,
  '3295'  =>  0x00C95F,
  '3298'  =>  0x009440,
  '330'   =>  0x006635,
  '3302'  =>  0x004F24,
  '3305'  =>  0x006327,
  '3308'  =>  0x00471D,
  '331'   =>  0xC2FFD6,
  '332'   =>  0xB3FFCC,
  '333'   =>  0x91FFBA,
  '334'   =>  0x00F763,
  '335'   =>  0x00B33E,
  '336'   =>  0x00872D,
  '337'   =>  0xB0FFCC,
  '3375'  =>  0xA6FFBF,
  '338'   =>  0x87FFAD,
  '3385'  =>  0x8CFFAB,
  '339'   =>  0x29FF70,
  '3395'  =>  0x63FF8C,
  '340'   =>  0x00E84F,
  '3405'  =>  0x26FF59,
  '341'   =>  0x00B53C,
  '3415'  =>  0x00C72E,
  '342'   =>  0x00912A,
  '3425'  =>  0x009421,
  '343'   =>  0x02631C,
  '3435'  =>  0x005710,
  '344'   =>  0xBAFFC4,
  '345'   =>  0x9EFFAD,
  '346'   =>  0x73FF87,
  '347'   =>  0x00F723,
  '348'   =>  0x00C21D,
  '349'   =>  0x00940D,
  '350'   =>  0x0D4000,
  '351'   =>  0xD4FFD6,
  '352'   =>  0xBAFFBF,
  '353'   =>  0x9EFFA3,
  '354'   =>  0x33FF1A,
  '355'   =>  0x0FFF00,
  '356'   =>  0x09BA00,
  '357'   =>  0x167000,
  '358'   =>  0xBAFF9E,
  '359'   =>  0xA3FF82,
  '360'   =>  0x6BFF33,
  '361'   =>  0x4FFF00,
  '362'   =>  0x46E800,
  '363'   =>  0x3EC200,
  '364'   =>  0x349400,
  '365'   =>  0xE0FFB5,
  '366'   =>  0xCCFF8F,
  '367'   =>  0xADFF69,
  '368'   =>  0x6EFF00,
  '369'   =>  0x61ED00,
  '370'   =>  0x52BA00,
  '371'   =>  0x407000,
  '372'   =>  0xE6FFAB,
  '373'   =>  0xD6FF8A,
  '374'   =>  0xC2FF6E,
  '375'   =>  0x96FF38,
  '376'   =>  0x74F200,
  '377'   =>  0x6BC200,
  '378'   =>  0x436600,
  '379'   =>  0xE8FF6B,
  '380'   =>  0xDEFF47,
  '381'   =>  0xCCFF17,
  '382'   =>  0xB5FF00,
  '383'   =>  0xA5CF00,
  '384'   =>  0x90B000,
  '385'   =>  0x686B00,
  '386'   =>  0xF0FF70,
  '387'   =>  0xE6FF42,
  '388'   =>  0xDBFF36,
  '389'   =>  0xCCFF26,
  '390'   =>  0xB7EB00,
  '391'   =>  0x95AB00,
  '392'   =>  0x798200,
  '393'   =>  0xF7FF73,
  '3935'  =>  0xFCFF52,
  '394'   =>  0xF0FF3D,
  '3945'  =>  0xF7FF26,
  '395'   =>  0xEBFF26,
  '3955'  =>  0xF0FF00,
  '396'   =>  0xE3FF0F,
  '3965'  =>  0xEBFF00,
  '397'   =>  0xCCE300,
  '3975'  =>  0xB5B500,
  '398'   =>  0xABB800,
  '3985'  =>  0x969200,
  '399'   =>  0x919100,
  '3995'  =>  0x5C5900,
  '400'   =>  0xD6D0C9,
  '401'   =>  0xC4BBAF,
  '402'   =>  0xB0A597,
  '403'   =>  0x918779,
  '404'   =>  0x706758,
  '405'   =>  0x474030,
  '406'   =>  0xD6CBC9,
  '407'   =>  0xBDAEAC,
  '408'   =>  0xA89796,
  '409'   =>  0x8C7A77,
  '410'   =>  0x705C59,
  '411'   =>  0x47342E,
  '412'   =>  0x050402,
  '413'   =>  0xCCCCBA,
  '414'   =>  0xB3B3A1,
  '415'   =>  0x969684,
  '416'   =>  0x80806B,
  '417'   =>  0x585943,
  '418'   =>  0x3E402C,
  '419'   =>  0x000000,
  '420'   =>  0xD9D9D9,
  '421'   =>  0xBDBDBD,
  '422'   =>  0xABABAB,
  '423'   =>  0x8F8F8F,
  '424'   =>  0x636363,
  '425'   =>  0x3B3B3B,
  '426'   =>  0x000000,
  '427'   =>  0xE3E3E3,
  '428'   =>  0xCDD1D1,
  '429'   =>  0xA8ADAD,
  '430'   =>  0x858C8C,
  '431'   =>  0x525B5C,
  '432'   =>  0x2D393B,
  '433'   =>  0x090C0D,
  '434'   =>  0xEDE6E8,
  '435'   =>  0xDED6DB,
  '436'   =>  0xC2BFBF,
  '437'   =>  0x8A8C8A,
  '438'   =>  0x394500,
  '439'   =>  0x293300,
  '440'   =>  0x202700,
  '441'   =>  0xDAE8D8,
  '442'   =>  0xBECFBC,
  '443'   =>  0x9DB39D,
  '444'   =>  0x7E947E,
  '445'   =>  0x475947,
  '446'   =>  0x324031,
  '447'   =>  0x272E20,
  '448'   =>  0x2D3E00,
  '4485'  =>  0x4F3A00,
  '449'   =>  0x3D5200,
  '4495'  =>  0x8A6E07,
  '450'   =>  0x506700,
  '4505'  =>  0xA38B24,
  '451'   =>  0xABB573,
  '4515'  =>  0xC2B061,
  '452'   =>  0xC2CF9C,
  '4525'  =>  0xD4C581,
  '453'   =>  0xDBE3BF,
  '4535'  =>  0xE3DA9F,
  '454'   =>  0xE8EDD6,
  '4545'  =>  0xF0E9C2,
  '455'   =>  0x594A00,
  '456'   =>  0x917C00,
  '457'   =>  0xB89C00,
  '458'   =>  0xE6E645,
  '459'   =>  0xF0ED73,
  '460'   =>  0xF5F28F,
  '461'   =>  0xF7F7A6,
  '462'   =>  0x402600,
  '4625'  =>  0x361500,
  '463'   =>  0x6B3D00,
  '4635'  =>  0x8F4A06,
  '464'   =>  0x955300,
  '4645'  =>  0xB8743B,
  '465'   =>  0xCCAD6B,
  '4655'  =>  0xD19B73,
  '466'   =>  0xE0C791,
  '4665'  =>  0xE6BC9C,
  '467'   =>  0xE8D9A8,
  '4675'  =>  0xF0D5BD,
  '468'   =>  0xF0E8C4,
  '4685'  =>  0xF5E4D3,
  '469'   =>  0x4A1A00,
  '4695'  =>  0x420D00,
  '470'   =>  0xAB4800,
  '4705'  =>  0x823126,
  '471'   =>  0xD15600,
  '4715'  =>  0xA8625D,
  '472'   =>  0xFFA87A,
  '4725'  =>  0xBF827C,
  '473'   =>  0xFFC4A3,
  '4735'  =>  0xD9A9A7,
  '474'   =>  0xFFD9BD,
  '4745'  =>  0xE6BEBC,
  '475'   =>  0xFFE3CC,
  '4755'  =>  0xF0D8D3,
  '476'   =>  0x381C00,
  '477'   =>  0x4F1800,
  '478'   =>  0x6B1200,
  '479'   =>  0xB08573,
  '480'   =>  0xD9B5B0,
  '481'   =>  0xE8CFC9,
  '482'   =>  0xF2E0DE,
  '483'   =>  0x660700,
  '484'   =>  0xB50900,
  '485'   =>  0xFF0D00,
  '486'   =>  0xFF8796,
  '487'   =>  0xFFA6B8,
  '488'   =>  0xFFBDCF,
  '489'   =>  0xFFD9E3,
  '490'   =>  0x471300,
  '491'   =>  0x7A1A00,
  '492'   =>  0x942200,
  '493'   =>  0xF283BB,
  '494'   =>  0xFFABDE,
  '495'   =>  0xFFC2E3,
  '496'   =>  0xFFD6E8,
  '497'   =>  0x381100,
  '4975'  =>  0x330E00,
  '498'   =>  0x662500,
  '4985'  =>  0x853241,
  '499'   =>  0x853100,
  '4995'  =>  0xA85868,
  '500'   =>  0xE38DB3,
  '5005'  =>  0xC47A8F,
  '501'   =>  0xF7B5D7,
  '5015'  =>  0xE3AAC1,
  '502'   =>  0xFCCFE3,
  '5025'  =>  0xEDC2D1,
  '503'   =>  0xFFE3EB,
  '5035'  =>  0xF7DFE1,
  '504'   =>  0x320000,
  '505'   =>  0x600000,
  '506'   =>  0x770000,
  '507'   =>  0xDE82C4,
  '508'   =>  0xF2A3E3,
  '509'   =>  0xFFC2ED,
  '510'   =>  0xFFD4F0,
  '511'   =>  0x3D0066,
  '5115'  =>  0x2B0041,
  '512'   =>  0x6100CE,
  '5125'  =>  0x592482,
  '513'   =>  0x8A1FFF,
  '5135'  =>  0x8257B8,
  '514'   =>  0xD980FF,
  '5145'  =>  0xB38CE0,
  '515'   =>  0xED9EFF,
  '5155'  =>  0xD4B3EB,
  '516'   =>  0xF7BAFF,
  '5165'  =>  0xE8CFF2,
  '517'   =>  0xFFD1FF,
  '5175'  =>  0xF2E0F7,
  '518'   =>  0x2E005C,
  '5185'  =>  0x1C0022,
  '519'   =>  0x44009D,
  '5195'  =>  0x3D0C4E,
  '520'   =>  0x5C00E0,
  '5205'  =>  0x7A5E85,
  '521'   =>  0xBA87FF,
  '5215'  =>  0xB59EC2,
  '522'   =>  0xD4A1FF,
  '5225'  =>  0xD4BAD9,
  '523'   =>  0xE6BDFF,
  '5235'  =>  0xE6D4E6,
  '524'   =>  0xF0D9FF,
  '5245'  =>  0xF0E6ED,
  '525'   =>  0x270085,
  '5255'  =>  0x0D0B4D,
  '526'   =>  0x3B00ED,
  '5265'  =>  0x20258A,
  '527'   =>  0x4500FF,
  '5275'  =>  0x3848A8,
  '528'   =>  0x9673FF,
  '5285'  =>  0x7280C4,
  '529'   =>  0xBD99FF,
  '5295'  =>  0xA8B3E6,
  '530'   =>  0xD1B0FF,
  '5305'  =>  0xC7CEED,
  '531'   =>  0xE6CCFF,
  '5315'  =>  0xE4E4F2,
  '532'   =>  0x00193F,
  '533'   =>  0x00227B,
  '534'   =>  0x002CAA,
  '535'   =>  0x94B3ED,
  '536'   =>  0xB0C7F2,
  '537'   =>  0xC7DBF7,
  '538'   =>  0xDEE8FA,
  '539'   =>  0x00274D,
  '5395'  =>  0x00223D,
  '540'   =>  0x003473,
  '5405'  =>  0x3A728A,
  '541'   =>  0x00449E,
  '5415'  =>  0x5A8A96,
  '542'   =>  0x5EC1F7,
  '5425'  =>  0x79A6AD,
  '543'   =>  0x96E3FF,
  '5435'  =>  0xB8CDD4,
  '544'   =>  0xB3F0FF,
  '5445'  =>  0xCCDCDE,
  '545'   =>  0xC7F7FF,
  '5455'  =>  0xDAE8E8,
  '546'   =>  0x02272B,
  '5463'  =>  0x002B24,
  '5467'  =>  0x000D09,
  '547'   =>  0x003440,
  '5473'  =>  0x167A58,
  '5477'  =>  0x1D4230,
  '548'   =>  0x00465C,
  '5483'  =>  0x43B08B,
  '5487'  =>  0x48705D,
  '549'   =>  0x56ADBA,
  '5493'  =>  0x73C9AD,
  '5497'  =>  0x829E90,
  '550'   =>  0x7BC1C9,
  '5503'  =>  0x9CDBC5,
  '5507'  =>  0xA1B5A8,
  '551'   =>  0xA2D7DE,
  '5513'  =>  0xC7F2E1,
  '5517'  =>  0xBED1C5,
  '552'   =>  0xC5E8E8,
  '5523'  =>  0xDCF7EB,
  '5527'  =>  0xD5E3DA,
  '553'   =>  0x143319,
  '5535'  =>  0x102E14,
  '554'   =>  0x115422,
  '5545'  =>  0x327A3D,
  '555'   =>  0x187031,
  '5555'  =>  0x5A9E68,
  '556'   =>  0x66BA80,
  '5565'  =>  0x84BD8F,
  '557'   =>  0x98D9AD,
  '5575'  =>  0xA9D4B2,
  '558'   =>  0xBAE8CA,
  '5585'  =>  0xCAE6CC,
  '559'   =>  0xCEF0D8,
  '5595'  =>  0xDDEDDA,
  '560'   =>  0x0D4018,
  '5605'  =>  0x050F07,
  '561'   =>  0x127A38,
  '5615'  =>  0x2E522B,
  '562'   =>  0x1AB058,
  '5625'  =>  0x5A7D57,
  '563'   =>  0x79FCAC,
  '5635'  =>  0x89A386,
  '564'   =>  0xA1FFCC,
  '5645'  =>  0xAEBFA6,
  '565'   =>  0xC4FFDE,
  '5655'  =>  0xC5D1BE,
  '566'   =>  0xDBFFE8,
  '5665'  =>  0xDAE6D5,
  '567'   =>  0x0E4D1C,
  '568'   =>  0x14A346,
  '569'   =>  0x04D45B,
  '570'   =>  0x85FFB5,
  '571'   =>  0xADFFCF,
  '572'   =>  0xC4FFDB,
  '573'   =>  0xDBFFE8,
  '574'   =>  0x314A0E,
  '5743'  =>  0x1F2E07,
  '5747'  =>  0x243600,
  '575'   =>  0x3E7800,
  '5753'  =>  0x3F5410,
  '5757'  =>  0x547306,
  '576'   =>  0x4F9C00,
  '5763'  =>  0x5C6E1D,
  '5767'  =>  0x849C32,
  '577'   =>  0xAEE67C,
  '5773'  =>  0x909E5A,
  '5777'  =>  0xA5B85E,
  '578'   =>  0xC0F090,
  '5783'  =>  0xAFBA86,
  '5787'  =>  0xCEDE99,
  '579'   =>  0xCDF7A3,
  '5793'  =>  0xC9D1A5,
  '5797'  =>  0xDCE8B0,
  '580'   =>  0xDCFAB9,
  '5803'  =>  0xDEE3C8,
  '5807'  =>  0xE9F0CE,
  '581'   =>  0x464700,
  '5815'  =>  0x363605,
  '582'   =>  0x788A00,
  '5825'  =>  0x69660E,
  '583'   =>  0xA3D400,
  '5835'  =>  0x999632,
  '584'   =>  0xD3F032,
  '5845'  =>  0xB3B15F,
  '585'   =>  0xDEFA55,
  '5855'  =>  0xD1D190,
  '586'   =>  0xE8FF78,
  '5865'  =>  0xDEDEA6,
  '587'   =>  0xF2FF99,
  '5875'  =>  0xEBEBC0,
  '600'   =>  0xFFFFB5,
  '601'   =>  0xFFFF99,
  '602'   =>  0xFFFF7D,
  '603'   =>  0xFCFC4E,
  '604'   =>  0xF7F71E,
  '605'   =>  0xEDE800,
  '606'   =>  0xE0D700,
  '607'   =>  0xFCFCCF,
  '608'   =>  0xFAFAAA,
  '609'   =>  0xF5F584,
  '610'   =>  0xF0F065,
  '611'   =>  0xE3E112,
  '612'   =>  0xCCC800,
  '613'   =>  0xB3AB00,
  '614'   =>  0xF5F5C4,
  '615'   =>  0xF0EDAF,
  '616'   =>  0xE8E397,
  '617'   =>  0xD4CF6E,
  '618'   =>  0xB3AD17,
  '619'   =>  0x918C00,
  '620'   =>  0x787200,
  '621'   =>  0xD9FAE1,
  '622'   =>  0xBAF5C6,
  '623'   =>  0x9CE6AE,
  '624'   =>  0x72CC85,
  '625'   =>  0x4BAB60,
  '626'   =>  0x175E22,
  '627'   =>  0x04290A,
  '628'   =>  0xCFFFF0,
  '629'   =>  0xA8FFE8,
  '630'   =>  0x87FFE3,
  '631'   =>  0x52FADC,
  '632'   =>  0x13F2CE,
  '633'   =>  0x00BFAC,
  '634'   =>  0x00998B,
  '635'   =>  0xADFFEB,
  '636'   =>  0x8CFFE8,
  '637'   =>  0x73FFE8,
  '638'   =>  0x2BFFE6,
  '639'   =>  0x00F2E6,
  '640'   =>  0x00C7C7,
  '641'   =>  0x00ABB3,
  '642'   =>  0xD2F0FA,
  '643'   =>  0xB8E4F5,
  '644'   =>  0x8BCCF0,
  '645'   =>  0x64A7E8,
  '646'   =>  0x4696E3,
  '647'   =>  0x0056C4,
  '648'   =>  0x002D75,
  '649'   =>  0xD9EDFC,
  '650'   =>  0xBEE3FA,
  '651'   =>  0x95C5F0,
  '652'   =>  0x5C97E6,
  '653'   =>  0x004ECC,
  '654'   =>  0x00399E,
  '655'   =>  0x002B7A,
  '656'   =>  0xDBF5FF,
  '657'   =>  0xC2EBFF,
  '658'   =>  0x96CCFF,
  '659'   =>  0x5CA6FF,
  '660'   =>  0x1A6EFF,
  '661'   =>  0x0048E8,
  '662'   =>  0x003BD1,
  '663'   =>  0xEDF0FF,
  '664'   =>  0xE3E8FF,
  '665'   =>  0xC8CFFA,
  '666'   =>  0xA4A6ED,
  '667'   =>  0x6970DB,
  '668'   =>  0x3E40B3,
  '669'   =>  0x201E87,
  '670'   =>  0xFFDEFF,
  '671'   =>  0xFCCCFF,
  '672'   =>  0xF7A8FF,
  '673'   =>  0xF082FF,
  '674'   =>  0xE854FF,
  '675'   =>  0xCD00F7,
  '676'   =>  0xBB00C7,
  '677'   =>  0xFADEFF,
  '678'   =>  0xF7C9FF,
  '679'   =>  0xF2BAFF,
  '680'   =>  0xE18EFA,
  '681'   =>  0xC15FF5,
  '682'   =>  0xA82FE0,
  '683'   =>  0x810091,
  '684'   =>  0xFACFFA,
  '685'   =>  0xF7BAF7,
  '686'   =>  0xF2AAF2,
  '687'   =>  0xDC7EE0,
  '688'   =>  0xC459CF,
  '689'   =>  0x9D27A8,
  '690'   =>  0x690369,
  '691'   =>  0xFCD7E8,
  '692'   =>  0xFAC0E1,
  '693'   =>  0xF0A8D3,
  '694'   =>  0xE683BA,
  '695'   =>  0xBF508A,
  '696'   =>  0x991846,
  '697'   =>  0x7D0925,
  '698'   =>  0xFFD6EB,
  '699'   =>  0xFFC2E6,
  '700'   =>  0xFFA3DB,
  '701'   =>  0xFF78CC,
  '702'   =>  0xF24BA0,
  '703'   =>  0xD62463,
  '704'   =>  0xBA0025,
  '705'   =>  0xFFE8F2,
  '706'   =>  0xFFD4E6,
  '707'   =>  0xFFB3DB,
  '708'   =>  0xFF8AC7,
  '709'   =>  0xFF579E,
  '710'   =>  0xFF366B,
  '711'   =>  0xFA0032,
  '712'   =>  0xFFDBB0,
  '713'   =>  0xFFCF96,
  '714'   =>  0xFFB875,
  '715'   =>  0xFFA14A,
  '716'   =>  0xFF8717,
  '717'   =>  0xFA7000,
  '718'   =>  0xEB6300,
  '719'   =>  0xFFE6BF,
  '720'   =>  0xFCD7A7,
  '721'   =>  0xF7BC77,
  '722'   =>  0xE89538,
  '723'   =>  0xD4740B,
  '724'   =>  0xA14C00,
  '725'   =>  0x823B00,
  '726'   =>  0xFAE6C0,
  '727'   =>  0xF2CEA0,
  '728'   =>  0xE6B577,
  '729'   =>  0xD19052,
  '730'   =>  0xB56E2B,
  '731'   =>  0x753700,
  '732'   =>  0x5C2800,
  '7401'  =>  0xFFF5D1,
  '7402'  =>  0xFFF0B3,
  '7403'  =>  0xFFE680,
  '7404'  =>  0xFFE833,
  '7405'  =>  0xFFE600,
  '7406'  =>  0xFFD100,
  '7407'  =>  0xE3B122,
  '7408'  =>  0xFFBF0D,
  '7409'  =>  0xFFB30D,
  '7410'  =>  0xFFB373,
  '7411'  =>  0xFFA64F,
  '7412'  =>  0xED8A00,
  '7413'  =>  0xF57300,
  '7414'  =>  0xE37B00,
  '7415'  =>  0xFFD1D9,
  '7416'  =>  0xFF6666,
  '7417'  =>  0xFF4040,
  '7418'  =>  0xF24961,
  '7419'  =>  0xD15473,
  '7420'  =>  0xCC2976,
  '7421'  =>  0x630046,
  '7422'  =>  0xFFE8F2,
  '7423'  =>  0xFF73C7,
  '7424'  =>  0xFF40B3,
  '7425'  =>  0xED18A6,
  '7426'  =>  0xD10073,
  '7427'  =>  0xB80040,
  '7428'  =>  0x73173F,
  '7429'  =>  0xFFD1F7,
  '7430'  =>  0xFAB0FF,
  '7431'  =>  0xF296ED,
  '7432'  =>  0xE667DF,
  '7433'  =>  0xD936B8,
  '7434'  =>  0xCC29AD,
  '7435'  =>  0xA60095,
  '7436'  =>  0xF7EBFF,
  '7437'  =>  0xF0CCFF,
  '7438'  =>  0xD9A6FF,
  '7439'  =>  0xCCA6FF,
  '7440'  =>  0xB399FF,
  '7441'  =>  0xA380FF,
  '7442'  =>  0x804DFF,
  '7443'  =>  0xF0F2FF,
  '7444'  =>  0xCCD4FF,
  '7445'  =>  0xADC6F7,
  '7446'  =>  0x919EFF,
  '7447'  =>  0x5357CF,
  '7448'  =>  0x4E4373,
  '7449'  =>  0x270020,
  '7450'  =>  0xCCE6FF,
  '7451'  =>  0x99C9FF,
  '7452'  =>  0x80ADFF,
  '7453'  =>  0x80BDFF,
  '7454'  =>  0x73AEE6,
  '7455'  =>  0x3378FF,
  '7456'  =>  0x6B9AED,
  '7457'  =>  0xE0FFFA,
  '7458'  =>  0x90F0E4,
  '7459'  =>  0x5FDED1,
  '7460'  =>  0x00F2F2,
  '7461'  =>  0x38B8FF,
  '7462'  =>  0x0073E6,
  '7463'  =>  0x003359,
  '7464'  =>  0xBFFFE6,
  '7465'  =>  0x80FFBF,
  '7466'  =>  0x4DFFC4,
  '7467'  =>  0x0DFFBF,
  '7468'  =>  0x00A5B8,
  '7469'  =>  0x007A99,
  '7470'  =>  0x1C778C,
  '7471'  =>  0xB8FFDB,
  '7472'  =>  0x7AFFBF,
  '7473'  =>  0x46EB91,
  '7474'  =>  0x14C78F,
  '7475'  =>  0x59B386,
  '7476'  =>  0x00663A,
  '7477'  =>  0x105249,
  '7478'  =>  0xD1FFDB,
  '7479'  =>  0x73FF80,
  '7480'  =>  0x66FF80,
  '7481'  =>  0x66FF73,
  '7482'  =>  0x33FF40,
  '7483'  =>  0x117300,
  '7484'  =>  0x008013,
  '7485'  =>  0xF0FFE6,
  '7486'  =>  0xCCFFB3,
  '7487'  =>  0xB3FF8C,
  '7488'  =>  0x91FF66,
  '7489'  =>  0x5FED2F,
  '7490'  =>  0x5BA621,
  '7491'  =>  0x689900,
  '7492'  =>  0xD1ED77,
  '7493'  =>  0xC5E693,
  '7494'  =>  0xA3D982,
  '7495'  =>  0x86B324,
  '7496'  =>  0x5F9E00,
  '7497'  =>  0x738639,
  '7498'  =>  0x263300,
  '7499'  =>  0xFFFAD9,
  '7500'  =>  0xF7F2D2,
  '7501'  =>  0xF0E6C0,
  '7502'  =>  0xE6D395,
  '7503'  =>  0xBFA87C,
  '7504'  =>  0x997354,
  '7505'  =>  0x735022,
  '7506'  =>  0xFFF2D9,
  '7507'  =>  0xFFE6B3,
  '7508'  =>  0xF5D093,
  '7509'  =>  0xF2C279,
  '7510'  =>  0xE39F40,
  '7511'  =>  0xBF6900,
  '7512'  =>  0xAB5C00,
  '7513'  =>  0xF7CBB2,
  '7514'  =>  0xF2B896,
  '7515'  =>  0xE09270,
  '7516'  =>  0xA65000,
  '7517'  =>  0x8F3900,
  '7518'  =>  0x663D2E,
  '7519'  =>  0x423500,
  '7520'  =>  0xFFD6CF,
  '7521'  =>  0xE6ACB8,
  '7522'  =>  0xD68196,
  '7523'  =>  0xCC7A85,
  '7524'  =>  0xBA544A,
  '7525'  =>  0xB36259,
  '7526'  =>  0xA63A00,
  '7527'  =>  0xEDE8DF,
  '7528'  =>  0xE6DFCF,
  '7529'  =>  0xD4CBBA,
  '7530'  =>  0xADA089,
  '7531'  =>  0x80735D,
  '7532'  =>  0x594A2D,
  '7533'  =>  0x261E06,
  '7534'  =>  0xE6E1D3,
  '7535'  =>  0xCCC6AD,
  '7536'  =>  0xADA687,
  '7537'  =>  0xC6CCB8,
  '7538'  =>  0xA2B39B,
  '7539'  =>  0xA0A395,
  '7540'  =>  0x474747,
  '7541'  =>  0xEDF2F2,
  '7542'  =>  0xC1D6D0,
  '7543'  =>  0xA6B3B3,
  '7544'  =>  0x8A9799,
  '7545'  =>  0x495C5E,
  '7546'  =>  0x304547,
  '7547'  =>  0x0A0F0F,
  '1162x' =>  0xFF9105,
  '1302x' =>  0xFF6B08,
  '1652x' =>  0xFF080A,
  '17882x'=>  0xFC000A,
  '1852x' =>  0xFC000A,
  '4852x' =>  0xFC000A,
  '2392x' =>  0xE800A1,
  '25922x'=>  0x3005FF,
  '2992x' =>  0x03BFFF,
  '3062x' =>  0x0DFCF2,
  '3202x' =>  0x00CCBF,
  '3272x' =>  0x02A80A,
  '3542x' =>  0x05FF05,
  '3682x' =>  0x1CFC03,
  '3752x' =>  0x38FF00,
  '3822x' =>  0x9CFC03,
  '4712x' =>  0xCC1F05,
  '4642x' =>  0x803007,
  '4332x' =>  0x0C1518,
  '801'   =>  0x17FFE3,
  '802'   =>  0x6BFF05,
  '803'   =>  0xFCE81F,
  '804'   =>  0xFF5914,
  '805'   =>  0xFF2138,
  '806'   =>  0xFA0F96,
  '807'   =>  0xE60AEB,
  '8012x' =>  0x03E0F5,
  '8022x' =>  0x40FF03,
  '8032x' =>  0xFFC408,
  '8042x' =>  0xFF360A,
  '8052x' =>  0xFF0F14,
  '8062x' =>  0xFC087A,
  '8072x' =>  0xDB03F7,
  '808'   =>  0x26FF7A,
  '809'   =>  0xE8F70F,
  '810'   =>  0xFFAD0F,
  '811'   =>  0xFF2E14,
  '812'   =>  0xFF0F73,
  '813'   =>  0xEB0DC9,
  '814'   =>  0x4069FF,
  '8082x' =>  0x0AFF47,
  '8092x' =>  0xE6ED08,
  '8102x' =>  0xFF940D,
  '8112x' =>  0xFF1A0A,
  '8122x' =>  0xFF083B,
  '8132x' =>  0xED05CC,
  '8142x' =>  0x3047FF,
}; }

1;

=head1 NAME

Graphics::ColorNames::Pantone - RGB values of Pantone colors

=head1 SYNOPSIS

  require Graphics::ColorNames::Pantone;

  $NameTable = Graphics::ColorNames::Pantone->NamesRgbTable();
  $RgbBlack  = $NameTable->{'151'};

=head1 DESCRIPTION

See the documentation of L<Graphics::ColorNames> for information how to use
this module.

This module defines 1091 names and associated RGB values of colors which
are part of a palette created by the I<Pantone Institute> for Designers.
Please not mistake them for the colors of the annual I<Pantone Report>.
To access them use L<Graphics::ColorNames::PantoneReport>.

Pantone names are numbers with three or four digits. Colors from the 
extended palette are marked by an appended I<'2x'> (without space)
(e.g. C<8082x> ).

=head1 SEE ALSO

Pantone Institute L<https://www.pantone.com>

Pantone Colors L<https://www.pantone-colours.com/>

=head1 AUTHOR

Herbert Breunung <lichtkind@cpan.org>

Based on L<Graphics::ColorNames::X> by Robert Rothenberg.

=head1 LICENSE

Copyright 2022 Herbert Breunung

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
