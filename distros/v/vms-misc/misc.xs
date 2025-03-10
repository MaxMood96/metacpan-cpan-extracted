/* A set of general purpose routines to do stuff that doesn't fit anyplace */
/* else. */

#ifdef __cplusplus
extern "C" {
#endif
#include <starlet.h>
#include <descrip.h>
#include <time.h>
  
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif


unsigned long CVT$CONVERT_FLOAT(void    *input_value, 
                                unsigned long input_type, 
                                void    *output_value, 
                                unsigned long output_type, 
                                unsigned long options); 
 
globalvalue CVT$K_VAX_G; 
globalvalue CVT$K_IEEE_T; 
globalvalue CVT$K_IEEE_X; 
globalvalue CVT$M_ROUND_TO_NEAREST; 
globalvalue CVT$_NORMAL; 
 
MODULE = VMS::Misc		PACKAGE = VMS::Misc		
PROTOTYPES: ENABLE

SV *
byte_to_iv(DataConv)
     SV *DataConv;
   PPCODE:
     char *PVPointer;
     char DataToConvert;
     
     PVPointer = SvPV(DataConv, PL_na);
     DataToConvert = PVPointer[0];
     
     XPUSHs(sv_2mortal(newSViv((I32) DataToConvert)));

SV *
word_to_iv(DataConv)
     SV *DataConv;
   PPCODE:
     short *PVPointer;
     short DataToConvert;

     PVPointer = (short *)SvPV(DataConv, PL_na);
     DataToConvert = *PVPointer;
     
     XPUSHs(sv_2mortal(newSViv((I32) DataToConvert)));


SV *
long_to_iv(DataConv)
     SV *DataConv;
   PPCODE:
     long *PVPointer;
     long DataToConvert;

     PVPointer = (long *)SvPV(DataConv, PL_na);
     DataToConvert = *PVPointer;
     
     XPUSHs(sv_2mortal(newSViv((I32) DataToConvert)));

SV *
quad_to_date(DataConv)
     SV *DataConv;
   PPCODE:
     char *PVPointer;
     char QuadWordBuffer[8];
     char ConvertedDate[255];
     unsigned int ConvertedDateLen = 255;     
     struct dsc$descriptor_s TimeStringDesc;
     int Status;

     PVPointer = SvPV(DataConv, PL_na);
     Copy(PVPointer, QuadWordBuffer, 8, char);
     Zero(ConvertedDate, 255, char);
     
     /* Fill in the time string descriptor */
     TimeStringDesc.dsc$a_pointer = ConvertedDate;
     TimeStringDesc.dsc$w_length = ConvertedDateLen;
     TimeStringDesc.dsc$b_dtype = DSC$K_DTYPE_T;
     TimeStringDesc.dsc$b_class = DSC$K_CLASS_S;
     
     Status = sys$asctim(NULL, &TimeStringDesc, QuadWordBuffer, 0);
     if (Status != SS$_NORMAL) {
       croak("Bogus date!");
     }

     /* Make sure there's a leading zero */
     if (ConvertedDate[0] == ' ') {
       ConvertedDate[0] = '0';
     }
     
     XPUSHs(sv_2mortal(newSVpv(ConvertedDate, 0)));

SV *
date_to_quad(DataConv)
     SV *DataConv;
   PPCODE:
     char *PVPointer;
     char QuadWordBuffer[8];
     char StringDate[255];
     unsigned int DateLen;     
     struct dsc$descriptor_s TimeStringDesc;
     int Status;

     PVPointer = SvPV(DataConv, DateLen);
     Copy(PVPointer, StringDate, DateLen, char);
     
     /* Fill in the time string descriptor */
     TimeStringDesc.dsc$a_pointer = StringDate;
     TimeStringDesc.dsc$w_length = DateLen;
     TimeStringDesc.dsc$b_dtype = DSC$K_DTYPE_T;
     TimeStringDesc.dsc$b_class = DSC$K_CLASS_S;
     
     Status = sys$bintim(&TimeStringDesc, QuadWordBuffer);
     if (Status != SS$_NORMAL) {
       croak("Bogus date!");
     }
     
     XPUSHs(sv_2mortal(newSVpv(QuadWordBuffer, 8)));

SV *
vms_date_to_unix_epoch(DataConv)
     SV *DataConv
   PPCODE:
     char *PVPointer;
     char QuadWordBuffer[8];
     char ConvertedDate[255];
     unsigned int ConvertedDateLen = 255;     
     struct dsc$descriptor_s TimeStringDesc;
     struct tm TimeBuff;
     time_t EpochSecs;
     int Status;

     PVPointer = SvPV(DataConv, PL_na);

     strptime(PVPointer, "%d-%B-%Y %T", &TimeBuff);
     EpochSecs = mktime(&TimeBuff);
     XPUSHs(sv_2mortal(newSViv(EpochSecs)));

SV *
nv_to_64_bit_ieee_str(DataConv)
     SV *DataConv;
   PPCODE:
     char out_buf[8];
     NV temp_float;
     int from_type;
     int status;

     temp_float = SvNV(DataConv);
     if (sizeof(temp_float) == 8) {
       from_type = CVT$K_VAX_G;
     } else {
       from_type = CVT$K_IEEE_X;
     }

     status = CVT$CONVERT_FLOAT(&temp_float, from_type, out_buf,
				CVT$K_IEEE_T, 0);

     if (CVT$_NORMAL == status) {
       XPUSHs(sv_2mortal(newSVpv(out_buf, 8)));
     } else {
       croak("Conversion failed!");
     }
   
                                                                                                                                                                                                                                                                                                                                                                               MIMAGEBASEDPROJECTSOLICITATIOND OFFICEIECE ENSEMBLEMAKOLAYER MULTIPLAYEROINT ADVANTAGEGREEMENTCLEMSONLEADNIGHTREDUCTIONVICTORYRT POWEREDUND RETAILRONG PLANWIDEED APPROACHTTACKEMAILSTRATEGYUTT BIRDIEOGEYDOUBLEED FORROMTOING FROMQUARTER TRENDRANKED GOGUIDED AROUNDEK CEOUN COMBINEDDOUBLETIMESEAMER CHANGEUPSON PERIODT CESSNAER LASTONCOND ONLINEHIFT BASISPEROT EDGELEADSWINGVACCINATIONIDED ONETE SIMULCASTOME JOSHTHEPEED GELATOSWITCHINGOTTED PALMTAGE AMPLIFIERAIDEDBIDDINGCURRENTFORMATRATEEDUCTIONTRANSACTIONR EVENTFRENCHRATINGEP ACQUISITIONPPROACHCERTIFICATIONREGISTRATIONOUNDSEALEDOURCEPINTRANSACTIONOREY CARENTERTAINMENTLOCATIONY 360ROOMBUILDINGCREWELEVATORHOMEUSEPINEAPPLESTATETRAININGWAREHOUSEOODENRAP BACKPACKOKE ADVANTAGENDBUSINESSDEFICITENGINELEADPENALTYVICTORYUPPLIER STRUCTURETENTH OFRABYTE NCRM CLAUSEDIRECTORGOVERNORPRESIDENCYTTEXAHIRD 63569ALLNDBEINGLOWYCANNOTOMPLETEDISAPPROVEFEELORROMHAVEINTERESTMAJORITYICROSOFTNOWWNERRELATEDSAIDYCORELESSINCEUBSTANTIALLYPPORTTHEISOVOTEWASEITHOUSAND WASREE KILOMETERTIMEICK RANGEER DISTRIBUTIONMARKETONERTOWAGEED ADOPTIONPRICINGOGRAMMOTIONALSERYVESTINGME 500ACADEMYLLAMERICANSTARMERICANUSTRALIANVERAGECHAMPIONINESEOPENHAGENDAYTONAEFENDINGEUROPEANFINALISTORBEMERGOLDRAMMYNDMVPNATIONALOLYMPICSCARPLAYERRESIDENTIALORACEEIGNINGOWINGSERYTOURVICTORWINNERORLDO THREEPARTYNE BALLCOMBINATIONLEATHERORANGESILVERD GREENWER CLASSRACK VOLUNTARYIN EXPANSIONLNGUNDER 142SER LICENSEVOLUME HISTORYTE LOSSWAR ASSUMPTIONY ACCESSLERTINGWAYSONNDNUALROUNDUTHENTICATIONBENEFITILATERALRIDGEOADBANDCABLEPACITYOLLABORATIONMMUNICATIONNNECTORTACTVERSATIONALDATAELIVERYVICEIRECTEARTHNACTEDVENTXCHANGETERNALFIXEDLOWMHFCIGHSPEEDIMNSTANTTEGRATIONRACTIONVEITYLEAVINGNETMEDIUMSSAGINGICROWAVERROROBILEVEMENTOPERATIONALPAGERINGRTICIPATIONERSONALIZEDLAYROCESSDUCTRADIOEADYLATIONSHIPSATELLITEECURITYRVERICEHORTIDEMSTREETYMMETRICALNCHRONIZATIONSTEMTELECOMMUNICATIONNFERENCEXTMESSAGINGIERADEINGFFICNSFERENCEMISSIONUNITSERVHFIDEOOICEANDSATWIRELESSTRIV ANDV COMEEK ABSENCEGOBREAKCAMPAIGNLOSINGOMPAIGNLIMENTARYUTERNDITIONINGDEADLINEENGLISHVENTXERCISEFAIRILMHAWAIIOSPITALINTEGRATIONVESTIGATIONJOURNEYSLAYOFFONGWMARCHONEYZARTONAIRVERSEAPAIDERIODILOTRODUCTIONREIGNSIDENCYUNSEARCHMINARSSIONHUTDOWNLOTTAYRIKEUSPENSIONTESTOURREATMENTKIPULTIMATUMVISITOLUNTEERHEEL ORIN IMPROVEMENTWORLDWIDEYARD RUNEAR 1.680MILLION3005.75006.05ABSENCEGREEMENTLEXALMALENDPPLICATIONOINTMENTROPRIATIONRREARVERAGEBANROOKINGCASHHARTOLLEGEMMITMENTNSTRUCTIONTRACTURSETSHIPUSTOMDEALCLINEEARTHQUAKEVALUATIONXEMPTIONPOSURETENSIONFEDERALINANCINGRMREEGENERALRACEHIATUINITIATIVETERNATIONALJAILLAYOFFICENSINGFETIMEMITEDOSSWMASTERULTINATIONWIDEONTRANSFERABLETEOFFERLDNLINEPERATINGONPEACENALTYRFORMANCEIODILOTLANROCESSUREMENTGRAMMINGJECTUBLICRCHASEQUESTRCECESSIONORDDEMPTIONUCTIONLATIONSHIPNEWABLESEARCHRVEUNNINGSALARYCHOOLENTENCERVICEHARETANDARDRETCHUDYUSPENSIONTALKEACHINGCHNOLOGYLEVISIONRMSTINGORANSFORMATIONEASURYVETERANWARRANTYORKINGZONE TWOCOMMUNITYP ATHASKEPTR AMEXNNOUNCEDCROWNNYSESHAREWEDENTODAYWERA MODIFIEDSOLICITATIONI AOFTRENDWESTS INCVE INDEXT ARTICLECOMNFIDENTIALPUBLISHEFT OURTHEY HTTPNASDAQTELEWESTUNDERV TEKWERKT NASDAQA ANDUNDERC ANYSETIMEE ANNOUNCEDCONTACTONSTATEDLECOM COMI 11.00HTTPLEHMANNYSEOSYMBOLTHIRDODAYR 18.13UMASI ONW AISX ANDNOTAVAILYSETIMEYLA ZINKTECHNICIANVER CEOX 011.3011823586138469179424573170.3PK3.94.07.889.6224738447.2524389503110929377008012022733163083804565075000601012342610571101074820300610561822186426931127468442454407707002275676037992301477879059390181504525216263553523652534044909018441968270425415953216772960271308388.87972ACCORDINGREEROXCHANGEJOINGTECHLLMYNADARKODNOUNCEDREATBAELTIMORERCODINGSEDEAUMONTROOKLINECALLERTIMERPATSKYEARNINGSTRATEGYSPERTEGORYIONENTRALHICAGOITYXPRESSOLORADONTRACTORURRENTYNETDALLATEELNVERIDRIVERYNCORPEGYEFWLTHERNETOBRTGOSROUPHAGERSTOWNSEALTHVISIONRITAGETMIBMDCFLLUMINETMMEDIATELYNDIANAPOLISUSTRYSPECTIONSJOHNKANSAIMBERLYCLARKLASERTECHEXINGTONITTLEOCALKHEEDUMINEXMADDJORITYLTARCHSTERTTHEWYODIFIEDRNINGSUUNDAYNASDAQTIVEEWICOLERCOCXNEPENTHERPANTHERFORMANCEINNACLELATFORMOINTWERRIORVIDEQTYRALEIGHECEIVEDMAINPQUIREDSEARCHOSEMARIEXSCHOOLEATTLENRVEICEVENHREVEPORTIGNALMEOLICITATIONUTIONPANISHTARLINKPLEXOCKTONUMMARYWITCHINGTCNECHNOLOGYRRYXAHEISMOLDRANSFUSIONMITVUNITEDVERSITYSTILVISITTWASYNEEREHEELCHAIRNICHITHIN00032 0101 RESPONSE102SP EXAMINELOOK2038ZZ SOLICITATION1 LOOP9 SERY2038ZZ THE40 MEDIAA LIMITEDETHEWASHOB NASDAQTEXAODAYASED VALEROC COMOBC ANNOUNCEDNYSETODAYRANSWITCHI ISO ANNOUNCEDCOMFORWARDLOOKINGHASPRESIDENTSECURITYOLDEXA PFORESTSERVICE TAMUR RHEALTHVISION ORCHARDI NYSETEXAKIMBERLY CLARKL CREATEDTMUNWHICHEGION ORGTXLEGIONM NASDAQTREXN ANDBASEDROADCOMDOWNGRADINGHASINSMORETOROLANASDAQONTHERREVISINGTEXAHEIMEWERES ISSERYTACTION NOTICEUMMARY NOTICETHEISANDSHTTPISORSCPTUSINGU 214ANDBOARDCOMMUNICATIONRPDELIVEREDISONLECTRICNERGYUROPEHASISNYSEOFFERPANTELLORICEWATERHOUSECOOPEROVIDESAIDTEXAHEURLCOM COMSA PY 1COBBDANJUMAETMERGMIRECTORGENERALGEORGEHVYLUNDMOOREPARTENRAUBERVSHEPPARDINETHEBINGHAMGROUPRIPPET1 22 CONTRACTE CONTRACT2K CONTRACT34 CONTRACT40 THE88 CONTRACTAB CEOGI MMKOWY ATCELLLOCTCOMPUTERDIRECTLYHASLAUNCHETHESEWASSNO SUDARTOBO WESTC ISLSENSAIDO 561ALSOMPNDRECLAIMOMDEALOEELECTRONICNDFELTIREHASEALTHCAREYPHENATEINTERNATIONAL       �Y          	      �   ��  ��         	 	 �          	      �   Y  ��          
 �t          	 ś          	 iV           iV          
 E�           zu      	         �      �_  c)  �/  �c  �e          	      �   �D  ?m          	 ��          
 ��          
      �   S  nc          	
      �
   �A  �\  ]  �]  �`  bj  �m  �o  r  h�                �   �i  ?m  �y  /|           �P         	 	B�          	 ��           Ρ           �Z           ��               �      �  �       �)          	 �)          	      �   �  �)          	 �)          
      �   G  [�  ��  �           �H                �   �:  ��                �   f  ~           J�           R�           �           �}          	 /�                �      �  �d  ��  %�       C          	      �   �9  �:           ��           �c           �F          	 *U          	      �   vI  �J           �           Zn           �6           �.                �   �b  �u         	  �          
 �8           :          	      �   :  �H         
 	          
 
      �   ֟  ,�  �      	 ��          	 �           �          	 1{          	 \           i-           �r          	 ��            S�           �           .L          
 �          	 qL          	      �   �  �L  �L  �]  �      	 �+         	 	 �"          	 rN         
       �   o  �         
  <h         	  B(           B(           ;]                �   8'  �)  �t            �    r  A�                �   "  �  �  �  %�     
       �   �^  �^  .�  h�          	 �           �                �   {  �  HQ  �           ع          
 *�           |           Yo           Y1           ��           a~           ��           PK      
          �   �L  \M  @N  b  �  ˱  ��       �N         
  qL           P           i          
 �9           ��         
       �   c9  �:          	      �   c9  �:           !�      	         �      �N  GN  �O  �W  !�           �           Y]           ^�           �{                �   ��  ��           V�           <h         	 	 <h         
  �6           $W           $W          	 ��          	 $W          	 ��          	 �          
 �          	      �   ��  ј  ��       �           �           ��           #          	 �;           B�      	           �   ,;  2;  �p  �p  �y  ��                �   ơ  ��          	 �           ��          	 �;          	 |           ��           �]          
 �+          
 �l                �   �I  �K  �L  eM          	 �?           �?          	 �U          	 �          	 �	          	      �   Q  [�  �       �R         	 	 �A          	 ��          	      �   �;  AW         	 	 )q          
 ��           ��           �L           _          
 _          
 �          
      �   _  �_  �{  	    
      ��                                                                                                                                                                                                                                                   �#                       iq\; ~      NEWS.BAK                       M    [NEWS2DB]CYBER_TEXTWP08.L45;1                                                                                                      �                        � |     Sq            �M  �  �N  �N  ]�          
      �   �  ]�          
      �   Y�  &�  �  *�           �<           DE         
  h�           U5                �   ԏ  ڏ                �   �_  �b         
  S           bg                �   �^  �`  ��       �          
 (          
 q�          
  �          	 &          
 �@          
      �   }Q  �X  �]  ۟          	 �&           �C          
 Q          	 &           o          
 3�         
 	 ��          	 8K          
 �*          
      �   �=  �a          	      �   +E  v[          	 {8                �   ��  ��          	      �   �  �?  <�  ̜          
 �'          	      �   ߖ  u�      �     �     �   �   �H  Yf  @�  >  D  �  �    {  �	  �	  �	  
  

  �
  �
  �  �  �  ~  �  !  �  
  �  �  �  ~  -  �      �  �  �!  �!  A"  �$  �%  �(  )  {*  Z*  q*  �*  \+  r+  ,  M0  �1  .  M/  _/  �/  �3  �4  5  �8  �8  :  :  ;:  H:  �:  g>  :@  �@  �@  D  vD  �E  PF  OF  �F  �F  �G  H  �I  8K  SK  <M  �M  �N  �N  �N  O  Q  R  [S  �T  V  X  X  Y  uY  _\  \  \  i^  m^  _  R_  _  �`  �b  d  �g  �h  �h  Dj  �k  2l  el  �m  Wo  �o  Vp  �t  �t  �u  �v  �w  �w  ;x  Rx  z  �{  �}  �~  �  ��  ҃  .�  $�  f�  b�  �  Ԉ  ��  T�  <�  k�  �  .�  Đ  �  �  ��  ��  ו  a�  ��   �  ��  ��  ��  E�  K�  ϟ  �  �  ¡  ��  .�  ��  4�  ݫ  ]�  Ŭ  �  2�  ��  ��  ̰  _�  Ǳ  ��  b�  ��  N�  '�  η  ��  ܸ  �          
 ��          	 �h          	 �                �   ��  "�          
 �u          
 c          
      �   ߖ  u�           rq          	 &           F�          
      �   �P  eT  6      	      �   ?0  U5  �u  �  N�      	      �   ;:  �:          
 �          
      �   Am  Lm  �o     
  �           \(          	      �   ��  5�         	  ��                �   �  ��                �   ��  ��  	�       �          	 �           W/                �   �  ��           �=          
 zY                �   �|  '�  h�  Ђ           :h          
 �z          
      �   N4  O4                �   �O  -]  �  /�           �      
    	      �   r,  $-  c2  �/  ZA  �^  ��            �   r,  ZA                �   $-  c2  �/  �^  ��      	 
         	 	 �o          	 L�                �   V  �b  ݯ      
 *�         	 	 �Q                �   �)  SL  �L  V  �p  A�  �  7�          	      �   \/  ��           7O           �D          	 �<           �.                �   �s  ��  �  є          	      �    m  ��           �r                     