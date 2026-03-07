#ifndef __BROKER_ACCOUNT_DAILY_RESULTS_ONLINE_MQH__
#define __BROKER_ACCOUNT_DAILY_RESULTS_ONLINE_MQH__
#property strict

const string daily_results_api_path = "/api/v1/broker_accounts/daily_results";
const int daily_results_timer_check_seconds = 60;
const int daily_results_retry_seconds = 300;
const int daily_results_retry_max_seconds = 3600;
const int daily_results_missing_broker_retry_seconds = 120;

datetime daily_results_last_timer_check = 0;
datetime daily_results_next_attempt_at = 0;
datetime daily_results_last_reported_day_utc = 0;
datetime daily_results_blocked_day_utc = 0;
datetime daily_results_last_reverify_day_utc = 0;
int daily_results_consecutive_failures = 0;
string daily_results_last_error = "";
int daily_results_last_http_status = 0;

enum DailyResultsSubmitState
{
  DAILY_RESULTS_SUBMIT_SUCCESS = 0,
  DAILY_RESULTS_SUBMIT_ALREADY_RECORDED = 1,
  DAILY_RESULTS_SUBMIT_MISSING_BROKER = 2,
  DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD = 3,
  DAILY_RESULTS_SUBMIT_AUTH_ERROR = 4,
  DAILY_RESULTS_SUBMIT_RETRY = 5
};

string DailyResults_Trim(const string value)
{
  string v=value;
  StringTrimLeft(v);
  StringTrimRight(v);
  return v;
}

string DailyResults_SanitizeToken(const string value)
{
  string result="";
  int len=StringLen(value);
  for(int i=0;i<len;i++)
  {
    int ch=StringGetCharacter(value,i);
    bool allowed=(ch>='0' && ch<='9') ||
                 (ch>='A' && ch<='Z') ||
                 (ch>='a' && ch<='z') ||
                 ch=='_' || ch=='-';
    if(allowed)
      result+=CharToString((uchar)ch);
    else
      result+="_";
  }
  if(result=="")
    result="_";
  return result;
}

string DailyResults_GlobalReportedKey()
{
  long account_login=(long)AccountInfoInteger(ACCOUNT_LOGIN);
  string ea_key=license_ea_id;
  if(ea_key=="")
    ea_key=base_ea_id_key;
  long magic_number=LicenseGetCachedMagicNumber();
  if(magic_number<=0)
    return "";
  return "SNP_AP_DAILY_REPORTED_" + StringFormat("%I64d",account_login) +
         "_" + DailyResults_SanitizeToken(ea_key) +
         "_" + StringFormat("%I64d",magic_number);
}

datetime DailyResults_ReadGlobalLastReportedDay()
{
  string key=DailyResults_GlobalReportedKey();
  if(key=="")
    return 0;
  if(!GlobalVariableCheck(key))
    return 0;

  double value=GlobalVariableGet(key);
  if(value<=0.0)
    return 0;

  return (datetime)((long)value);
}

void DailyResults_WriteGlobalLastReportedDay(const datetime day_start_utc)
{
  string key=DailyResults_GlobalReportedKey();
  if(key=="")
    return;
  GlobalVariableSet(key,(double)((long)day_start_utc));
}

datetime DailyResults_UtcDayStart(const datetime ts_utc)
{
  long seconds=(long)ts_utc;
  if(seconds<=0)
    return 0;
  return (datetime)(seconds - (seconds % 86400));
}

datetime DailyResults_TargetCompletedUtcDayStart()
{
  datetime now_utc=TimeGMT();
  if(now_utc<=86400)
    return 0;

  datetime today_start_utc=DailyResults_UtcDayStart(now_utc);
  return today_start_utc - 86400;
}

int DailyResults_ServerUtcOffsetSeconds()
{
  datetime server_now=TimeCurrent();
  datetime utc_now=TimeGMT();
  return (int)(server_now - utc_now);
}

double DailyResults_Round2(const double value)
{
  double rounded=NormalizeDouble(value,2);
  if(rounded>-0.005 && rounded<0.005)
    rounded=0.0;
  return rounded;
}

string DailyResults_Format2(const double value)
{
  return DoubleToString(DailyResults_Round2(value),2);
}

bool DailyResults_IsAuthError(const string error_code)
{
  if(License_IsAuthError(error_code))
    return true;
  if(error_code=="expired") return true;
  if(error_code=="license_not_found") return true;
  if(error_code=="user_not_found") return true;
  if(error_code=="ea_not_found") return true;
  if(error_code=="missing_magic_number") return true;
  if(error_code=="invalid_magic_number") return true;
  return false;
}

bool DailyResults_CalcNetClosedPnlForUtcDay(const datetime day_start_utc,
                                            const long magic_number,
                                            double &pnl_out,
                                            int &deals_out)
{
  pnl_out=0.0;
  deals_out=0;
  if(magic_number<=0)
    return false;
  datetime day_end_utc=day_start_utc + 86400;
  if(day_end_utc<=day_start_utc)
    return false;

  int offset_seconds=DailyResults_ServerUtcOffsetSeconds();
  datetime select_from=day_start_utc + offset_seconds;
  datetime select_to=day_end_utc + offset_seconds - 1;
  if(select_to<select_from)
    select_to=select_from;

  ResetLastError();
  if(!HistorySelect(select_from,select_to))
  {
    int err=GetLastError();
    PrintFormat("[DailyResults] HistorySelect failed (error %d).",err);
    return false;
  }

  int total=HistoryDealsTotal();
  for(int i=0;i<total;i++)
  {
    ulong ticket=HistoryDealGetTicket(i);
    if(ticket==0)
      continue;

    datetime deal_time_server=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
    datetime deal_time_utc=deal_time_server - offset_seconds;
    if(deal_time_utc<day_start_utc || deal_time_utc>=day_end_utc)
      continue;

    ENUM_DEAL_ENTRY deal_entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
    if(deal_entry!=DEAL_ENTRY_OUT && deal_entry!=DEAL_ENTRY_INOUT)
      continue;

    ENUM_DEAL_TYPE deal_type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
    if(deal_type!=DEAL_TYPE_BUY && deal_type!=DEAL_TYPE_SELL)
      continue;

    long deal_magic=(long)HistoryDealGetInteger(ticket,DEAL_MAGIC);
    if(deal_magic!=magic_number)
      continue;

    double deal_profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
    double deal_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
    double deal_commission=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
    double deal_fee=HistoryDealGetDouble(ticket,DEAL_FEE);
    double deal_net=deal_profit + deal_swap + deal_commission + deal_fee;
    if(!MathIsValidNumber(deal_net))
      continue;

    pnl_out+=deal_net;
    deals_out++;
  }

  pnl_out=DailyResults_Round2(pnl_out);
  return true;
}

string DailyResults_EffectiveBrokerCompany()
{
  if(license_broker_company!="")
    return license_broker_company;
  return AccountInfoString(ACCOUNT_COMPANY);
}

long DailyResults_EffectiveBrokerAccountNumber()
{
  if(license_broker_account_number>0)
    return license_broker_account_number;
  return (long)AccountInfoInteger(ACCOUNT_LOGIN);
}

string DailyResults_EffectiveBrokerAccountType()
{
  if(license_broker_account_type=="real" || license_broker_account_type=="demo")
    return license_broker_account_type;

  string account_type=AccountTypeToString();
  if(account_type=="real" || account_type=="demo")
    return account_type;

  return "";
}

int DailyResults_ComputeRetryDelaySeconds()
{
  int attempts=daily_results_consecutive_failures;
  if(attempts<1)
    attempts=1;
  int delay=daily_results_retry_seconds * attempts;
  if(delay>daily_results_retry_max_seconds)
    delay=daily_results_retry_max_seconds;
  return delay;
}

void DailyResults_ScheduleRetry(const datetime now_server,const int fixed_delay_seconds=0)
{
  int delay=(fixed_delay_seconds>0 ? fixed_delay_seconds : DailyResults_ComputeRetryDelaySeconds());
  daily_results_next_attempt_at=now_server + (datetime)delay;
  PrintFormat("[DailyResults] Retry scheduled in %d seconds (http=%d, error=%s).",
              delay,
              daily_results_last_http_status,
              (daily_results_last_error=="" ? "unknown" : daily_results_last_error));
}

DailyResultsSubmitState DailyResults_SubmitDay(const datetime day_start_utc)
{
  daily_results_last_error="";
  daily_results_last_http_status=0;
  long magic_number=LicenseGetCachedMagicNumber();
  if(magic_number<=0)
  {
    daily_results_last_error="missing_magic_number";
    return DAILY_RESULTS_SUBMIT_AUTH_ERROR;
  }

  double net_result=0.0;
  int closed_deals=0;
  if(!DailyResults_CalcNetClosedPnlForUtcDay(day_start_utc,magic_number,net_result,closed_deals))
  {
    daily_results_last_error="history_unavailable";
    return DAILY_RESULTS_SUBMIT_RETRY;
  }

  string source=DailyResults_Trim(source_secret_key);
  string email=DailyResults_Trim(license_email);
  string ea_id=DailyResults_Trim(license_ea_id);
  string license_key=DailyResults_Trim(EA_License_Key);
  string broker_company=DailyResults_Trim(DailyResults_EffectiveBrokerCompany());
  long broker_account_number=DailyResults_EffectiveBrokerAccountNumber();
  string broker_account_type=DailyResults_Trim(DailyResults_EffectiveBrokerAccountType());
  if(source=="" || email=="" || ea_id=="" || license_key=="")
  {
    daily_results_last_error="invalid_license_context";
    return DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD;
  }
  if(broker_company=="" || broker_account_number<=0 || broker_account_type=="")
  {
    daily_results_last_error="invalid_broker_account_context";
    return DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD;
  }

  string result_value=DailyResults_Format2(net_result);
  JSON::Object payload;
  payload.setProperty("source",source);
  payload.setProperty("email",email);
  payload.setProperty("ea_id",ea_id);
  payload.setProperty("license_key",license_key);
  payload.setProperty("magic_number",magic_number);

  JSON::Object *broker_account=new JSON::Object();
  broker_account.setProperty("company",broker_company);
  broker_account.setProperty("account_number",broker_account_number);
  broker_account.setProperty("account_type",broker_account_type);
  payload.setProperty("broker_account",broker_account);
  payload.setProperty("result_timestamp",(long)day_start_utc);
  payload.setProperty("result_value",result_value);

  string url=license_api_base_url + daily_results_api_path;
  string response_body="";
  int status_code=0;
  if(!HttpPostJson(url,payload.toString(),response_body,status_code))
  {
    daily_results_last_error="request_failed";
    return DAILY_RESULTS_SUBMIT_RETRY;
  }

  daily_results_last_http_status=status_code;
  string response_copy=response_body;
  JSON::Object response(response_copy);
  bool ok=response.isBoolean("ok") ? response.getBoolean("ok") : false;
  string error="";
  if(response.isString("error"))
    error=response.getString("error");
  daily_results_last_error=error;

  if(status_code>=200 && status_code<300 && ok)
  {
    PrintFormat("[DailyResults] Submitted UTC day=%d result=%s deals=%d (HTTP %d).",
                (int)day_start_utc,
                result_value,
                closed_deals,
                status_code);
    return DAILY_RESULTS_SUBMIT_SUCCESS;
  }

  if(status_code==409 && error=="already_recorded")
    return DAILY_RESULTS_SUBMIT_ALREADY_RECORDED;
  if(status_code==404 && error=="broker_account_not_found")
    return DAILY_RESULTS_SUBMIT_MISSING_BROKER;
  if(status_code==422 && error=="invalid_payload")
    return DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD;
  if(status_code==429 || error=="rate_limited")
    return DAILY_RESULTS_SUBMIT_RETRY;
  if(status_code>=500)
    return DAILY_RESULTS_SUBMIT_RETRY;
  if(status_code==401 || status_code==403 || DailyResults_IsAuthError(error))
    return DAILY_RESULTS_SUBMIT_AUTH_ERROR;
  if(error=="invalid_payload")
    return DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD;

  return DAILY_RESULTS_SUBMIT_RETRY;
}

void DailyResults_MarkReportedDay(const datetime day_start_utc,const bool already_recorded)
{
  daily_results_last_reported_day_utc=day_start_utc;
  DailyResults_WriteGlobalLastReportedDay(day_start_utc);
  daily_results_next_attempt_at=0;
  daily_results_consecutive_failures=0;
  daily_results_blocked_day_utc=0;
  daily_results_last_error="";
  if(already_recorded)
  {
    PrintFormat("[DailyResults] UTC day=%d already recorded on backend. Local state synced.",
                (int)day_start_utc);
  }
}

void DailyResults_HandleSubmitFailure(const datetime now_server,
                                      const datetime target_day_start_utc,
                                      const DailyResultsSubmitState state)
{
  if(daily_results_last_error=="missing_magic_number" ||
     daily_results_last_error=="invalid_magic_number")
  {
    PrintFormat("[DailyResults] Hard auth failure (error=%s). Removing EA.",
                daily_results_last_error);
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return;
  }

  if(state==DAILY_RESULTS_SUBMIT_INVALID_PAYLOAD)
  {
    daily_results_blocked_day_utc=target_day_start_utc;
    daily_results_next_attempt_at=0;
    PrintFormat("[DailyResults] Blocking UTC day=%d after invalid payload (http=%d, error=%s).",
                (int)target_day_start_utc,
                daily_results_last_http_status,
                (daily_results_last_error=="" ? "unknown" : daily_results_last_error));
    return;
  }

  daily_results_consecutive_failures++;
  if(state==DAILY_RESULTS_SUBMIT_MISSING_BROKER)
  {
    DailyResults_ScheduleRetry(now_server,daily_results_missing_broker_retry_seconds);
    return;
  }

  if(state==DAILY_RESULTS_SUBMIT_AUTH_ERROR)
  {
    DailyResults_ScheduleRetry(now_server,daily_results_retry_max_seconds);
    return;
  }

  DailyResults_ScheduleRetry(now_server,0);
}

void DailyResults_ResetRuntime()
{
  daily_results_last_timer_check=0;
  daily_results_next_attempt_at=0;
  daily_results_last_reported_day_utc=DailyResults_ReadGlobalLastReportedDay();
  daily_results_blocked_day_utc=0;
  daily_results_last_reverify_day_utc=0;
  daily_results_consecutive_failures=0;
  daily_results_last_error="";
  daily_results_last_http_status=0;
}

void DailyResults_OnTimer()
{
  if(is_testing)
    return;
  if(last_validation_time==0)
    return;

  datetime now_server=TimeCurrent();
  if(daily_results_last_timer_check!=0 &&
     (now_server-daily_results_last_timer_check)<daily_results_timer_check_seconds)
    return;
  daily_results_last_timer_check=now_server;

  if(daily_results_next_attempt_at>0 && now_server<daily_results_next_attempt_at)
    return;

  datetime target_day_start_utc=DailyResults_TargetCompletedUtcDayStart();
  if(target_day_start_utc<=0)
    return;

  datetime global_last_reported=DailyResults_ReadGlobalLastReportedDay();
  if(global_last_reported>daily_results_last_reported_day_utc)
    daily_results_last_reported_day_utc=global_last_reported;
  if(daily_results_last_reported_day_utc==target_day_start_utc)
    return;
  if(daily_results_blocked_day_utc==target_day_start_utc)
    return;

  DailyResultsSubmitState state=DailyResults_SubmitDay(target_day_start_utc);
  if(state==DAILY_RESULTS_SUBMIT_SUCCESS)
  {
    DailyResults_MarkReportedDay(target_day_start_utc,false);
    return;
  }
  if(state==DAILY_RESULTS_SUBMIT_ALREADY_RECORDED)
  {
    DailyResults_MarkReportedDay(target_day_start_utc,true);
    return;
  }
  if(state==DAILY_RESULTS_SUBMIT_MISSING_BROKER &&
     daily_results_last_reverify_day_utc!=target_day_start_utc)
  {
    daily_results_last_reverify_day_utc=target_day_start_utc;
    Print("[DailyResults] broker_account_not_found. Requesting leader license re-verify.");
    if(LicenseOnline_RequestLeaderReverify("daily_results_missing_broker"))
    {
      state=DailyResults_SubmitDay(target_day_start_utc);
      if(state==DAILY_RESULTS_SUBMIT_SUCCESS)
      {
        DailyResults_MarkReportedDay(target_day_start_utc,false);
        return;
      }
      if(state==DAILY_RESULTS_SUBMIT_ALREADY_RECORDED)
      {
        DailyResults_MarkReportedDay(target_day_start_utc,true);
        return;
      }
    }
  }

  DailyResults_HandleSubmitFailure(now_server,target_day_start_utc,state);
}

#endif
