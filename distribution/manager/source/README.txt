HAPLOBOX MANAGER HM26.1.0 TEST — SYNC-01 phase 1
Windows 10/11, Python 3.10+ with Tkinter (standard Python Windows installation).
Extract to a permanent folder outside WoW. Run START.cmd. Default: D:\World of Warcraft\_forever_.
SCAN; choose any source; select targets; select settings; PREVIEW; close ALL WoW clients; COPY SETTINGS.
Supported: character layout-local.txt and optional character bindings-cache.wtf (unchecked by default).
Does not copy account-wide bindings, macros, config-cache.wtf, full WTF, or ANY addon SavedVariables. Questie/Zygor and other addon-specific visual adapters are not yet implemented.
UPDATE opens existing HaploBox UPDATE desktop shortcut with WoW closed. Original updater and manifest unchanged.
Backups automatically written before copying to %LOCALAPPDATA%\HaploBoxManager\Backups. RESTORE selects a backup directory; rejects files changed after copy. STATUS shows transaction log.
No standalone manual backup button yet. Backups are transaction-specific. No auto-update or background process.
Offline file tests included. Windows GUI/process check and actual WoW layout acceptance NOT tested. Start with a non-critical test character. Keep WoW closed during the operation. Do not modify files externally during a transaction.
