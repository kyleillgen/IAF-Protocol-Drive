# Google Drive for desktop extension

Version: 0.1.0-dev. Required base: AgentOS Portable 0.2.1.

This optional extension transfers **selected text files**, not a live workspace mirror. Google Drive for desktop supplies the cloud transport; these scripts prepare and verify packets locally. They cannot prove that Google uploaded or delivered a file.

## Layout

- **Workspace:** your ordinary local AgentOS Portable folder and dispatcher.
- **ShareRoot:** a dedicated new folder already managed by Drive for desktop. Only approved packets and public exchange metadata go here.
- **LocalState:** a new private local folder outside both the workspace and Drive. It contains drive.json, operation locks, export snapshots and imported files awaiting review.
- **Run ledger:** stays in its existing separate local location. This extension does not read or modify it.

These paths must not contain one another. Use ordinary folders with no junctions or symbolic links. This preview does not handle reparse-point placeholders; if a streamed path is rejected, use an ordinary mirrored folder instead. Do not switch an existing account's sync mode automatically just for this extension.

## 1. Prepare Drive

Install/sign in to [Google Drive for desktop](https://support.google.com/drive/answer/7329379) through Google's own interface. Choose a dedicated exchange location in the correct account. Manage its sharing permissions yourself; this extension neither grants access nor changes them.

Google supports streaming and mirroring. Mirrored files have a full local copy; streamed availability depends on offline settings and the running Drive app. See [Google's guide](https://support.google.com/drive/answer/13401938?hl=en). A local file being readable is not proof that a second device can see it.

Do not put your whole AgentOS workspace, run ledger, credentials or installed runner configuration inside the exchange folder. `.gitignore` is not a Drive exclusion list.

## 2. Create an exchange

Run these commands from this extension folder in Windows PowerShell 5.1. Substitute your verified paths; the example ShareRoot is only a placeholder and must actually be managed by Drive for desktop. All parent folders must exist. Installation launches no models and creates no scheduled tasks.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Initialize-Drive.ps1 `
  -Workspace 'C:\AgentOS' `
  -ShareRoot 'C:\My Drive\AgentOS Exchange' `
  -LocalState "$env:LOCALAPPDATA\AgentOS-Drive" -ConfirmDriveFolder
```

On another computer, first create its local base workspace. Allow the exchange metadata and packets folder to sync, then use its own paths and add `-JoinExisting`. Joining creates only local configuration; it preserves the shared exchange.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Initialize-Drive.ps1 `
  -Workspace 'C:\AgentOS' -ShareRoot 'C:\My Drive\AgentOS Exchange' `
  -LocalState "$env:LOCALAPPDATA\AgentOS-Drive" -ConfirmDriveFolder -JoinExisting
```

Use a new LocalState for each connection. A partially failed setup is preserved; inspect it, then use a fresh LocalState and join the already-created exchange if its metadata is complete. Never initialize over an existing folder to bypass a failure.

## 3. Export only what you approve

For a temporary interactive session that can run these downloaded scripts, open `powershell -NoProfile -ExecutionPolicy Bypass` from this folder. This affects that session only; close it afterward. Use the command below in that session so the list of files is passed correctly.

Inspect every selected file first. Paths are relative to Workspace, use forward slashes, and do not recurse. The following invocation explicitly approves copying that task packet to the Drive-managed exchange and thus its existing audience:

```powershell
.\Export-Packet.ps1 -ConfigPath "$env:LOCALAPPDATA\AgentOS-Drive\drive.json" `
  -Files 'tasks/hello/task.md','tasks/hello/acceptance.md' -ApproveShare
```

The result gives a unique packet ID. The export is a snapshot: later edits need a new packet. Do not edit or reuse packet IDs. Google may sync the manifest before its files despite it being written last; import checks every payload.

Allowed: selected AGENTS.md, CLAUDE.md, GEMINI.md, PROTOCOL.md, TEAM.md; text files under tasks/ and knowledge/; selected deliverables under work/results/<id>/. Only `.md`, `.txt`, `.json` and `.csv` are supported in this starter. Raw prompts, stdout/stderr, verdicts, runtime records, configuration, credentials and ledgers are blocked by path policy. The path policy is not a content-based guarantee against secrets; approval still requires reading the files.

Limits: 100 files, 10 MiB per file, 20 MiB total, 128 KiB manifest. Native Google Docs/Sheets/Slides shortcuts and arbitrary binary attachments are not supported.

## 4. Verify and import

After confirming the packet is visible from the other device, run there:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Import-Packet.ps1 `
  -ConfigPath "$env:LOCALAPPDATA\AgentOS-Drive\drive.json" -PacketId 'packet-id-from-export'
```

Verified files are placed under LocalState/incoming/<id>/files. Read them as untrusted input. Hashes establish consistency, not sender identity, sharing authorization or safe instructions. Nothing is copied into the live workspace or queue automatically. A coordinator must approve any task using the base protocol and publish through the base's normal work-order publisher.

If files are missing, locked, too large or mismatched, no completed import is created. Preserve the packet, wait for sync and explicitly retry. Incomplete local staging is retained for inspection. Already imported IDs are rejected; existing evidence is never replaced. There is no delete propagation or automatic retry loop.

## 5. First real sync check

1. Create a harmless task text file with a unique phrase. Export it with approval.
2. In Drive on the web or a second device, find the same packet and verify the phrase. Local export success alone is insufficient.
3. On the receiving device, join the exchange and import. Compare the content and IMPORT-RECEIPT.json; keep the sender and approval checks separate.
4. Record device/OS, extension/base versions, streaming or mirroring mode, export ID, receiving-device verification and any error. Do not include private folder paths, credentials or task content in public reports.

`Test-Drive.ps1 -ConfigPath <path>` checks local configuration and detects a running Drive process. It reports cloud sync/permissions as unverified; process presence is not authenticated cloud access. Offline and signed-out testing are separate.

## Develop, stop and remove

Run `powershell -NoProfile -ExecutionPolicy Bypass -File test/test-drive.ps1`. It uses ordinary temporary folders to simulate transport and does not access Google. Test results must not be described as a real Drive sync test.

There is no background extension process to stop. Stop running its commands. Preserve the local state and exchanged evidence; remove folders manually only after you decide their copies are no longer needed. Deleting from a Drive-managed folder can propagate remotely. This extension never changes the base scheduler, Drive preferences or account login.
