//+------------------------------------------------------------------+
CBcrypt BCrypt;

string   base_primary_key = "D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE";
string   base_secret_key  = "example_secret";
string   base_ea_id       = "sniper_advanced_panel_ea";
string   base_source_id   = "trading_sniper_panel_source";
bool     valid_license    = false;

string SidToString(const uchar &sid[])
{
  string sidString;
  int sidLength = ArraySize(sid);

  for (int i = 0; i < sidLength; i++)
  {
    sidString += StringFormat("%02X", sid[i]);
    if (i < sidLength - 1) sidString += "-";
  }

  return sidString;
}

string EncryptEA(string email = "", string ea_id = "", int days = 34)
{
  account = email + "," + ea_id + "," + (string)(TimeCurrent() + (60 * 60 * 24 * days));

  BCrypt.Init(base_primary_key, base_secret_key, account);
  string encrypted_account = BCrypt.Encrypt();

  Print("NEW LICENSE KEY= ", encrypted_account);

  return encrypted_account;
}

bool DecryptEA()
{
  string license_privileges[];
  ushort u_sep = StringGetCharacter(",", 0);
  BCrypt.Init(base_primary_key, base_secret_key);
  string decrypted_account = BCrypt.Decrypt(EA_License_Key);

  int license_ok = StringSplit(decrypted_account, u_sep, license_privileges);

  if(license_ok < 2) { Print("Could not Decrypt the current License."); return false; }

  string 	 email 	 				= license_privileges[0];
  string   ea_id   				= license_privileges[1];
  datetime license_expire = (datetime)license_privileges[2];

  return RequestLicenseValidationEndpoint(email, ea_id);
}
