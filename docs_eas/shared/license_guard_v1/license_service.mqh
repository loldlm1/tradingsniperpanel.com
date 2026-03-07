//+------------------------------------------------------------------+
//|                      Shared License Guard Service (v1)           |
//+------------------------------------------------------------------+
#ifndef _SERVICES_SHARED_LICENSE_GUARD_V1_LICENSE_SERVICE_MQH_
#define _SERVICES_SHARED_LICENSE_GUARD_V1_LICENSE_SERVICE_MQH_

#include "license_guard_profile.mqh"

#ifdef LICENSE_SHARED_ENFORCEMENT_ENABLED
#ifndef LICENSE_ENFORCEMENT_ENABLED
#define LICENSE_ENFORCEMENT_ENABLED
#endif
#endif

#ifdef LICENSE_SHARED_DAILY_RESULTS_ENABLED
#ifndef LICENSE_DAILY_RESULTS_ENABLED
#define LICENSE_DAILY_RESULTS_ENABLED
#endif
#endif

#ifdef LICENSE_DAILY_RESULTS_ENABLED
#ifndef LICENSE_ENFORCEMENT_ENABLED
#undef LICENSE_DAILY_RESULTS_ENABLED
#endif
#endif

#ifndef LICENSE_SERVICE_TIMER_SECONDS
#define LICENSE_SERVICE_TIMER_SECONDS 60
#endif

bool   g_ea_removal_requested             = false;
bool   g_ea_removal_preserve_chart_error  = false;
string g_ea_removal_chart_message         = "";

void EALifecycleRequestRemoval(const string chart_message,
                               const bool preserve_chart_error = true)
{
  g_ea_removal_requested            = true;
  g_ea_removal_preserve_chart_error = preserve_chart_error;
  g_ea_removal_chart_message        = chart_message;
}

bool EALifecycleHasPendingRemoval()
{
  return g_ea_removal_requested;
}

bool EALifecyclePreserveErrorObject()
{
  return g_ea_removal_preserve_chart_error;
}

string EALifecycleRemovalMessage()
{
  return g_ea_removal_chart_message;
}

void EALifecycleClearRemovalRequest()
{
  g_ea_removal_requested            = false;
  g_ea_removal_preserve_chart_error = false;
  g_ea_removal_chart_message        = "";
}

string LicenseSharedRemovalPrefix()
{
  return LICENSE_SHARED_PROFILE_NAME + " removed: ";
}

string LicenseServiceBuildRemovalMessage(const string fallback_message)
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  string error_code = license_last_error;
  StringToLower(error_code);

  string prefix = LicenseSharedRemovalPrefix();
  if(error_code == "request_failed")
    return prefix + "license server connection failed.";
  if(error_code == "expired" || error_code == "license_not_found")
    return prefix + "license expired.";
  if(error_code == "addons_required")
    return prefix + "required addon entitlement missing.";
  if(error_code == "invalid_key" || error_code == "invalid_source")
    return prefix + "license validation failed.";
  if(error_code == "missing_magic_number" || error_code == "invalid_magic_number")
    return prefix + "backend magic number validation failed.";
  if(error_code == "online_limit_reached")
    return LicenseFriendlyOnlineLimitMessage();
  if(error_code == "invalid_granted_addons" || error_code == "invalid_expires_at")
    return prefix + "invalid license response.";

  if(license_last_http_status >= 500)
    return prefix + "license server unavailable.";

  if(error_code != "")
    return prefix + "license error (" + error_code + ").";
#endif

  if(fallback_message != "")
    return fallback_message;

  return LicenseSharedRemovalPrefix() + "license validation failed.";
}

#ifdef LICENSE_ENFORCEMENT_ENABLED
#include "../../Bcrypt.mqh"
#include "license_guard_online.mqh"
#ifdef LICENSE_DAILY_RESULTS_ENABLED
#include "daily_results_online.mqh"
#endif
#else
bool is_testing = false;
string license_addons = "";
#endif

int LicenseServiceTimerSeconds()
{
  return LICENSE_SERVICE_TIMER_SECONDS;
}

bool LicenseServiceInit()
{
  is_testing = (MQLInfoInteger(MQL_TESTER) > 0);

#ifdef LICENSE_ENFORCEMENT_ENABLED
  if(StringLen(LicenseGetRequestedAddonsCsv()) == 0 &&
     StringLen(LICENSE_SHARED_REQUIRED_ADDONS_CSV) > 0)
  {
    LicenseSetRequestedAddonsCsv(LICENSE_SHARED_REQUIRED_ADDONS_CSV);
  }
#endif

#ifndef LICENSE_ENFORCEMENT_ENABLED
  Print("[License] Enforcement disabled at compile-time. Online validation/reporting skipped.");
  return true;
#else
  if(!VerifyLicense())
  {
    if(LicenseLastFailureWasStartupOnlineLimit())
    {
      Print("[License] Startup verification failed with online_limit_reached. Requester chart removed.");
      EALifecycleRequestRemoval(LicenseFriendlyOnlineLimitMessage());
      return false;
    }

    if(license_last_http_status > 0)
      PrintFormat("[License] Startup verification failed (HTTP %d, error=%s).",
                  license_last_http_status,
                  (license_last_error == "" ? "unknown" : license_last_error));
    else
      PrintFormat("[License] Startup verification failed (error=%s).",
                  (license_last_error == "" ? "request_failed" : license_last_error));
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return false;
  }

#ifdef LICENSE_DAILY_RESULTS_ENABLED
  DailyResults_ResetRuntime();
#endif
  return true;
#endif
}

void LicenseServiceOnTimer()
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  LicenseOnline_OnTimer();
#ifdef LICENSE_DAILY_RESULTS_ENABLED
  DailyResults_OnTimer();
#endif
#endif
}

void LicenseServiceOnDeinit()
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  LicenseOnline_OnDeinit();
#endif
}

#ifndef LICENSE_ENFORCEMENT_ENABLED
string EncryptEA(string account = "", string type = "Testing", string name = "", int days = 30)
{
  return "";
}

bool DecryptEA()
{
  return true;
}

bool VerifyOnlyValidEAs(string ea_name)
{
  return true;
}

bool VerifyLicense()
{
  return true;
}

bool VerifyLicenseType()
{
  return true;
}

bool VerifyValidLicenseTime()
{
  return true;
}

bool LicenseErrorIsHardAuth(const string)
{
  return false;
}

bool LicenseErrorIsRetryable(const string, const int)
{
  return false;
}

bool LicenseErrorIsOnlineLimitReached(const string)
{
  return false;
}

bool LicenseShouldRemoveForOnlineLimit(const bool, const int)
{
  return false;
}

bool LicenseLastFailureWasStartupOnlineLimit()
{
  return false;
}

string LicenseFriendlyOnlineLimitMessage()
{
  return "No license seat is currently available for this EA. Please close another active session or try again shortly.";
}

bool LicenseOnline_RequestLeaderReverify(const string)
{
  return false;
}

bool LicenseHasValidCachedMagicNumber()
{
  return false;
}

long LicenseGetCachedMagicNumber()
{
  return 0;
}

void LicenseSetRequestedAddonsCsv(const string addons_csv)
{
  license_addons = addons_csv;
}

string LicenseGetRequestedAddonsCsv()
{
  return license_addons;
}

bool LicenseIsTestingMode()
{
  return is_testing;
}

bool LicenseHasAddon(const string)
{
  return true;
}

bool LicenseHasAnyCompoundFamilyAddon()
{
  return true;
}

int LicenseGrantedAddonCount()
{
  return 0;
}

void LicenseCopyGrantedAddons(string &addons_out[])
{
  ArrayResize(addons_out, 0);
}

bool IsAdmin()
{
  return false;
}

bool CanBacktest()
{
  return true;
}

bool AllowDemo()
{
  return true;
}

bool AllowLive()
{
  return true;
}
#endif

#endif // _SERVICES_SHARED_LICENSE_GUARD_V1_LICENSE_SERVICE_MQH_
