/**
 * Sourcemod 1.7 Plugin Template
 */
#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

#define PLUGIN_VERSION "0.4.0"
public Plugin myinfo = {
    name = "Localization Server",
    author = "nosoop",
    description = "Serves up localizations from a generated database.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop/SM-LocalizationServer/"
}

#define DATABASE_ENTRY "localization-db"
#define MAX_LANGUAGE_NAME_LENGTH 32

Database g_LanguageDatabase;
DBStatement g_StmtGetLocalizedString;

typedef LocalizedStringCallback = function void(int language, const char[] token, const char[] result, any data);

public void OnPluginStart() {
	char error[256];
	g_LanguageDatabase = SQLite_UseDatabase("language-db", error, sizeof(error));

	if (g_LanguageDatabase == null) {
		SetFailState("Failed to access localization strings database: %s", error);
	}
	
	g_StmtGetLocalizedString = SQL_PrepareQuery(g_LanguageDatabase,
			"SELECT string FROM localizations WHERE token = ? AND language = ?", error, sizeof(error));
	if (g_StmtGetLocalizedString == null) {
		SetFailState("Failed to create prepared statement for GetLocalizedString() -- %s", error);
	}
	
	CreateConVar("localization_server_version", PLUGIN_VERSION, "Current version of Localization Server", FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

/* Methods and natives */

public int Native_GetLocalizedString(Handle plugin, int nArgs) {
	int tokenLength;
	
	// off by 1?
	GetNativeStringLength(2, tokenLength);
	tokenLength++;
	
	char[] token = new char[tokenLength];
	
	int language = GetNativeCell(1);
	GetNativeString(2, token, tokenLength);
	LocalizedStringCallback callback = view_as<LocalizedStringCallback>(GetNativeFunction(3));
	any data = GetNativeCell(4);
	
	Handle fwd = CreateLocalizedStringCallbackForward(plugin, callback);
	Internal_GetLocalizedString(fwd, language, token, data);
}

public int Native_ResolveLocalizedString(Handle plugin, int nArgs) {
	int tokenLength;
	GetNativeStringLength(2, tokenLength);
	tokenLength++;
	
	char[] token = new char[tokenLength];
	
	int language = GetNativeCell(1);
	GetNativeString(2, token, tokenLength);
	
	int maxlen = GetNativeCell(4);
	char[] buffer = new char[maxlen];
	
	bool result = Internal_ResolveLocalizedString(language, token, buffer, maxlen);
	SetNativeString(3, buffer, maxlen);
	
	return result;
}

/* Internal query methods */

Handle CreateLocalizedStringCallbackForward(Handle plugin = INVALID_HANDLE, LocalizedStringCallback callback) {
	Handle fwd = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	AddToForward(fwd, plugin, callback);
	return fwd;
}

void Internal_GetLocalizedString(Handle callbackFwd, int language, const char[] token, any data = 0) {
	char languageName[MAX_LANGUAGE_NAME_LENGTH];
	GetLanguageInfo(language, _, _, languageName, sizeof(languageName));
	
	char query[256], escapedToken[128];
	g_LanguageDatabase.Escape(token, escapedToken, sizeof(escapedToken));
	
	Format(query, sizeof(query),
			"SELECT token, string FROM localizations WHERE token = '%s' AND language = '%s'", escapedToken, languageName);
	
	DataPack dataPack = new DataPack();
	dataPack.WriteCell(language);
	dataPack.WriteCell(data);
	dataPack.WriteCell(callbackFwd);
	dataPack.WriteString(token);
	
	g_LanguageDatabase.Query(Internal_LocalizedStringQueryCallback, query, dataPack);
}

public void Internal_LocalizedStringQueryCallback(Database db, DBResultSet results, const char[] error, DataPack dataPack) {
	dataPack.Reset();
	
	// we only use the packed token in case of an error (might be truncated)
	char packedToken[128];
	
	int language = dataPack.ReadCell();
	any data = dataPack.ReadCell();
	Handle callbackFwd = dataPack.ReadCell();
	dataPack.ReadString(packedToken, sizeof(packedToken));
	
	delete dataPack;
	
	if (results.RowCount < 1) {
		ThrowError("Could not find localized string for token %s.", packedToken);
		delete callbackFwd;
		return;
	}
	
	// token
	int bufferSize = results.FetchSize(0) + 1;
	char[] token = new char[bufferSize];
	results.FetchString(0, token, bufferSize);
	
	// string
	bufferSize = results.FetchSize(1) + 1;
	char[] resultString = new char[bufferSize];
	results.FetchString(1, resultString, bufferSize);
	
	PerformLocalizedStringCallback(callbackFwd, language, token, resultString, data);
}

bool Internal_ResolveLocalizedString(int language, const char[] token, char[] buffer, int maxlen) {
	char languageName[MAX_LANGUAGE_NAME_LENGTH];
	GetLanguageInfo(language, _, _, languageName, sizeof(languageName));
	
	g_StmtGetLocalizedString.BindString(0, token, true);
	g_StmtGetLocalizedString.BindString(1, languageName, true);
	
	// apparently prepared statements can't be threaded yet!
	SQL_Execute(g_StmtGetLocalizedString);
	SQL_FetchRow(g_StmtGetLocalizedString);
	
	SQL_FetchString(g_StmtGetLocalizedString, 0, buffer, maxlen);
	
	return true;
}

void PerformLocalizedStringCallback(Handle fwd, int language, const char[] token, const char[] result, any data) {
	Call_StartForward(fwd);
	Call_PushCell(language);
	Call_PushString(token);
	Call_PushString(result);
	Call_PushCell(data);
	Call_Finish();
	
	delete fwd;
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] strError, int iMaxErrors) {
	RegPluginLibrary("localization-server");
	CreateNative("LanguageServer_GetLocalizedString", Native_GetLocalizedString);
	CreateNative("LanguageServer_ResolveLocalizedString", Native_ResolveLocalizedString);
}