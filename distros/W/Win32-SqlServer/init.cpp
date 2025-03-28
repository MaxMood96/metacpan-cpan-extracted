/*---------------------------------------------------------------------
 $Header: /Perl/OlleDB/init.cpp 20    24-07-17 23:06 Sommar $

  This file holds code that is run when the module initialiases, and
  when a new OlleDB object is created. This file also declares global
  variables that exist through the lifetime of the module. They are
  constants that are set up once and then never changed.


  Copyright (c) 2004-2024  Erland Sommarskog

  $History: init.cpp $
 * 
 * *****************  Version 20  *****************
 * User: Sommar       Date: 24-07-17   Time: 23:06
 * Updated in $/Perl/OlleDB
 * Entirely removed AutoTranslate as an option and it is now considered
 * unknown.
 * 
 * *****************  Version 19  *****************
 * User: Sommar       Date: 24-07-15   Time: 23:52
 * Updated in $/Perl/OlleDB
 * Added new login property ServerCertificate which also can be set
 * through SetDefaultForEncryption.
 * 
 * *****************  Version 18  *****************
 * User: Sommar       Date: 22-05-27   Time: 19:03
 * Updated in $/Perl/OlleDB
 * When looking for encryption option, also filter for the property set,
 * since properties in different set can have the same value.
 * 
 * *****************  Version 17  *****************
 * User: Sommar       Date: 22-05-18   Time: 22:22
 * Updated in $/Perl/OlleDB
 * Added module routine SetDefaultForEncryption to permit changing the
 * default for the lgoin properties Encrypt, TrustServerCertificate and
 * HostNameInCertificate.
 * 
 * *****************  Version 16  *****************
 * User: Sommar       Date: 22-05-08   Time: 23:37
 * Updated in $/Perl/OlleDB
 * For Encrypt option, set is_optional as TRUE, so that provider default
 * can apply.
 * 
 * *****************  Version 15  *****************
 * User: Sommar       Date: 22-05-08   Time: 23:14
 * Updated in $/Perl/OlleDB
 * New OLE DB provider MSOLEDBSQl19. Changed data type for the Encrypt
 * loginu property. New login property HostNameInCertificate, only
 * available with MSOLEDBSQL19.
 * 
 * *****************  Version 14  *****************
 * User: Sommar       Date: 21-07-12   Time: 21:37
 * Updated in $/Perl/OlleDB
 * No longer tracking whether a property is for SQLOLEDB, but instead
 * added a concept of optional properties, to permit adding login
 * properties that are not added by all versions of MSOLEDBSQL. Also added
 * five new login properties to support what MSOLEDBSQL supports.
 * 
 * *****************  Version 13  *****************
 * User: Sommar       Date: 20-01-10   Time: 21:40
 * Updated in $/Perl/OlleDB
 * Bugfix: error code reported as 0 when initialisation failed, making it
 * difficult to diagnose an error.
 * 
 * *****************  Version 12  *****************
 * User: Sommar       Date: 19-07-19   Time: 22:00
 * Updated in $/Perl/OlleDB
 * Removed the olddbtranslate option from internaldata, and entirely
 * deprecated setting the AutoTranslate option to make sure that it always
 * is false. When clearing options when ProviderString is set, we don't
 * clear AutoTranslate.
 * 
 * *****************  Version 11  *****************
 * User: Sommar       Date: 19-07-08   Time: 22:30
 * Updated in $/Perl/OlleDB
 * Made default for AutoTranslate macro. Updated copyright year.
 * 
 * *****************  Version 10  *****************
 * User: Sommar       Date: 18-04-09   Time: 22:49
 * Updated in $/Perl/OlleDB
 * Added support for the new MSOLEDBSQL provider. Added new login propery
 * MultiSubnetFailover, only supported by MSOLEDBSQL.
 * 
 * *****************  Version 9  *****************
 * User: Sommar       Date: 15-05-24   Time: 21:04
 * Updated in $/Perl/OlleDB
 * Updated copyright information.
 * 
 * *****************  Version 8  *****************
 * User: Sommar       Date: 12-09-27   Time: 22:45
 * Updated in $/Perl/OlleDB
 * Updated year in variable $Win32::SqlServer::Version.
 * 
 * *****************  Version 7  *****************
 * User: Sommar       Date: 12-09-23   Time: 22:52
 * Updated in $/Perl/OlleDB
 * Updated Copyright note.
 * 
 * *****************  Version 6  *****************
 * User: Sommar       Date: 12-08-15   Time: 21:27
 * Updated in $/Perl/OlleDB
 * One new login property for SQL 2012 and two new for SQL 2008. Now track
 * the number of properties per version of  the OLE DB provider.
 * 
 * *****************  Version 5  *****************
 * User: Sommar       Date: 12-07-20   Time: 23:50
 * Updated in $/Perl/OlleDB
 * Add support for SQLNCLI11.
 * 
 * *****************  Version 4  *****************
 * User: Sommar       Date: 11-08-07   Time: 23:26
 * Updated in $/Perl/OlleDB
 * Updated copyright message for $VERSION.
 * 
 * *****************  Version 3  *****************
 * User: Sommar       Date: 08-04-30   Time: 22:46
 * Updated in $/Perl/OlleDB
 * Use get_sv and not perl_get_sv (deprecated). Pass GV_ADDMULTI to get_sv
 * to avoid "Used only once" warning. Don't define macro XS_VERSION in the
 * file, as it comes with the Makefile.
 *
 * *****************  Version 2  *****************
 * User: Sommar       Date: 08-01-06   Time: 23:33
 * Updated in $/Perl/OlleDB
 * Replaced all unsafe CRT functions with their safe replacements in VC8.
 * olledb_message now takes a va_list as argument, so we pass it
 * parameterised strings and don't have to litter the rest of the code
 * with that.
 *
 * *****************  Version 1  *****************
 * User: Sommar       Date: 07-12-24   Time: 21:40
 * Created in $/Perl/OlleDB
  ---------------------------------------------------------------------*/

#define _WIN32_DCOM   // Needed for CoInitializeEx

#include "CommonInclude.h"

#include <cguid.h>
#include <msdaguid.h>


#include "convenience.h"
#include "datatypemap.h"
#include "init.h"



#undef FILEDEBUG
#ifdef FILEDEBUG
FILE *dbgfile = NULL;
#endif


// Global variables for class ids for the possible providers.
CLSID  clsid_sqloledb     = CLSID_NULL;
CLSID  clsid_sqlncli      = CLSID_NULL;
CLSID  clsid_sqlncli10    = CLSID_NULL;
CLSID  clsid_sqlncli11    = CLSID_NULL;
CLSID  clsid_msoledbsql   = CLSID_NULL;
CLSID  clsid_msoledbsql19 = CLSID_NULL;

// This global array holds definition of all initialisation properties
// for OLE DB.
init_property gbl_init_props[MAX_INIT_PROPERTIES];

// Number of properties per provider:
int no_of_ssprops_sqloledb     = -1;
int no_of_ssprops_sqlncli      = -1;
int no_of_ssprops_sqlncli10    = -1;
int no_of_ssprops_sqlncli11    = -1;
int no_of_ssprops_msoledbsql   = -1;
int no_of_ssprops_msoledbsql19 = -1;

// This array holds where each property set starts in gbl_init_props;
propset_info_struct init_propset_info[NO_OF_INIT_PROPSETS];


// Global pointer to OLE DB Services. Set once when we intialize, and
// never released.
IDataInitialize * data_init_ptr    = NULL;

// Global pointer the OLE DB conversion library.
IDataConvert    * data_convert_ptr = NULL;

// Global pointer to the IMalloc interface. Most of the time when we allocate
// memory, we rely on the Perl methods. However, there are situations when
// we must free memory allocated by SQLOLEDB. Same here, we create once, as
// the COM implementation is touted as thread-safe.
IMalloc*   OLE_malloc_ptr = NULL;



// A helper routine to get default for APPNAME.
static BSTR get_scriptname () {
   // Get the name of the script, taken from Perl var $0. This is used as
   // the default application name in SQL Server.

   SV* sv;

   if (sv = get_sv("0", FALSE))
   {
      // Get script name into a BSTR.
      BSTR tmp = SV_to_BSTR(sv);
      BSTR scriptname;
      WCHAR *p;

      // But this name is full path, and we want only the trailing bit.
      if (p = wcsrchr(tmp, '/'))
         ++p;
      else if (p = wcsrchr(tmp, '\\'))
         ++p;
      else if (p = wcsrchr(tmp, ':'))
          ++p;
      else
          p = tmp;

      scriptname = SysAllocString(p);
      SysFreeString(tmp);
      return scriptname;
   }
   else {
      return NULL;
   }
}

// And another one to get the default for WSID.
static BSTR get_hostname() {
   BSTR hostname = SysAllocStringLen(NULL, 31);
   memset(hostname, 0, 60);
   GetEnvironmentVariable(L"COMPUTERNAME", hostname, 30);
   return hostname;
}

// Add a property to the global array.
// isoptoinal: properties that were added in a .X version of a provider, or
// options where we want the provider default to apply.
static void add_init_property (const char *  name,
                               init_propsets propset_enum,
                               DBPROPID      propid,
                               BOOL          isoptional, 
                               VARTYPE       datatype,
                               BOOL          default_empty,
                               const WCHAR * default_str,
                               int           default_int,
                               int          &ix)
{

   // Check that we are not exceeding the global array. Note that the last
   // slot must be left unusued, as this is used as a stop condition!
   if (ix >= MAX_INIT_PROPERTIES - 1) {
      croak("Internal error: size of array for init properties exceeded");
   }

   // Increment property set counter.
   init_propset_info[propset_enum].no_of_props++;

   strcpy_s(gbl_init_props[ix].name, INIT_PROPNAME_LEN, name);
   gbl_init_props[ix].propset_enum  = propset_enum;
   gbl_init_props[ix].property_id   = propid;
   gbl_init_props[ix].isoptional    = isoptional;
   gbl_init_props[ix].datatype      = datatype;
   VariantInit(&gbl_init_props[ix].default_value);

   if (! default_empty) {
      gbl_init_props[ix].default_value.vt = datatype;

      switch (datatype) {
         case VT_BOOL :
            gbl_init_props[ix].default_value.boolVal = default_int;
            break;

         case VT_I2 :
            gbl_init_props[ix].default_value.iVal = default_int;
            break;

         case VT_UI2 :
            gbl_init_props[ix].default_value.uiVal = default_int;
            break;

         case VT_I4 :
            gbl_init_props[ix].default_value.lVal = default_int;
            break;

         case VT_BSTR :
               gbl_init_props[ix].default_value.bstrVal = SysAllocString(default_str);
            break;

         default :
            croak ("Internal error: add_init_property was called witn unhandled vartype %d",
                    datatype);
            break;
       }
    }

    // And increase the index.
    ix++;
}

// And this is the routine that sets up the array.
static void setup_init_properties ()
{
   int ix = 0;
   BSTR scriptname = get_scriptname();
   BSTR hostname   = get_hostname();

   // Init array so that all entrys are unused and init propset_info.
   memset(gbl_init_props, not_in_use,
          MAX_INIT_PROPERTIES * sizeof(init_property));


   // DBPROPSET_DBINIT, main OLE DB init and auth properties.
   init_propset_info[oleinit_props].start = ix;
   init_propset_info[oleinit_props].no_of_props = 0;

   add_init_property("IntegratedSecurity", oleinit_props, DBPROP_AUTH_INTEGRATED,
                     FALSE, VT_BSTR, FALSE, L"SSPI", NULL, ix);
   add_init_property("Password", oleinit_props, DBPROP_AUTH_PASSWORD,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("Username", oleinit_props, DBPROP_AUTH_USERID,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("Database", oleinit_props, DBPROP_INIT_CATALOG,
                     FALSE, VT_BSTR, FALSE, L"tempdb", NULL, ix);
   add_init_property("Server", oleinit_props, DBPROP_INIT_DATASOURCE,
                     FALSE, VT_BSTR, FALSE, L"(local)", NULL, ix);
   add_init_property("GeneralTimeout", oleinit_props, DBPROP_INIT_GENERALTIMEOUT,
                     FALSE, VT_I4, FALSE, NULL, 0, ix);
   add_init_property("LCID", oleinit_props, DBPROP_INIT_LCID,
                     FALSE, VT_I4, FALSE, NULL, GetUserDefaultLCID(), ix);
   add_init_property("Pooling", oleinit_props, DBPROP_INIT_OLEDBSERVICES,
                     FALSE, VT_I4, FALSE, NULL, DBPROPVAL_OS_RESOURCEPOOLING, ix);
   add_init_property("Prompt", oleinit_props, DBPROP_INIT_PROMPT,
                     FALSE, VT_I2, FALSE, NULL, DBPROMPT_NOPROMPT, ix);
   add_init_property("ConnectionString", oleinit_props, DBPROP_INIT_PROVIDERSTRING,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("ConnectTimeout", oleinit_props, DBPROP_INIT_TIMEOUT,
                     FALSE, VT_I4, FALSE, NULL, 15, ix);

   // DBPROPSET_SQLSERVERDBINIT, SQLOLEDB specific proprties.
   init_propset_info[ssinit_props].start = ix;
   init_propset_info[ssinit_props].no_of_props = 0;

   add_init_property("Appname", ssinit_props, SSPROP_INIT_APPNAME,
                     FALSE, VT_BSTR, FALSE, scriptname, NULL, ix);
   add_init_property("Autotranslate", ssinit_props, SSPROP_INIT_AUTOTRANSLATE,
                     FALSE, VT_BOOL, FALSE, NULL, NULL, ix);   // This property is not settable by the user, but we also force it as FALSE.
   add_init_property("Language", ssinit_props, SSPROP_INIT_CURRENTLANGUAGE,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("AttachFilename", ssinit_props, SSPROP_INIT_FILENAME,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("NetworkAddress", ssinit_props, SSPROP_INIT_NETWORKADDRESS,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("Netlib", ssinit_props, SSPROP_INIT_NETWORKLIBRARY,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("PacketSize", ssinit_props, SSPROP_INIT_PACKETSIZE,
                     FALSE, VT_I4, TRUE, NULL, NULL, ix);
   add_init_property("UseProcForPrep", ssinit_props, SSPROP_INIT_USEPROCFORPREP,
                     FALSE, VT_I4, FALSE, NULL, SSPROPVAL_USEPROCFORPREP_OFF, ix);
   add_init_property("Hostname", ssinit_props, SSPROP_INIT_WSID,
                     FALSE, VT_BSTR, FALSE, hostname, NULL, ix);
   add_init_property("Encrypt", ssinit_props, SSPROP_INIT_ENCRYPT,
                     TRUE, VT_BSTR, TRUE, NULL, NULL, ix);  // Set as is_optional, to permit for different provider defaults.
   // The above properties are those that are in SQLOLEDB.
   no_of_ssprops_sqloledb = init_propset_info[ssinit_props].no_of_props;

   // These properties were added in SQL 2005.
   add_init_property("FailoverPartner", ssinit_props, SSPROP_INIT_FAILOVERPARTNER,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("TrustServerCert", ssinit_props, SSPROP_INIT_TRUST_SERVER_CERTIFICATE,
                     FALSE, VT_BOOL, TRUE, NULL, NULL, ix);
   add_init_property("OldPassword", ssinit_props, SSPROP_AUTH_OLD_PASSWORD,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   no_of_ssprops_sqlncli = init_propset_info[ssinit_props].no_of_props;

   // These two were added with SQL 2008.
   add_init_property("ServerSPN", ssinit_props, SSPROP_INIT_SERVERSPN,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   add_init_property("FailoverPartnerSPN", ssinit_props, SSPROP_INIT_FAILOVERPARTNERSPN,
                     FALSE, VT_BSTR, TRUE, NULL, NULL, ix);
   no_of_ssprops_sqlncli10 = init_propset_info[ssinit_props].no_of_props;

   // And here is a single one that made it into SQL 2012.
   add_init_property("ApplicationIntent", ssinit_props, SSPROP_INIT_APPLICATIONINTENT,
                     FALSE, VT_BSTR, FALSE, L"ReadWrite", NULL, ix);
   no_of_ssprops_sqlncli11 = init_propset_info[ssinit_props].no_of_props;

   // This one appeared first with the undeprecated driver in 2018.
   add_init_property("MultiSubnetFailover", ssinit_props, SSPROP_INIT_MULTISUBNETFAILOVER,
                     TRUE, VT_BOOL, FALSE, NULL, FALSE, ix);
   add_init_property("AccessToken", ssinit_props, SSPROP_AUTH_ACCESS_TOKEN,
                     TRUE, VT_BSTR, TRUE, NULL, FALSE, ix);
   add_init_property("Authentication", ssinit_props, SSPROP_AUTH_MODE,
                     TRUE, VT_BSTR, TRUE, NULL, FALSE, ix);
   add_init_property("ConnectRetryCount", ssinit_props, SSPROP_INIT_CONNECT_RETRY_COUNT,
                     TRUE, VT_I4, FALSE, NULL, 1, ix);
   add_init_property("ConnectRetryInterval", ssinit_props, SSPROP_INIT_CONNECT_RETRY_INTERVAL,
                     TRUE, VT_I4, FALSE, NULL, 10, ix);
   add_init_property("TransparentNetworkIPResolution", ssinit_props, SSPROP_INIT_TNIR,
                     TRUE, VT_BOOL, FALSE, NULL, FALSE, ix);
   no_of_ssprops_msoledbsql = init_propset_info[ssinit_props].no_of_props;

   // Properties new in MSOLEDBSQL19.
   add_init_property("HostNameInCertificate", ssinit_props, SSPROP_INIT_HOST_NAME_CERTIFICATE,
                     FALSE, VT_BSTR, TRUE, NULL, FALSE, ix);
   add_init_property("ServerCertificate", ssinit_props, SSPROP_INIT_SERVER_CERTIFICATE,
                     FALSE, VT_BSTR, TRUE, NULL, FALSE, ix);
   no_of_ssprops_msoledbsql19 = init_propset_info[ssinit_props].no_of_props;   

   
   // DBPROPSET_DATASOURCE, data-source properties.
   init_propset_info[datasrc_props].start = ix;
   init_propset_info[datasrc_props].no_of_props = 0;

   add_init_property("MultiConnections", datasrc_props, DBPROP_MULTIPLECONNECTIONS,
                     FALSE, VT_BOOL, FALSE, NULL, FALSE, ix);

   SysFreeString(scriptname);
   SysFreeString(hostname);
}

// Above we leave the Encrypt option without a default, to let the provider to decide. But this
// routine permits the user to override.
void SetDefaultForEncryption(SV * sv_Encrypt,
                             SV * sv_Trust,
                             SV * sv_HostName,
                             SV * sv_ServerCert) {
   int    encrypt_ix = -1;
   int    trust_cert_ix = -1;
   int    host_name_ix  = -1;
   int    server_cert_ix = -1;

   // Loop over gbl_init_props to find the indexes for the Encrypt and TrustServerCert options
   for (int ix = 0; 
            ix < MAX_INIT_PROPERTIES && 
                 (encrypt_ix < 0 || trust_cert_ix < 0 || 
                  host_name_ix < 0 || server_cert_ix < 0); ix++) {
      if (gbl_init_props[ix].propset_enum == ssinit_props) {
         if (gbl_init_props[ix].property_id == SSPROP_INIT_ENCRYPT) {
            encrypt_ix = ix;
         }
         else if (gbl_init_props[ix].property_id == SSPROP_INIT_TRUST_SERVER_CERTIFICATE) {
            trust_cert_ix = ix;
         }
         else if (gbl_init_props[ix].property_id == SSPROP_INIT_HOST_NAME_CERTIFICATE) {
            host_name_ix = ix;
         }
         else if (gbl_init_props[ix].property_id == SSPROP_INIT_SERVER_CERTIFICATE) {
            server_cert_ix = ix;
         }
      }
   }

   // Sanity check.
   if (encrypt_ix == -1 || trust_cert_ix == -1 || host_name_ix == -1 || server_cert_ix == -1) {
      croak("Internal error! Was not able to set encrypt_ix(%d), trust_cert_ix(%d), host_name_ix(%d) or server_cert_ix(%d)!\n", 
            encrypt_ix, trust_cert_ix, host_name_ix, server_cert_ix);
   }
   
   // Handle Encrypt option
   if (sv_Encrypt && SvOK(sv_Encrypt)) {
      char * setting = SvPV_nolen(sv_Encrypt);

      if (strcmp("Optional", setting) == 0 || 
          strcmp("Mandatory", setting) == 0 || 
          strcmp("Strict", setting) == 0) {

         gbl_init_props[encrypt_ix].isoptional = FALSE;
         gbl_init_props[encrypt_ix].default_value.vt = VT_BSTR;
         gbl_init_props[encrypt_ix].default_value.bstrVal = SV_to_BSTR(sv_Encrypt);
      }
      else {
         warn("SetDefaultForEncrypt: Illegal value for encrypt option: '%s'.\n", setting);
         croak("Permitted values are undef, 'Optional', 'Mandatory', and 'Strict'.\n");
      }
   }
   else {
      gbl_init_props[encrypt_ix].isoptional = TRUE;
      VariantClear(&gbl_init_props[encrypt_ix].default_value);
   }

   // Handle default for TrustServerCertificate.
   if (sv_Trust && SvOK(sv_Trust)) {
      gbl_init_props[trust_cert_ix].isoptional = FALSE;
      gbl_init_props[trust_cert_ix].default_value.vt = VT_BOOL;
      gbl_init_props[trust_cert_ix].default_value.boolVal = 
           (SvTRUE(sv_Trust) ? -1 : FALSE);
   }
   else {
      gbl_init_props[trust_cert_ix].isoptional = TRUE;
      VariantClear(&gbl_init_props[trust_cert_ix].default_value);
   }

   // And host name in certificate.
   if (sv_HostName && SvOK(sv_HostName)) {
      gbl_init_props[host_name_ix].isoptional = FALSE;
      gbl_init_props[host_name_ix].default_value.vt = VT_BSTR;
      gbl_init_props[host_name_ix].default_value.bstrVal = SV_to_BSTR(sv_HostName);
   }
   else {
      gbl_init_props[host_name_ix].isoptional = TRUE;
      VariantClear(&gbl_init_props[host_name_ix].default_value);
   }

   // Finally, server certificate.
   if (sv_ServerCert && SvOK(sv_ServerCert)) {
      gbl_init_props[server_cert_ix].isoptional = FALSE;
      gbl_init_props[server_cert_ix].default_value.vt = VT_BSTR;
      gbl_init_props[server_cert_ix].default_value.bstrVal = SV_to_BSTR(sv_ServerCert);
   }
   else {
      gbl_init_props[server_cert_ix].isoptional = TRUE;
      VariantClear(&gbl_init_props[server_cert_ix].default_value);
   }

}


//---------------------------------------------------------------------
// Initialization and finalization.
//--------------------------------------------------------------------

//-------------------------------------------------------------------
// Windows calls DllMain the DLL is (un)loaded. We need a critical
// section in initialize (which is called by Perl on use of the module),
// so that only the first process sets up the global structures.
//-------------------------------------------------------------------
static CRITICAL_SECTION CS;

BOOL WINAPI DllMain(
  HINSTANCE hinstDLL,     // handle to the DLL module
  DWORD    fdwReason,     // reason for calling function
  LPVOID   lpvReserved)   // reserved
{
  switch (fdwReason) {
     case DLL_PROCESS_ATTACH:
        InitializeCriticalSection(&CS);
        break;
     case DLL_PROCESS_DETACH:
        DeleteCriticalSection(&CS);
        break;
     default:
        break;
  }
  return TRUE;
}

// Called when a Perl script says C<use Win32::SqlServer>.
void initialize ()
{
   SV *sv;
   DWORD       err;
   HRESULT     ret = S_OK;
   char      * obj;

   // In the critical section we create our starting point, the pointer to
   // OLE DB services. We also create a pointer to a conversion object.
   // Thess pointer will never be released.
   EnterCriticalSection(&CS);

   // Get classIDs for the possible providers.
   if (IsEqualCLSID(clsid_sqloledb,     CLSID_NULL) &&
       IsEqualCLSID(clsid_sqlncli,      CLSID_NULL) &&
       IsEqualCLSID(clsid_sqlncli10,    CLSID_NULL) && 
       IsEqualCLSID(clsid_sqlncli11,    CLSID_NULL) &&
       IsEqualCLSID(clsid_msoledbsql,   CLSID_NULL) &&
       IsEqualCLSID(clsid_msoledbsql19, CLSID_NULL)) {

      ret = CLSIDFromProgID(L"SQLOLEDB", &clsid_sqloledb);
      if (FAILED(ret)) {
         clsid_sqloledb = CLSID_NULL;
      }

      ret = CLSIDFromProgID(L"SQLNCLI", &clsid_sqlncli);
      if (FAILED(ret)) {
         clsid_sqlncli = CLSID_NULL;
      }

      ret = CLSIDFromProgID(L"SQLNCLI10", &clsid_sqlncli10);
      if (FAILED(ret)) {
         clsid_sqlncli10 = CLSID_NULL;
      }

      ret = CLSIDFromProgID(L"SQLNCLI11", &clsid_sqlncli11);
      if (FAILED(ret)) {
         clsid_sqlncli11 = CLSID_NULL;
      }

      ret = CLSIDFromProgID(L"MSOLEDBSQL", &clsid_msoledbsql);
      if (FAILED(ret)) {
         clsid_msoledbsql = CLSID_NULL;
      }

      ret = CLSIDFromProgID(L"MSOLEDBSQL19", &clsid_msoledbsql19);
      if (FAILED(ret)) {
         clsid_msoledbsql19 = CLSID_NULL;
      }
   }

   if (OLE_malloc_ptr == NULL)
      CoGetMalloc(1, &OLE_malloc_ptr);

   if (data_init_ptr == NULL) {
      CoInitializeEx(NULL, COINIT_MULTITHREADED);

      ret = CoCreateInstance(CLSID_MSDAINITIALIZE, NULL, CLSCTX_INPROC_SERVER,
                             IID_IDataInitialize,
                             reinterpret_cast<LPVOID *>(&data_init_ptr));

      if (SUCCEEDED(ret)) {
         // Fill the type map and the default login properties here.
         fill_type_map();
         setup_init_properties();

#ifdef FILEDEBUG
         // Open debug file.
         if (dbgfile == NULL) {
            dbgfile = _wfopen(L"C:\\temp\\ut.txt", L"wbc");
            fprintf(dbgfile, "\xFF\xFE");
         }
#endif
      }
      else {
         obj = "IDataInitialize";
         err = GetLastError();
      }
   }


   if (SUCCEEDED(ret) && data_convert_ptr == NULL) {
      ret = CoCreateInstance(CLSID_OLEDB_CONVERSIONLIBRARY,
                             NULL, CLSCTX_INPROC_SERVER,
                             IID_IDataConvert,
                             (void **) &data_convert_ptr);
      if (FAILED(ret)) {
         obj = "IDataConvert";
         err = GetLastError();
      }
   }

   LeaveCriticalSection(&CS);

   if (FAILED(ret)) {
      warn("Could not create '%s' object: err: %d, ret: %d", obj, err, ret);
      warn("This could be because you don't have the MDAC on your machine,\n");
      warn("or an MDAC version you have is too arcane and not supported by\n");
      croak("Win32::SqlServer, which requires MDAC 2.6\n");
   }

   // Set Version string.
   if (sv = get_sv("Win32::SqlServer::Version", GV_ADD | GV_ADDMULTI))
   {
        char buff[256];
        sprintf_s(buff, 256,
                  "This is Win32::SqlServer, version %s\n\nCopyright (c) 2005-2019 Erland Sommarskog\n",
                  XS_VERSION);
        sv_setnv(sv, atof(XS_VERSION));
        sv_setpv(sv, buff);
        SvNOK_on(sv);
   }
}


// Returns the number of properties in the SSPROP structure for the 
// given provider.
int no_of_ssprops(provider_enum provider) {
   switch (provider) {
      case provider_sqloledb     : return no_of_ssprops_sqloledb;
      case provider_sqlncli      : return no_of_ssprops_sqlncli;
      case provider_sqlncli10    : return no_of_ssprops_sqlncli10;
      case provider_sqlncli11    : return no_of_ssprops_sqlncli11;
      case provider_msoledbsql   : return no_of_ssprops_msoledbsql;
      case provider_msoledbsql19 : return no_of_ssprops_msoledbsql19;
      default :
         croak("Internal error: Unexpected value %d passed to no_of_ssprops");
         return 0;
   }
}

// This routine returns the default provider, which is highest version of
// SQL Native Client/SQLOLEDB that is installed.
provider_enum default_provider(void) {
  if (! IsEqualCLSID(clsid_msoledbsql19, CLSID_NULL))
      return provider_msoledbsql19;
  else if (! IsEqualCLSID(clsid_msoledbsql, CLSID_NULL))
      return provider_msoledbsql;
  else if (! IsEqualCLSID(clsid_sqlncli11, CLSID_NULL))
      return provider_sqlncli11;
  else if (! IsEqualCLSID(clsid_sqlncli10, CLSID_NULL))
      return provider_sqlncli10;
  else if (! IsEqualCLSID(clsid_sqlncli, CLSID_NULL))
      return provider_sqlncli;
  else
      return provider_sqloledb;
}

