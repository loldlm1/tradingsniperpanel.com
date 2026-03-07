//+------------------------------------------------------------------+
#ifndef _SERVICES_SHARED_LICENSE_GUARD_V1_ONLINE_MQH_
#define _SERVICES_SHARED_LICENSE_GUARD_V1_ONLINE_MQH_
#include "license_guard_profile.mqh"
#include "../../JsonParser.mqh"
#ifdef LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS
#include "core/addon_catalog.mqh"
#else
string AddonCatalogNormalizeKey(const string addon_key)
{
  string normalized = addon_key;
  StringTrimLeft(normalized);
  StringTrimRight(normalized);
  StringToLower(normalized);
  return normalized;
}

bool AddonCatalogKeysEqual(const string left_key, const string right_key)
{
  return (AddonCatalogNormalizeKey(left_key) == AddonCatalogNormalizeKey(right_key));
}

void AddonCatalogAllCompoundFamilies(string &families[])
{
  ArrayResize(families, 0);
}

#define ADDON_KEY_SESSION_TIME_FILTER      "addon_session_time_filter"
#define ADDON_KEY_GRID_STRATEGY_CONFIG     "addon_grid_strategy_config"
#define ADDON_KEY_CANDLE_STRUCTURE_FILTER   "addon_candle_structure"
#define ADDON_KEY_COMPOUND_TREND_RIDE      "addon_compound_trend_ride"
#define ADDON_KEY_COMPOUND_PULLBACK_CONT   "addon_compound_pullback_continue"
#define ADDON_KEY_COMPOUND_REVERSAL_EARLY  "addon_compound_reversal_early"
#define ADDON_KEY_COMPOUND_BREAKOUT_READY  "addon_compound_breakout_ready"
#define ADDON_KEY_COMPOUND_VOLATILITY_TRAP "addon_compound_volatility_trap"
#endif
CBcrypt BCrypt;

string primary_ci_key = LICENSE_SHARED_PRIMARY_CI_KEY;
string base_secret_key = LICENSE_SHARED_BASE_SECRET_KEY;
string source_secret_key = LICENSE_SHARED_SOURCE_KEY;
string license_addons = "";
const string base_ea_id_key = LICENSE_SHARED_BASE_EA_ID;

const string license_api_base_url = LICENSE_SHARED_API_BASE_URL;
const string license_verify_api_path = "/api/v1/licenses/verify";
const string license_heartbeat_api_path = "/api/v1/licenses/heartbeat";
const int license_request_timeout_ms = 5000;
const int license_refresh_seconds = 86400;
const int license_heartbeat_seconds = 180;
const int license_leader_stale_seconds = 360;
const int license_online_limit_runtime_confirmations = 2;
const int license_startup_sync_max_polls = 25;
const int license_startup_sync_poll_sleep_ms = 200;

const string license_lane_key_prefix = "SNP_LANE";
const long license_magic_number_min = 1;
const long license_magic_number_max = 2147483647;

enum LicenseRequestType
{
  LICENSE_REQUEST_VERIFY = 0,
  LICENSE_REQUEST_HEARTBEAT = 1
};

enum LicenseSharedErrorCode
{
  LICENSE_SHARED_ERROR_NONE = 0,
  LICENSE_SHARED_ERROR_REQUEST_FAILED = 1,
  LICENSE_SHARED_ERROR_INVALID_SOURCE = 2,
  LICENSE_SHARED_ERROR_INVALID_KEY = 3,
  LICENSE_SHARED_ERROR_ADDONS_REQUIRED = 4,
  LICENSE_SHARED_ERROR_TRIAL_DISABLED = 5,
  LICENSE_SHARED_ERROR_EXPIRED = 6,
  LICENSE_SHARED_ERROR_USER_NOT_FOUND = 7,
  LICENSE_SHARED_ERROR_EA_NOT_FOUND = 8,
  LICENSE_SHARED_ERROR_LICENSE_NOT_FOUND = 9,
  LICENSE_SHARED_ERROR_INVALID_EXPIRES_AT = 10,
  LICENSE_SHARED_ERROR_INVALID_GRANTED_ADDONS = 11,
  LICENSE_SHARED_ERROR_RATE_LIMITED = 12,
  LICENSE_SHARED_ERROR_ONLINE_LIMIT_REACHED = 13,
  LICENSE_SHARED_ERROR_INTERNAL_ERROR = 14,
  LICENSE_SHARED_ERROR_INVALID_PAYLOAD = 15,
  LICENSE_SHARED_ERROR_MISSING_MAGIC_NUMBER = 16,
  LICENSE_SHARED_ERROR_INVALID_MAGIC_NUMBER = 17,
  LICENSE_SHARED_ERROR_UNKNOWN = 100
};

string license_email = "";
string license_ea_id = "";
datetime license_expire = 0;
datetime last_validation_time = 0;
datetime license_last_heartbeat_time = 0;
bool license_payload_ok = false;
bool is_testing = false;
bool license_trial = false;
string license_plan_interval = "";
string license_last_error = "";
int license_last_http_status = 0;
string license_broker_name = "";
string license_broker_company = "";
long license_broker_account_number = 0;
string license_broker_account_type = "";
bool license_broker_account_synced = false;
long license_magic_number = 0;
bool license_magic_number_synced = false;
string license_granted_addons[];

long license_instance_id = 0;
string license_lane_hash = "";
bool license_lane_initialized = false;
bool license_lane_is_leader = false;
datetime license_lane_next_heartbeat_at = 0;
int license_runtime_online_limit_conflicts = 0;
bool license_last_failure_startup_online_limit = false;
datetime license_instance_verified_startup_at = 0;
datetime license_last_reverify_request_handled = 0;

string SidToString(const uchar &sid[])
{
  string sidString;
  int sidLength = ArraySize(sid);

  for(int i = 0; i < sidLength; i++)
  {
    sidString += StringFormat("%02X", sid[i]);
    if(i < sidLength - 1)
      sidString += "-";
  }

  return sidString;
}

string Trim(string value)
{
  StringTrimLeft(value);
  StringTrimRight(value);
  return value;
}

string LicenseNormalizeErrorCode(const string raw_error)
{
  string normalized = Trim(raw_error);
  StringToLower(normalized);
  return normalized;
}

bool LicenseMagicNumberIsSupported(const long value)
{
  return (value >= license_magic_number_min && value <= license_magic_number_max);
}

bool LicenseGlobalDoubleToSupportedMagicNumber(const string key,
                                               long &magic_number)
{
  magic_number = 0;
  if(!GlobalVariableCheck(key))
    return false;

  double raw_magic = GlobalVariableGet(key);
  if(raw_magic <= 0.0)
    return false;

  long parsed_magic = (long)raw_magic;
  if((double)parsed_magic != raw_magic)
    return false;
  if(!LicenseMagicNumberIsSupported(parsed_magic))
    return false;

  magic_number = parsed_magic;
  return true;
}

bool LicenseErrorIsOnlineLimitReached(const string error_code)
{
  return (LicenseNormalizeErrorCode(error_code) == "online_limit_reached");
}

bool License_IsAuthError(const string error_code)
{
  string normalized = LicenseNormalizeErrorCode(error_code);
  if(normalized == "invalid_source") return true;
  if(normalized == "invalid_key") return true;
  if(normalized == "addons_required") return true;
  if(normalized == "trial_disabled") return true;
  if(normalized == "expired") return true;
  if(normalized == "user_not_found") return true;
  if(normalized == "ea_not_found") return true;
  if(normalized == "license_not_found") return true;
  if(normalized == "missing_magic_number") return true;
  if(normalized == "invalid_magic_number") return true;
  return false;
}

bool LicenseErrorIsHardAuth(const string error_code)
{
  return License_IsAuthError(error_code);
}

bool LicenseErrorIsRetryable(const string error_code, const int http_status)
{
  string normalized = LicenseNormalizeErrorCode(error_code);
  if(normalized == "request_failed") return true;
  if(normalized == "rate_limited") return true;
  if(normalized == "online_limit_reached") return true;
  if(normalized == "internal_error") return true;
  if(http_status >= 500) return true;
  return false;
}

bool LicenseShouldRemoveForOnlineLimit(const bool is_startup,
                                       const int consecutive_conflicts)
{
  if(is_startup)
    return true;
  return (consecutive_conflicts >= license_online_limit_runtime_confirmations);
}

bool LicenseLastFailureWasStartupOnlineLimit()
{
  return license_last_failure_startup_online_limit;
}

string LicenseFriendlyOnlineLimitMessage()
{
  return "No license seat is currently available for this EA. Please close another active session or try again shortly.";
}

void LicenseSetRequestedAddonsCsv(const string addons_csv)
{
  license_addons = Trim(addons_csv);
}

string LicenseGetRequestedAddonsCsv()
{
  return license_addons;
}

void LicenseClearGrantedAddons()
{
  ArrayResize(license_granted_addons, 0);
}

void LicenseAppendGrantedAddon(const string addon_key)
{
  string normalized_key = AddonCatalogNormalizeKey(addon_key);
  if(normalized_key == "")
    return;

  int total = ArraySize(license_granted_addons);
  for(int i = 0; i < total; i++)
  {
    if(AddonCatalogKeysEqual(license_granted_addons[i], normalized_key))
      return;
  }

  ArrayResize(license_granted_addons, total + 1);
  license_granted_addons[total] = normalized_key;
}

int LicenseGrantedAddonCount()
{
  return ArraySize(license_granted_addons);
}

bool LicenseIsTestingMode()
{
  return is_testing;
}

bool LicenseHasValidCachedMagicNumber()
{
  return (license_magic_number_synced && LicenseMagicNumberIsSupported(license_magic_number));
}

long LicenseGetCachedMagicNumber()
{
  if(!LicenseHasValidCachedMagicNumber())
    return 0;
  return license_magic_number;
}

bool LicenseHasAddon(const string addon_key)
{
  if(LicenseIsTestingMode())
    return true;

  string normalized_key = AddonCatalogNormalizeKey(addon_key);
  if(normalized_key == "")
    return false;

  int total = ArraySize(license_granted_addons);
  for(int i = 0; i < total; i++)
  {
    if(AddonCatalogKeysEqual(license_granted_addons[i], normalized_key))
      return true;
  }

  return false;
}

bool LicenseHasAnyCompoundFamilyAddon()
{
  string compound_families[];
  AddonCatalogAllCompoundFamilies(compound_families);

  int total = ArraySize(compound_families);
  for(int i = 0; i < total; i++)
  {
    if(LicenseHasAddon(compound_families[i]))
      return true;
  }
  return false;
}

void LicenseCopyGrantedAddons(string &addons_out[])
{
  int total = ArraySize(license_granted_addons);
  ArrayResize(addons_out, total);
  for(int i = 0; i < total; i++)
    addons_out[i] = license_granted_addons[i];
}

int LicenseAddonBitIndex(const string addon_key)
{
  string normalized = AddonCatalogNormalizeKey(addon_key);
  if(normalized == ADDON_KEY_SESSION_TIME_FILTER) return 0;
  if(normalized == ADDON_KEY_GRID_STRATEGY_CONFIG) return 1;
  if(normalized == ADDON_KEY_CANDLE_STRUCTURE_FILTER) return 2;
  if(normalized == ADDON_KEY_COMPOUND_TREND_RIDE) return 3;
  if(normalized == ADDON_KEY_COMPOUND_PULLBACK_CONT) return 4;
  if(normalized == ADDON_KEY_COMPOUND_REVERSAL_EARLY) return 5;
  if(normalized == ADDON_KEY_COMPOUND_BREAKOUT_READY) return 6;
  if(normalized == ADDON_KEY_COMPOUND_VOLATILITY_TRAP) return 7;
  return -1;
}

ulong LicenseGrantedAddonsMask()
{
  ulong mask = 0;
  int total = ArraySize(license_granted_addons);
  for(int i = 0; i < total; i++)
  {
    int bit = LicenseAddonBitIndex(license_granted_addons[i]);
    if(bit < 0)
      continue;
    mask |= (((ulong)1) << bit);
  }
  return mask;
}

void LicenseApplyGrantedAddonsMask(const ulong mask)
{
  LicenseClearGrantedAddons();

  if((mask & (((ulong)1) << 0)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_SESSION_TIME_FILTER);
  if((mask & (((ulong)1) << 1)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_GRID_STRATEGY_CONFIG);
  if((mask & (((ulong)1) << 2)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_CANDLE_STRUCTURE_FILTER);
  if((mask & (((ulong)1) << 3)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_COMPOUND_TREND_RIDE);
  if((mask & (((ulong)1) << 4)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_COMPOUND_PULLBACK_CONT);
  if((mask & (((ulong)1) << 5)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_COMPOUND_REVERSAL_EARLY);
  if((mask & (((ulong)1) << 6)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_COMPOUND_BREAKOUT_READY);
  if((mask & (((ulong)1) << 7)) != 0) LicenseAppendGrantedAddon(ADDON_KEY_COMPOUND_VOLATILITY_TRAP);
}

bool LicenseParseGrantedAddonsFromResponse(JSON::Object &response)
{
  LicenseClearGrantedAddons();

  if(!response.isArray("granted_addons"))
    return false;

  JSON::Array *addons = response.getArray("granted_addons");
  if(addons == NULL)
    return false;

  int total = addons.getLength();
  for(int i = 0; i < total; i++)
  {
    if(!addons.isString(i))
      continue;
    LicenseAppendGrantedAddon(addons.getString(i));
  }

  return true;
}

bool IsValidEmail(const string email)
{
  int at_pos = StringFind(email, "@");
  if(at_pos <= 0) return false;
  if(at_pos >= StringLen(email) - 1) return false;
  return true;
}

string AccountTypeToString()
{
  if(is_testing)
    return "testing";

  ENUM_ACCOUNT_TRADE_MODE trade_mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
  if(trade_mode == ACCOUNT_TRADE_MODE_REAL) return "real";
  if(trade_mode == ACCOUNT_TRADE_MODE_DEMO) return "demo";

  return "unknown";
}

string LicenseSanitizeToken(const string value)
{
  string result = "";
  int len = StringLen(value);
  for(int i = 0; i < len; i++)
  {
    int ch = StringGetCharacter(value, i);
    bool allowed = (ch >= '0' && ch <= '9') ||
                   (ch >= 'A' && ch <= 'Z') ||
                   (ch >= 'a' && ch <= 'z');
    if(allowed)
      result += CharToString((uchar)ch);
    else
      result += "_";
  }

  if(result == "")
    result = "_";
  return result;
}

ulong LicenseFNV1a64(const string input_value)
{
  ulong hash = 1469598103934665603;
  int len = StringLen(input_value);
  for(int i = 0; i < len; i++)
  {
    hash ^= (ulong)(uchar)StringGetCharacter(input_value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string LicenseLaneBuildHash(const string identity_raw)
{
  ulong hash = LicenseFNV1a64(identity_raw);
  uint hi = (uint)(hash >> 32);
  uint lo = (uint)(hash & 0xFFFFFFFF);
  return StringFormat("%08X%08X", hi, lo);
}

string LicenseLaneGlobalKey(const string suffix)
{
  return license_lane_key_prefix + "_" + license_lane_hash + "_" + suffix;
}

int LicenseSharedErrorCodeToInt(const string error_code)
{
  string normalized = LicenseNormalizeErrorCode(error_code);
  if(normalized == "") return LICENSE_SHARED_ERROR_NONE;
  if(normalized == "request_failed") return LICENSE_SHARED_ERROR_REQUEST_FAILED;
  if(normalized == "invalid_source") return LICENSE_SHARED_ERROR_INVALID_SOURCE;
  if(normalized == "invalid_key") return LICENSE_SHARED_ERROR_INVALID_KEY;
  if(normalized == "addons_required") return LICENSE_SHARED_ERROR_ADDONS_REQUIRED;
  if(normalized == "trial_disabled") return LICENSE_SHARED_ERROR_TRIAL_DISABLED;
  if(normalized == "expired") return LICENSE_SHARED_ERROR_EXPIRED;
  if(normalized == "user_not_found") return LICENSE_SHARED_ERROR_USER_NOT_FOUND;
  if(normalized == "ea_not_found") return LICENSE_SHARED_ERROR_EA_NOT_FOUND;
  if(normalized == "license_not_found") return LICENSE_SHARED_ERROR_LICENSE_NOT_FOUND;
  if(normalized == "invalid_expires_at") return LICENSE_SHARED_ERROR_INVALID_EXPIRES_AT;
  if(normalized == "invalid_granted_addons") return LICENSE_SHARED_ERROR_INVALID_GRANTED_ADDONS;
  if(normalized == "rate_limited") return LICENSE_SHARED_ERROR_RATE_LIMITED;
  if(normalized == "online_limit_reached") return LICENSE_SHARED_ERROR_ONLINE_LIMIT_REACHED;
  if(normalized == "internal_error") return LICENSE_SHARED_ERROR_INTERNAL_ERROR;
  if(normalized == "invalid_payload") return LICENSE_SHARED_ERROR_INVALID_PAYLOAD;
  if(normalized == "missing_magic_number") return LICENSE_SHARED_ERROR_MISSING_MAGIC_NUMBER;
  if(normalized == "invalid_magic_number") return LICENSE_SHARED_ERROR_INVALID_MAGIC_NUMBER;
  return LICENSE_SHARED_ERROR_UNKNOWN;
}

string LicenseSharedErrorCodeFromInt(const int code)
{
  if(code == LICENSE_SHARED_ERROR_NONE) return "";
  if(code == LICENSE_SHARED_ERROR_REQUEST_FAILED) return "request_failed";
  if(code == LICENSE_SHARED_ERROR_INVALID_SOURCE) return "invalid_source";
  if(code == LICENSE_SHARED_ERROR_INVALID_KEY) return "invalid_key";
  if(code == LICENSE_SHARED_ERROR_ADDONS_REQUIRED) return "addons_required";
  if(code == LICENSE_SHARED_ERROR_TRIAL_DISABLED) return "trial_disabled";
  if(code == LICENSE_SHARED_ERROR_EXPIRED) return "expired";
  if(code == LICENSE_SHARED_ERROR_USER_NOT_FOUND) return "user_not_found";
  if(code == LICENSE_SHARED_ERROR_EA_NOT_FOUND) return "ea_not_found";
  if(code == LICENSE_SHARED_ERROR_LICENSE_NOT_FOUND) return "license_not_found";
  if(code == LICENSE_SHARED_ERROR_INVALID_EXPIRES_AT) return "invalid_expires_at";
  if(code == LICENSE_SHARED_ERROR_INVALID_GRANTED_ADDONS) return "invalid_granted_addons";
  if(code == LICENSE_SHARED_ERROR_RATE_LIMITED) return "rate_limited";
  if(code == LICENSE_SHARED_ERROR_ONLINE_LIMIT_REACHED) return "online_limit_reached";
  if(code == LICENSE_SHARED_ERROR_INTERNAL_ERROR) return "internal_error";
  if(code == LICENSE_SHARED_ERROR_INVALID_PAYLOAD) return "invalid_payload";
  if(code == LICENSE_SHARED_ERROR_MISSING_MAGIC_NUMBER) return "missing_magic_number";
  if(code == LICENSE_SHARED_ERROR_INVALID_MAGIC_NUMBER) return "invalid_magic_number";
  return "unknown";
}

void LicenseLaneEnsureInstanceId()
{
  if(license_instance_id != 0)
    return;

  license_instance_id = (long)ChartID();
  if(license_instance_id == 0)
    license_instance_id = (long)AccountInfoInteger(ACCOUNT_LOGIN);
  if(license_instance_id == 0)
    license_instance_id = (long)TimeCurrent();
}

string LicenseLaneBuildIdentityRaw()
{
  string company = LicenseNormalizeErrorCode(AccountInfoString(ACCOUNT_COMPANY));
  string account_type = LicenseNormalizeErrorCode(AccountTypeToString());
  long account_number = (long)AccountInfoInteger(ACCOUNT_LOGIN);

  return source_secret_key + "|" +
         LicenseNormalizeErrorCode(license_email) + "|" +
         LicenseNormalizeErrorCode(license_ea_id) + "|" +
         company + "|" +
         StringFormat("%I64d", account_number) + "|" +
         account_type;
}

bool LicenseLaneEnsureInitialized()
{
  if(license_lane_initialized)
    return true;

  if(!license_payload_ok && !DecryptEA())
    return false;

  LicenseLaneEnsureInstanceId();
  string identity_raw = LicenseLaneBuildIdentityRaw();
  license_lane_hash = LicenseLaneBuildHash(identity_raw);
  license_lane_initialized = (license_lane_hash != "");
  return license_lane_initialized;
}

long LicenseLaneReadLeaderId()
{
  string key = LicenseLaneGlobalKey("LEADER");
  if(!GlobalVariableCheck(key))
    return 0;
  return (long)GlobalVariableGet(key);
}

datetime LicenseLaneReadLeaderHeartbeatAt()
{
  string key = LicenseLaneGlobalKey("BEAT");
  if(!GlobalVariableCheck(key))
    return 0;
  return (datetime)((long)GlobalVariableGet(key));
}

void LicenseLaneWriteLeaderHeartbeatAt(const datetime ts)
{
  string key = LicenseLaneGlobalKey("BEAT");
  GlobalVariableSet(key, (double)((long)ts));
}

void LicenseLaneWriteSharedSuccess(const datetime now)
{
  GlobalVariableSet(LicenseLaneGlobalKey("LAST_OK"), (double)((long)now));
  GlobalVariableSet(LicenseLaneGlobalKey("EXP"), (double)((long)license_expire));
  GlobalVariableSet(LicenseLaneGlobalKey("ERR"), (double)LICENSE_SHARED_ERROR_NONE);
  GlobalVariableSet(LicenseLaneGlobalKey("ERR_AT"), 0.0);
  GlobalVariableSet(LicenseLaneGlobalKey("HTTP"), (double)license_last_http_status);
  GlobalVariableSet(LicenseLaneGlobalKey("ADDON"), (double)LicenseGrantedAddonsMask());
  GlobalVariableSet(LicenseLaneGlobalKey("MAGIC"),
                    (LicenseMagicNumberIsSupported(license_magic_number) ? (double)license_magic_number : 0.0));
  GlobalVariableSet(LicenseLaneGlobalKey("CLAIM_AT"), (double)((long)license_instance_verified_startup_at));
}

void LicenseLaneWriteSharedFailure(const datetime now,
                                   const string error_code,
                                   const int http_status)
{
  int shared_error = LicenseSharedErrorCodeToInt(error_code);
  GlobalVariableSet(LicenseLaneGlobalKey("ERR"), (double)shared_error);
  GlobalVariableSet(LicenseLaneGlobalKey("ERR_AT"), (double)((long)now));
  GlobalVariableSet(LicenseLaneGlobalKey("HTTP"), (double)http_status);
}

bool LicenseLaneReadSharedState(datetime &last_ok,
                                datetime &expires_at,
                                string &error_code,
                                datetime &error_at,
                                ulong &addons_mask,
                                long &magic_number)
{
  last_ok = 0;
  expires_at = 0;
  error_code = "";
  error_at = 0;
  addons_mask = 0;
  magic_number = 0;

  string key_last_ok = LicenseLaneGlobalKey("LAST_OK");
  string key_exp = LicenseLaneGlobalKey("EXP");
  string key_err = LicenseLaneGlobalKey("ERR");
  string key_err_at = LicenseLaneGlobalKey("ERR_AT");
  string key_addon = LicenseLaneGlobalKey("ADDON");
  string key_magic = LicenseLaneGlobalKey("MAGIC");

  if(GlobalVariableCheck(key_last_ok))
    last_ok = (datetime)((long)GlobalVariableGet(key_last_ok));
  if(GlobalVariableCheck(key_exp))
    expires_at = (datetime)((long)GlobalVariableGet(key_exp));
  if(GlobalVariableCheck(key_err))
    error_code = LicenseSharedErrorCodeFromInt((int)GlobalVariableGet(key_err));
  if(GlobalVariableCheck(key_err_at))
    error_at = (datetime)((long)GlobalVariableGet(key_err_at));
  if(GlobalVariableCheck(key_addon))
    addons_mask = (ulong)((long)GlobalVariableGet(key_addon));
  LicenseGlobalDoubleToSupportedMagicNumber(key_magic, magic_number);

  return (last_ok > 0 || expires_at > 0 || error_code != "" || magic_number > 0);
}

bool LicenseLaneLeaderIsHealthy(const datetime now)
{
  datetime heartbeat = LicenseLaneReadLeaderHeartbeatAt();
  if(heartbeat <= 0)
    return false;
  return ((now - heartbeat) <= license_leader_stale_seconds);
}

bool LicenseLaneTryAcquireLeadership(const datetime now,
                                     const bool allow_takeover)
{
  string key_leader = LicenseLaneGlobalKey("LEADER");

  if(!GlobalVariableCheck(key_leader))
    GlobalVariableSet(key_leader, (double)license_instance_id);

  long current_leader = LicenseLaneReadLeaderId();
  if(current_leader == 0)
  {
    GlobalVariableSet(key_leader, (double)license_instance_id);
    current_leader = license_instance_id;
  }

  if(current_leader == license_instance_id)
  {
    license_lane_is_leader = true;
    LicenseLaneWriteLeaderHeartbeatAt(now);
    return true;
  }

  bool leader_healthy = LicenseLaneLeaderIsHealthy(now);
  if(!allow_takeover || leader_healthy)
  {
    license_lane_is_leader = false;
    return false;
  }

  bool became_leader = GlobalVariableSetOnCondition(key_leader,
                                                    (double)license_instance_id,
                                                    (double)current_leader);
  if(!became_leader)
  {
    license_lane_is_leader = false;
    return false;
  }

  license_lane_is_leader = true;
  LicenseLaneWriteLeaderHeartbeatAt(now);
  return true;
}

void LicenseLaneReleaseLeadership()
{
  if(!license_lane_initialized || !license_lane_is_leader)
    return;

  string key_leader = LicenseLaneGlobalKey("LEADER");
  long current_leader = LicenseLaneReadLeaderId();
  if(current_leader == license_instance_id)
    GlobalVariableSet(key_leader, 0.0);

  string key_beat = LicenseLaneGlobalKey("BEAT");
  if(GlobalVariableCheck(key_beat))
    GlobalVariableSet(key_beat, 0.0);

  license_lane_is_leader = false;
}

void LicenseLaneTouchLeader(const datetime now)
{
  if(!license_lane_is_leader)
    return;
  LicenseLaneWriteLeaderHeartbeatAt(now);
}

bool LicenseLaneApplySharedSuccessIfAvailable(const datetime now)
{
  datetime shared_last_ok = 0;
  datetime shared_exp = 0;
  string shared_error = "";
  datetime shared_error_at = 0;
  ulong shared_mask = 0;
  long shared_magic = 0;
  bool has_state = LicenseLaneReadSharedState(shared_last_ok,
                                              shared_exp,
                                              shared_error,
                                              shared_error_at,
                                              shared_mask,
                                              shared_magic);
  if(!has_state)
    return false;

  if(shared_exp <= now)
    return false;

  if(LicenseErrorIsHardAuth(shared_error))
    return false;

  if(shared_magic <= 0)
    return false;

  license_expire = shared_exp;
  last_validation_time = shared_last_ok;
  license_last_error = "";
  license_last_http_status = 200;
  license_magic_number = shared_magic;
  license_magic_number_synced = true;
  LicenseApplyGrantedAddonsMask(shared_mask);
  return true;
}

bool LicenseLaneShouldRemoveFollowerForSharedHardError(const datetime now)
{
  datetime shared_last_ok = 0;
  datetime shared_exp = 0;
  string shared_error = "";
  datetime shared_error_at = 0;
  ulong shared_mask = 0;
  long shared_magic = 0;

  bool has_state = LicenseLaneReadSharedState(shared_last_ok,
                                              shared_exp,
                                              shared_error,
                                              shared_error_at,
                                              shared_mask,
                                              shared_magic);
  if(!has_state)
    return false;

  if(!LicenseErrorIsHardAuth(shared_error))
    return false;

  if(shared_error_at <= 0)
    return false;

  if(shared_last_ok > 0 && shared_error_at <= shared_last_ok)
    return false;

  if((now - shared_error_at) > license_refresh_seconds)
    return false;

  license_last_error = shared_error;
  return true;
}

bool LicenseLaneHasPendingReverifyRequest(datetime &requested_at_out)
{
  requested_at_out = 0;
  string key = LicenseLaneGlobalKey("REVERIFY");
  if(!GlobalVariableCheck(key))
    return false;

  requested_at_out = (datetime)((long)GlobalVariableGet(key));
  if(requested_at_out <= 0)
    return false;

  if(requested_at_out <= license_last_reverify_request_handled)
    return false;

  return true;
}

void LicenseLaneRequestReverify(const datetime now)
{
  GlobalVariableSet(LicenseLaneGlobalKey("REVERIFY"), (double)((long)now));
}

void LicenseLaneClearReverifyRequest(const datetime handled_at)
{
  GlobalVariableSet(LicenseLaneGlobalKey("REVERIFY"), 0.0);
  license_last_reverify_request_handled = handled_at;
}

string BuildLicensePayload(const bool include_addons,
                           const LicenseRequestType request_type)
{
  JSON::Object payload;
  payload.setProperty("source", source_secret_key);
  payload.setProperty("email", license_email);
  payload.setProperty("ea_id", license_ea_id);
  payload.setProperty("license_key", EA_License_Key);

  if(request_type == LICENSE_REQUEST_VERIFY && include_addons && StringLen(Trim(license_addons)) > 0)
    payload.setProperty("addons", Trim(license_addons));

  JSON::Object* broker_account = new JSON::Object();
  broker_account.setProperty("name", AccountInfoString(ACCOUNT_NAME));
  broker_account.setProperty("company", AccountInfoString(ACCOUNT_COMPANY));
  broker_account.setProperty("account_number", (long)AccountInfoInteger(ACCOUNT_LOGIN));
  broker_account.setProperty("account_type", AccountTypeToString());
  payload.setProperty("broker_account", broker_account);

  return payload.toString();
}

bool HttpPostJson(const string url,
                  const string payload,
                  string &response_body,
                  int &status_code)
{
  uchar data[];
  int data_len = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8) - 1;
  if(data_len < 0)
    data_len = 0;
  ArrayResize(data, data_len);

  uchar result[];
  string result_headers;
  string headers = "Content-Type: application/json; charset=utf-8\r\n"
                   "Accept: application/json\r\n";

  ResetLastError();
  int res = WebRequest("POST", url, headers, license_request_timeout_ms, data, result, result_headers);
  if(res == -1)
  {
    int err = GetLastError();
    PrintFormat("LICENSE REQUEST FAILED (error %d).", err);
    return false;
  }

  response_body = CharArrayToString(result, 0, -1, CP_UTF8);
  status_code = res;
  return true;
}

void License_ClearRuntimeDetails()
{
  license_trial = false;
  license_plan_interval = "";
  license_last_error = "";
  license_last_http_status = 0;
  license_broker_name = "";
  license_broker_company = "";
  license_broker_account_number = 0;
  license_broker_account_type = "";
  license_broker_account_synced = false;
  license_magic_number = 0;
  license_magic_number_synced = false;
  LicenseClearGrantedAddons();
}

void License_ParseBrokerAccountFromResponse(JSON::Object &response)
{
  license_broker_name = "";
  license_broker_company = "";
  license_broker_account_number = 0;
  license_broker_account_type = "";
  license_broker_account_synced = false;

  if(!response.isObject("broker_account"))
    return;

  JSON::Object *broker = response.getObject("broker_account");
  if(broker == NULL)
    return;

  if(broker.isString("name"))
    license_broker_name = broker.getString("name");
  if(broker.isString("company"))
    license_broker_company = broker.getString("company");
  if(broker.isNumber("account_number"))
    license_broker_account_number = (long)broker.getNumber("account_number");
  if(broker.isString("account_type"))
    license_broker_account_type = broker.getString("account_type");

  license_broker_account_synced = (license_broker_company != "" &&
                                   license_broker_account_number > 0 &&
                                   (license_broker_account_type == "real" ||
                                    license_broker_account_type == "demo"));
}

bool License_ParseMagicNumberFromResponse(JSON::Object &response)
{
  if(!response.isNumber("magic_number"))
  {
    license_last_error = "missing_magic_number";
    Print("LICENSE RESPONSE MISSING magic_number.");
    return false;
  }

  long parsed_magic_number = (long)response.getNumber("magic_number");
  if(!LicenseMagicNumberIsSupported(parsed_magic_number))
  {
    license_last_error = "invalid_magic_number";
    PrintFormat("LICENSE RESPONSE INVALID magic_number=%I64d. Expected supported signed-32-bit-safe value.",
                parsed_magic_number);
    return false;
  }

  license_magic_number = parsed_magic_number;
  license_magic_number_synced = true;
  return true;
}

bool LicenseParseSuccessResponse(JSON::Object &response,
                                 const LicenseRequestType request_type)
{
  license_trial = response.isBoolean("trial") ? response.getBoolean("trial") : false;
  license_plan_interval = response.isString("plan_interval") ? response.getString("plan_interval") : "";
  License_ParseBrokerAccountFromResponse(response);

  if(request_type == LICENSE_REQUEST_VERIFY)
  {
    if(!LicenseParseGrantedAddonsFromResponse(response))
    {
      license_last_error = "invalid_granted_addons";
      Print("LICENSE RESPONSE MISSING granted_addons.");
      return false;
    }
    if(!License_ParseMagicNumberFromResponse(response))
      return false;
  }

  long expires_at = 0;
  if(response.isNumber("expires_at"))
    expires_at = (long)response.getNumber("expires_at");

  if(expires_at <= 0)
  {
    license_last_error = "invalid_expires_at";
    Print("LICENSE EXPIRATION INVALID.");
    return false;
  }

  license_expire = (datetime)expires_at;
  if(license_expire <= TimeCurrent())
  {
    license_last_error = "expired";
    Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
    return false;
  }

  return true;
}

bool LicenseSendOnlineRequest(const LicenseRequestType request_type,
                              const bool include_addons,
                              const bool is_startup)
{
  license_last_error = "";
  license_last_http_status = 0;
  license_last_failure_startup_online_limit = false;

  string endpoint = (request_type == LICENSE_REQUEST_HEARTBEAT ?
                     license_heartbeat_api_path :
                     license_verify_api_path);

  string url = license_api_base_url + endpoint;
  string payload = BuildLicensePayload(include_addons, request_type);
  string response_body = "";
  int status_code = 0;

  if(!HttpPostJson(url, payload, response_body, status_code))
  {
    license_last_error = "request_failed";
    return false;
  }

  license_last_http_status = status_code;
  string response_copy = response_body;
  JSON::Object response(response_copy);

  if(response.isString("error"))
    license_last_error = LicenseNormalizeErrorCode(response.getString("error"));

  bool ok = response.isBoolean("ok") ? response.getBoolean("ok") : false;
  if(status_code < 200 || status_code >= 300 || !ok)
  {
    if(license_last_error == "")
      license_last_error = "request_failed";

    if(is_startup && LicenseErrorIsOnlineLimitReached(license_last_error))
      license_last_failure_startup_online_limit = true;

    if(license_last_error != "")
      PrintFormat("LICENSE REJECTED (%s) HTTP %d: %s",
                  (request_type == LICENSE_REQUEST_HEARTBEAT ? "heartbeat" : "verify"),
                  status_code,
                  license_last_error);
    else
      PrintFormat("LICENSE SERVER ERROR (%s) HTTP %d.",
                  (request_type == LICENSE_REQUEST_HEARTBEAT ? "heartbeat" : "verify"),
                  status_code);
    return false;
  }

  if(!LicenseParseSuccessResponse(response, request_type))
    return false;

  datetime now = TimeCurrent();
  if(request_type == LICENSE_REQUEST_VERIFY)
    last_validation_time = now;
  else
    license_last_heartbeat_time = now;

  license_last_error = "";
  return true;
}

bool ValidateLicensePayload()
{
  if(!IsValidEmail(license_email))
    return false;
  if(StringLen(license_ea_id) == 0)
    return false;
  if(license_ea_id != base_ea_id_key)
  {
    Print("LICENSE EA ID DOES NOT MATCH.");
    return false;
  }
  if(license_expire <= 0)
    return false;
  return true;
}

string EncryptEA(string email = "", string ea_id = "", int days = 30)
{
  if(email == "")
    email = AccountInfoString(ACCOUNT_NAME);
  if(ea_id == "")
    ea_id = base_ea_id_key;

  string payload = email + "," + ea_id + "," + (string)(TimeCurrent() + (60 * 60 * 24 * days));
  BCrypt.Init(primary_ci_key, base_secret_key, payload);
  string encrypted_payload = BCrypt.Encrypt();

  Print("NEW LICENSE KEY= ", encrypted_payload);
  return encrypted_payload;
}

bool DecryptEA()
{
  license_payload_ok = false;
  License_ClearRuntimeDetails();

  if(StringLen(EA_License_Key) == 0)
  {
    Print("LICENSE KEY IS EMPTY.");
    return false;
  }

  string license_privileges[];
  ushort u_sep = StringGetCharacter(",", 0);
  BCrypt.Init(primary_ci_key, base_secret_key);
  string decrypted_payload = BCrypt.Decrypt(EA_License_Key);

  int license_ok = StringSplit(decrypted_payload, u_sep, license_privileges);
  if(license_ok != 3)
  {
    Print("Could not decrypt the current license.");
    return false;
  }

  license_email = Trim(license_privileges[0]);
  license_ea_id = Trim(license_privileges[1]);
  license_expire = (datetime)StringToInteger(Trim(license_privileges[2]));

  if(!ValidateLicensePayload())
  {
    Print("LICENSE PAYLOAD INVALID.");
    return false;
  }

  license_payload_ok = true;
  Print("LICENSE PAYLOAD OK.");
  return true;
}

bool VerifyOnlyValidEAs(string ea_name)
{
  if(IsAdmin())
    return true;

  long chartID = ChartFirst();
  string expert_name = "";
  string script_name = "";

  while(chartID > 0)
  {
    expert_name = ChartGetString(chartID, CHART_EXPERT_NAME);
    script_name = ChartGetString(chartID, CHART_SCRIPT_NAME);

    if(StringLen(expert_name) > 0 && expert_name != ea_name)
    {
      Print("Only valid [", ea_name, "] system EAs.");
      return false;
    }
    if(StringLen(script_name) > 0 && expert_name != ea_name)
    {
      Print("Only valid [", ea_name, "] system EAs.");
      return false;
    }

    chartID = ChartNext(chartID);
    if(chartID <= 0)
      break;
  }

  return true;
}

bool VerifyLicenseTester()
{
  if(!license_payload_ok && !DecryptEA())
    return false;
  if(!ValidateLicensePayload())
    return false;
  if(license_expire <= TimeCurrent())
  {
    license_last_error = "expired";
    Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
    return false;
  }

  last_validation_time = TimeCurrent();
  Print("VALID EA LICENSE (TESTER)!");
  return true;
}

bool VerifyLicenseOnlineRequest(const bool is_startup)
{
  bool ok = LicenseSendOnlineRequest(LICENSE_REQUEST_VERIFY, true, is_startup);
  if(!ok)
    return false;

  datetime now = TimeCurrent();
  if(is_startup && license_instance_verified_startup_at == 0)
    license_instance_verified_startup_at = now;

  LicenseLaneWriteSharedSuccess(now);
  PrintFormat("VALID EA LICENSE! trial=%s plan_interval=%s broker_synced=%s magic=%I64d addons=%d",
              (license_trial ? "true" : "false"),
              (license_plan_interval == "" ? "n/a" : license_plan_interval),
              (license_broker_account_synced ? "true" : "false"),
              license_magic_number,
              LicenseGrantedAddonCount());
  return true;
}

bool VerifyLicenseOnlineHeartbeat()
{
  return LicenseSendOnlineRequest(LICENSE_REQUEST_HEARTBEAT, false, false);
}

bool VerifyLicenseOnline()
{
  return VerifyLicenseOnlineRequest(false);
}

int LicenseStartupGuardedFallbackPolls()
{
  int polls = (license_request_timeout_ms / license_startup_sync_poll_sleep_ms);
  if((license_request_timeout_ms % license_startup_sync_poll_sleep_ms) != 0)
    polls++;
  if(polls < 1)
    polls = 1;
  return polls;
}

bool VerifyLicenseOnlineStartup()
{
  if(!license_payload_ok && !DecryptEA())
    return false;

  if(!LicenseLaneEnsureInitialized())
    return false;

  datetime now = TimeCurrent();
  if(LicenseLaneTryAcquireLeadership(now, true))
  {
    Print("[LicenseLane] startup leader verify.");
    return VerifyLicenseOnlineRequest(true);
  }

  for(int poll = 0; poll < license_startup_sync_max_polls; poll++)
  {
    datetime poll_now = TimeCurrent();
    if(LicenseLaneApplySharedSuccessIfAvailable(poll_now))
    {
      Print("[LicenseLane] shared_success_applied (startup_sync).");
      return true;
    }

    if(LicenseLaneTryAcquireLeadership(poll_now, true))
    {
      Print("[LicenseLane] startup leader verify after sync wait.");
      return VerifyLicenseOnlineRequest(true);
    }

    Sleep(license_startup_sync_poll_sleep_ms);
  }

  int guarded_polls = LicenseStartupGuardedFallbackPolls();
  datetime guard_now = TimeCurrent();
  if(LicenseLaneLeaderIsHealthy(guard_now))
  {
    PrintFormat("[LicenseLane] leader_healthy_wait (startup_guard) polls=%d.", guarded_polls);
    for(int poll = 0; poll < guarded_polls; poll++)
    {
      datetime guarded_now = TimeCurrent();
      if(LicenseLaneApplySharedSuccessIfAvailable(guarded_now))
      {
        Print("[LicenseLane] shared_success_applied (startup_guard).");
        return true;
      }

      if(LicenseLaneTryAcquireLeadership(guarded_now, true))
      {
        Print("[LicenseLane] startup leader verify after guarded wait.");
        return VerifyLicenseOnlineRequest(true);
      }

      Sleep(license_startup_sync_poll_sleep_ms);
    }
  }

  datetime fallback_now = TimeCurrent();
  if(LicenseLaneTryAcquireLeadership(fallback_now, true))
  {
    Print("[LicenseLane] startup leader verify before fallback.");
    return VerifyLicenseOnlineRequest(true);
  }

  if(LicenseLaneLeaderIsHealthy(fallback_now))
    Print("[LicenseLane] guarded_fallback_verify (leader still healthy after extended wait).");
  else
    Print("[LicenseLane] stale_leader_fallback_verify.");

  return VerifyLicenseOnlineRequest(true);
}

bool VerifyLicense()
{
  if(is_testing)
    return VerifyLicenseTester();
  return VerifyLicenseOnlineStartup();
}

bool VerifyLicenseType()
{
  return true;
}

bool VerifyValidLicenseTime()
{
  if(license_expire <= 0)
  {
    license_last_error = "invalid_expires_at";
    Print("LICENSE EXPIRATION INVALID.");
    return false;
  }
  if(license_expire > TimeCurrent())
    return true;

  license_last_error = "expired";
  Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
  return false;
}

bool LicenseOnline_RequestLeaderReverify(const string reason)
{
  if(is_testing)
    return false;

  if(!LicenseLaneEnsureInitialized())
    return false;

  datetime now = TimeCurrent();
  if(license_lane_is_leader)
  {
    PrintFormat("[LicenseLane] Leader reverify requested (%s).", reason);
    return VerifyLicenseOnlineRequest(false);
  }

  LicenseLaneRequestReverify(now);
  PrintFormat("[LicenseLane] Follower queued reverify request (%s).", reason);
  return false;
}

void LicenseOnline_OnTimer()
{
  if(is_testing)
    return;

  if(!license_payload_ok && !DecryptEA())
    return;

  if(!LicenseLaneEnsureInitialized())
    return;

  datetime now = TimeCurrent();
  LicenseLaneTryAcquireLeadership(now, true);

  if(!license_lane_is_leader)
  {
    if(LicenseLaneApplySharedSuccessIfAvailable(now))
    {
      license_runtime_online_limit_conflicts = 0;
      return;
    }

    if(LicenseLaneShouldRemoveFollowerForSharedHardError(now))
    {
      PrintFormat("[LicenseLane] Follower removal triggered by hard auth error (%s).", license_last_error);
      EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    }
    return;
  }

  LicenseLaneTouchLeader(now);

  datetime queued_reverify_at = 0;
  if(LicenseLaneHasPendingReverifyRequest(queued_reverify_at))
  {
    bool reverify_ok = VerifyLicenseOnlineRequest(false);
    if(reverify_ok)
      LicenseLaneClearReverifyRequest(queued_reverify_at);
  }

  if(last_validation_time == 0)
    last_validation_time = now;

  bool need_full_verify = ((now - last_validation_time) >= license_refresh_seconds);
  if(need_full_verify)
  {
    bool verify_ok = VerifyLicenseOnlineRequest(false);
    if(verify_ok)
    {
      license_runtime_online_limit_conflicts = 0;
      return;
    }

    LicenseLaneWriteSharedFailure(now, license_last_error, license_last_http_status);
    if(LicenseErrorIsHardAuth(license_last_error))
    {
      PrintFormat("LICENSE REFRESH FAILED (hard auth) error=%s. EA REMOVED.",
                  (license_last_error == "" ? "unknown" : license_last_error));
      EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
      return;
    }
  }

  if(license_lane_next_heartbeat_at == 0)
    license_lane_next_heartbeat_at = now;
  if(now < license_lane_next_heartbeat_at)
    return;

  license_lane_next_heartbeat_at = now + license_heartbeat_seconds;

  bool heartbeat_ok = VerifyLicenseOnlineHeartbeat();
  if(heartbeat_ok)
  {
    license_runtime_online_limit_conflicts = 0;
    license_last_heartbeat_time = now;
    LicenseLaneWriteSharedSuccess(now);
    return;
  }

  LicenseLaneWriteSharedFailure(now, license_last_error, license_last_http_status);

  if(LicenseErrorIsOnlineLimitReached(license_last_error))
  {
    bool verify_confirmed = false;
    if(!VerifyLicenseOnlineRequest(false) && LicenseErrorIsOnlineLimitReached(license_last_error))
      verify_confirmed = true;

    if(verify_confirmed)
      license_runtime_online_limit_conflicts++;
    else
      license_runtime_online_limit_conflicts = 0;

    PrintFormat("[LicenseLane] Runtime capacity confirmation %d/%d.",
                license_runtime_online_limit_conflicts,
                license_online_limit_runtime_confirmations);

    if(LicenseShouldRemoveForOnlineLimit(false, license_runtime_online_limit_conflicts))
    {
      Print("[LicenseLane] Runtime online_limit_reached confirmed. Removing newest claimant chart.");
      EALifecycleRequestRemoval(LicenseFriendlyOnlineLimitMessage());
    }
    return;
  }

  if(LicenseErrorIsHardAuth(license_last_error))
  {
    PrintFormat("LICENSE HEARTBEAT FAILED (hard auth) error=%s. EA REMOVED.",
                (license_last_error == "" ? "unknown" : license_last_error));
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return;
  }

  if(LicenseErrorIsRetryable(license_last_error, license_last_http_status))
  {
    PrintFormat("[LicenseLane] Heartbeat retryable failure (http=%d, error=%s).",
                license_last_http_status,
                (license_last_error == "" ? "unknown" : license_last_error));
    return;
  }

  PrintFormat("[LicenseLane] Heartbeat non-retryable failure (http=%d, error=%s).",
              license_last_http_status,
              (license_last_error == "" ? "unknown" : license_last_error));
}

void LicenseOnline_OnDeinit()
{
  LicenseLaneReleaseLeadership();
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

#endif // _SERVICES_SHARED_LICENSE_GUARD_V1_ONLINE_MQH_
