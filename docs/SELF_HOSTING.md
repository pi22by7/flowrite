# Self-hosting Flowrite

Flowrite runs without Supabase or Google sign-in. New installations default to
**Local only**. The browser saves documents and pending sync operations together
in IndexedDB. Desktop/mobile builds save complete records using atomic file
replacement. WebDAV sync is optional and runs after local saves finish.

## Docker Compose

Requirements: Docker Engine with Compose v2. The initial image build downloads
Flutter and dependencies; normal writing and WebDAV sync need no Internet.

```sh
cp deploy/selfhost.env.example deploy/selfhost.env
# Edit deploy/selfhost.env and replace WEBDAV_PASSWORD.
docker compose --env-file deploy/selfhost.env up -d --build
```

The default address is `http://localhost:8080` on the server. The stack has:

- `flowrite`: Nginx serving the Flutter release build and proxying `/dav/`.
- `webdav`: authenticated Apache WebDAV, accessible only inside the stack.
- `flowrite_documents`: a named volume containing synced documents.

Put your existing HTTPS reverse proxy in front of the Flowrite service. Forward
the entire hostname, including `/dav/`, without removing the Authorization header.
Choose an available `FLOWRITE_PORT`; change `FLOWRITE_BIND` only if your reverse
proxy needs access from another host or container network. A reverse proxy on the
host can use the default `127.0.0.1` binding. A proxy in another container can join
the Compose network and reach `flowrite:80` instead of using the host binding.

Use HTTPS for access from another computer. Browsers require a secure context
for offline service workers and WebDAV credential storage; `http://localhost` is
also a secure context for local testing. Plain HTTP at a LAN IP is not sufficient
for all browser features.

## Connect sync

1. Open Flowrite at your final hostname, for example `https://lyrics.example.net`.
2. Open Settings → Cloud Sync → WebDAV.
3. Enter `https://lyrics.example.net/dav/`, plus the username and password from
   `deploy/selfhost.env`. Use the public hostname here, not `webdav:80`.
4. Test the connection, then save. All local documents are queued for the newly
   connected server. Documents on a previous backend are not deleted.
5. Configure the same WebDAV account on each additional device.

An existing Nextcloud or other WebDAV server can be used instead of the bundled
service. It must support HTTP Basic authentication, directory listing, PUT, and ETag conditional updates.
For browsers, a different hostname also requires that server to allow the app's
origin, methods, Authorization and Cache-Control headers, and ETag/conditional request headers via
CORS. Using the bundled same-origin `/dav/` endpoint avoids that configuration.

## Offline use and updates

Wait for the first online visit to finish installing the offline cache before
disconnecting. After that, the app shell, fonts, rendering engine, and bundled
pronunciation dictionary can load without the server. Documents stay in each
browser's IndexedDB and edits sync when the app is open and the server is reachable.
Sync runs shortly after edits, when the app returns to the foreground, at two-minute intervals, and on manual sync.
The editor also attempts a local save when the app is backgrounded. Let a save
finish before force-closing Safari; an operating system can suspend a tab before
an asynchronous write finishes.
Closing the browser does not keep a sync process running.

Emoji fallback fonts are included and served locally. To add fallback fonts for
other writing systems beyond the bundled typefaces, run the font-bundling script
with `--all-fonts` before generating the offline cache (or add that flag to the
font-bundling command in `scripts/build_web.sh`). This increases the initial download. Unbundled fallback fonts are
requested from the local server, never silently from Google's font CDN.

The rhyme-suggestion popup still calls the optional RhymeBrain Internet API.
Editing, local saves, and the bundled pronunciation tools do not require it.

To install a new version, rebuild/restart the stack, visit the app online, then
close all tabs for that app and reopen it. A new cache activates once the old tabs
close. Cached builds are versioned by their asset contents.

Keep the same hostname, scheme, and port: browser storage belongs to an origin.
Changing the address does not automatically move the old browser's documents or
WebDAV credentials. Connect sync or export documents before changing origins.

## Existing data and migration

Legacy browser preferences are copied to IndexedDB on first use. The migration
commits with its completion marker in one transaction; original preferences are
retained for recovery and are not used again after migration.

Native builds still read legacy `.text` files and preference metadata. The next
save writes an authoritative `<id>.flowrite.json` record containing the document,
metadata, and pending sync state. Back up these records, not just old `.text`
files. Changing the save location copies and verifies both formats before
switching locations.

If you have documents only in Supabase, first download them using an app/build
configured for that Supabase project, then connect WebDAV. Switching backends
queues the local copies; it cannot discover documents that have never been
downloaded. The default Docker build embeds empty cloud configuration.

Supabase remains optional. For a custom Supabase-enabled build, configure your
own `.env`, apply `database/migrations/002_document_tombstones.sql`, and build
locally. Only selecting Supabase initializes its client. Local-only mode neither
constructs a sync client nor processes the outbox; unsent changes are retained.

## Conflict and deletion behavior

Each WebDAV record is `/flowrite/<id>.json`. Updates use ETags so a concurrent
server change is retried instead of overwritten. Acknowledging an upload clears
only that exact pending operation; edits made during the upload remain pending.

When local and remote versions diverge, the newer timestamp wins and the losing
nonempty text is preserved as a separately named conflict backup. Deletion wins
over an unacknowledged stale copy, with a backup of any conflicting nonempty text.
This preserves versions; it is not collaborative character-by-character merging.
Keep device clocks synchronized for predictable timestamp selection.

Deleted records remain as tombstones. Do not manually remove these JSON records
while other devices might still have stale copies. There is no tombstone garbage
collection yet. Use manual Sync to retry operations whose automatic retries were
exhausted. Switching to Local only never discards pending operations.

Older app versions do not understand tombstones and conditional sync. Upgrade all
devices before sharing this WebDAV account with the new build.

## Backups

Browser data can be cleared or evicted, so sync important documents and keep a
separate server-volume backup. HTTPS encrypts traffic in transit; document JSON
in the server volume is plaintext, so protect those backups accordingly. Unsynced changes exist only on their originating
device. Settings → Export All downloads a ZIP of active local documents; exports
preserve Unicode and disambiguate duplicate titles.

For a consistent server backup, stop only the WebDAV service while archiving its
volume (browsers can continue saving locally):

```sh
docker compose --env-file deploy/selfhost.env stop webdav
mkdir -p backups
docker compose --env-file deploy/selfhost.env run --rm --no-deps \
  --entrypoint tar -v "$PWD/backups:/backup" webdav \
  czf /backup/flowrite-documents.tar.gz -C /var/lib/dav .
docker compose --env-file deploy/selfhost.env start webdav
```

Also preserve `deploy/selfhost.env` securely. Do not use `docker compose down -v`
unless you intend to delete the synced document volume.

## Local builds and checks

```sh
flutter pub get
flutter test
flutter analyze
bash scripts/build_web.sh
```

Serve the generated `build/web` directory over localhost or HTTPS. The build script bundles local rendering assets and fonts and generates the
offline cache. Docker and the web CI workflows use the same script automatically. Docker excludes
your local `.env` from its build context.
