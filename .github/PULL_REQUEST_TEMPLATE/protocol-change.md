<!-- Protocol change PR template -->
## Summary

Describe the protocol change in one sentence. Include protocol version bump (e.g. v1.2 -> v1.3).

## Checklist

- [ ] Run `ajv validate -s shared/rules.schema.json -d shared/rules.json` locally (or rely on CI)
- [ ] Stamp protocol version locally: `scripts/build.fish stamp_version` (or run equivalent commands)
- [ ] Confirm `game-server/export/version.txt` and `web-client/export/version.txt` show the new version
- [ ] Add notes about backwards compatibility and migration steps

## Notes for reviewer

Explain why the protocol bump is necessary and any risks for client/server compatibility.

CI will run `validate-rules` and `check-protocol-drift` before merge. CODEOWNERS will request review from the repo owner.
