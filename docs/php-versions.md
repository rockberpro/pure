# PHP versions

Pure has one image per PHP version: `ghcr.io/rockberpro/pure:1-<version>` for the v1 release line (see [Versioning](../README.md#versioning)). The project picks its version with two inputs, and they answer different questions:

| Input | Question it answers | Example |
|---|---|---|
| `php_version` | Which PHP does the app **run on today**? | `"7.4"` |
| `test_version` | Which PHP versions do you want **warnings** for? | `"7.4-8.5"` |

```yaml
with:                        # GitHub (on GitLab, the same keys go under inputs:)
  php_version: "7.4"
  test_version: "7.4-8.5"    # optional
```

## Available versions

`7.4`, `8.0`, `8.1`, `8.2`, `8.3`, `8.4`, `8.5`. If you leave `php_version` out, you get `8.5`.

A version that isn't in this list (for example `"7.3"` or `"7"`) fails the job before any check runs, because the image doesn't exist (`manifest unknown`). Always use `major.minor` in quotes: YAML reads an unquoted `8.0` as the number `8`.

## What `php_version` changes in each check

| Check | Uses `php_version`? |
|---|---|
| **Syntax** (php-parallel-lint) | **Yes, exactly.** The check runs on that real PHP interpreter, so it accepts exactly what that version accepts. `match` fails on `7.4` and passes on `8.0`+. |
| **Static analysis** (PHPStan) | **Usually.** PHPStan takes the version from, in this order: `phpVersion` in the project's `phpstan.neon`, then `require.php` in `composer.json`, then the PHP it runs on (`php_version`). If your `composer.json` says `"php": ">=7.2"`, PHPStan checks against that range, not only 7.4. |
| **PHP compatibility** (PHPCompatibility) | **Indirectly.** It follows `test_version`. When `test_version` is empty, it uses `"<php_version>-"`, meaning "this version and newer". |
| Coding standard, complexity, composer audit | No. Same rules on every version. |

The image also decides **which tool versions** you get. Each image installs the newest release of each tool that still runs on its PHP, so the `7.4` image may have an older PHPStan or PHPCS release than the `8.5` image. Results on different images can differ slightly for that reason.

## `test_version`: warnings about other PHP versions

`test_version` only affects PHPCompatibility, which only produces warnings. It never blocks a merge.

| Value | Meaning | Typical use |
|---|---|---|
| empty (default) | `"<php_version>-"`, e.g. `"7.4-"`: this version and every newer one | Warns about what will break when you upgrade |
| `"7.4-8.5"` | Code must work on every version from 7.4 to 8.5 | Planning an upgrade to a known target |
| `"8.2"` | Only 8.2 | Rarely useful |

Example warnings with `php_version: "7.4"`: `each()` "removed since PHP 8.0", `create_function()`, `${var}` string interpolation (deprecated in 8.2).

## Planning an upgrade (e.g. 7.4 → 8.x)

**Step 1: warnings first.** Keep `php_version` at what production runs and set `test_version` to the target range. Every pull request then shows warnings for code that won't survive the upgrade, without blocking anything.

```yaml
php_version: "7.4"
test_version: "7.4-8.4"
```

**Step 2 (GitHub): run the target version too.** A matrix runs the full checks on both versions. The 8.x run shows real syntax and PHPStan results for the new version:

```yaml
jobs:
  pure:
    strategy:
      fail-fast: false
      matrix:
        php: ["7.4", "8.4"]
    uses: rockberpro/pure/.github/workflows/check.yml@v1
    with:
      php_version: ${{ matrix.php }}
      test_version: "7.4-8.4"
```

In branch protection, **require only the `7.4` check**. The 8.4 run is information until you migrate. GitHub doesn't allow `continue-on-error` on a reusable workflow call, so leaving it out of the required checks is how you keep it from blocking.

On GitLab, including the template twice doesn't work yet, because both copies create a job named `pure`. Use step 1 there.

**Step 3: switch.** When production moves to 8.x, change `php_version` and drop the matrix.

## Running locally

Use the same tag as CI, or you'll get different results:

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:1-7.4                            # like php_version: "7.4"
docker run --rm -v "$PWD:/app" -e PURE_TEST_VERSION=7.4-8.4 ghcr.io/rockberpro/pure:1-7.4
```

Your laptop's PHP doesn't matter. Everything runs inside the image.

## Adding a PHP version (Pure maintainers)

When a new PHP version is released (for example 8.6) and the official `php:8.6-cli-alpine` image exists:

1. Add `"8.6"` to the `php` matrix in `.github/workflows/image.yml`.
2. Merge into `main` (this builds the edge image `:8.6`), then tag a minor release. The release builds `:1.x.0-8.6` and `:1-8.6`, which `@v1` users get.
3. Optionally move the default `php_version` in `.github/workflows/check.yml` and `gitlab/pure.yml`, and the newest version used in `tests/run.sh` and `self-test.yml`, to the new version.
4. Update the "Available versions" list in this file.

If a tool doesn't support the new version yet, the image build fails at `composer global require`. Wait for the tool's release instead of pinning an old version.
