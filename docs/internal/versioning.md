<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Versioning

## `deck.toml`

`package.version` is the deck's only version; the deck exports no version
constant. It is authored and committed. jvc resolves against the manifest
on the default branch - `package.urls.deck` points at
`raw.githubusercontent.com/.../main/deck.toml` - so a version that only ever
existed in a CI workspace would leave jvc resolving a stale number. Bump the
manifest, commit, then tag to match; `release.yml` refuses a tag that
disagrees, and rejects a prerelease tag (`0.3.0-rc1`).

## The interpreter floor

Every `.j` file opens with `# pragma-jennifer-version: >=0.26.0`, which the
interpreter enforces when it reads the file. `tools/check-headers.sh` keeps
those in step with `engines.jennifer` in the manifest, and the licence header
with `package.license`.

A dev build of the interpreter bypasses the floor, so `tools/deck-lib.sh`
picks the CI container from the floor (`:0.26`) instead of `dev`. A
construct from a newer language version then fails CI instead of breaking
consumers on 0.26. The floor is 0.26.0 for the `binary` number readers
(`readUint`); until 0.26.0 is tagged CI runs on the `dev` image.
