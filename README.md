# Pure

A shared PHP code-quality standard for pull requests.
One Docker image per PHP version, containing every tool and the default config. Every project uses the same checks.

| Check | Tool | Fails the PR? |
|---|---|---|
| Syntax, for the project's PHP version | php-parallel-lint | yes |
| Static analysis | PHPStan | yes |
| Vulnerable dependencies | composer audit | yes |
| Coding standard (PSR-12) | PHP_CodeSniffer | warning |
| Compatibility with newer PHP | PHPCompatibility | warning |
| Complexity, unused code | PHPMD | warning |

On pull requests only the changed PHP files are checked. Problems appear as annotations on the diff, and a summary table appears on the run page.

## Add it to a project

`.github/workflows/quality.yml`:

```yaml
on: pull_request
jobs:
  pure:
    uses: rockberpro/pure/.github/workflows/check.yml@v1
    with:
      php_version: "7.4"
```

Optional inputs: `phpstan_level` (default 1, ignored if the project has `phpstan.neon`), `test_version` (PHPCompatibility, e.g. `"7.4-8.5"`) and `profile`.

### PHP versions

`php_version` is the PHP the app runs on today: it picks the image, and the syntax check runs on that exact interpreter. `test_version` is the range you want **warnings** for, e.g. `"7.4-8.5"` while planning an upgrade. Available: `7.4`, `8.0` to `8.5` (default `8.5`). Always quote them.

**Read [docs/php-versions.md](docs/php-versions.md)** for what each check does with the version, how to plan an upgrade, and how to add a new PHP version.

### Profiles

A profile picks the coding-standard rules. It only changes PHPCS **warnings**, never what blocks a merge.

| Profile | Use it for |
|---|---|
| `default` | New code, or code with namespaces |
| `legacy` | Old code without namespaces: `snake_case` methods, files that declare and run code |

A `phpcs.xml` at the project root overrides the profile. **Read [docs/profiles.md](docs/profiles.md)** for what each profile turns off, how to choose, how to customise and how to move from `legacy` to `default`.

Example for a legacy app (GitHub; on GitLab, put the same keys under `inputs:`):

```yaml
on: pull_request
jobs:
  pure:
    uses: rockberpro/pure/.github/workflows/check.yml@v1
    with:
      php_version: "7.4"
      profile: legacy
      test_version: "7.4-8.5"   # also warn about code that breaks on PHP 8
```

Then add a PHPStan baseline (see "Legacy code: start with a baseline" below) so only new errors fail.

### GitLab

`.gitlab-ci.yml`:

```yaml
include:
  - remote: https://raw.githubusercontent.com/rockberpro/pure/v1/gitlab/pure.yml
    inputs:
      php_version: "7.4"
```

This adds a `pure` job to merge request pipelines, in the `test` stage by default. If the project has custom stages, set the `stage` input. Findings go to GitLab Code Quality through the `codequality` artifact, and the log shows the same summary table. The other inputs match the GitHub workflow.

## Run it locally (same result as CI)

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:1-7.4                                 # all files
docker run --rm -v "$PWD:/app" -e PURE_BASE=origin/main ghcr.io/rockberpro/pure:1-7.4        # only your changes
```

## Legacy code: start with a baseline

The first full run on an old app reports thousands of issues. Record them once so that only **new** errors fail:

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:1-7.4 \
  phpstan analyse --level=1 -c /opt/pure/config/phpstan.neon --generate-baseline --allow-empty-baseline .
```

Then commit a `phpstan.neon`:

```neon
includes:
    - phpstan-baseline.neon
parameters:
    level: 1
```

Project config files (`phpstan.neon`, `phpcs.xml`) take priority over the defaults in `config/`.

## Versioning

Pure follows [SemVer](https://semver.org). Pin the major version: `@v1` on GitHub, `/v1/` in the GitLab URL. You get fixes and new features, never a change that can break your pipeline.

| Release | What changes | Example |
|---|---|---|
| **Major** (`v2`) | Can break your pipeline: a warning becomes blocking, an input is removed or renamed, a tool's major version is bumped (new errors), or a PHP version is dropped | PHPStan 2 → 3 |
| Minor (`v1.1.0`) | New things, all optional: an input, a profile, a PHP version, a warning-only check | the `legacy` profile |
| Patch (`v1.0.1`) | Fixes and docs | a report bug |

`v1` is a tag that moves to the newest `v1.x.y`. The templates use the images of the same major version (`:1-<php>`), so tools and rules only change with a v1 release. Pinning an exact tag (`@v1.0.0`) pins the templates, but they still use the `:1-<php>` images. `main` is the edge version and can change at any time, so don't point projects at it.

## Limitations

- **GitHub shows at most 10 error and 10 warning annotations per step**, and 50 per job. Anything beyond that is only in the job log and the summary table. Checking only changed files and using a PHPStan baseline keep most pull requests under the limit.
- **On GitLab, what the Code Quality report shows depends on your tier.** The merge request widget works on all tiers. Findings inline on the diff need a paid tier.
- **GitLab can't run two PHP versions in one pipeline yet.** Including the template twice creates two jobs named `pure`. Use `test_version` for upgrade warnings instead.
- **PHPCompatibility can lag behind the newest PHP.** Its checks for a brand new PHP version arrive after the release.
- **The pull request check covers only changed files.** An error that a change causes in a file it didn't touch (for example, removing a method that another file calls) isn't reported until that file changes. Running Pure without `PURE_BASE` checks every file (see "Run it locally").

## Maintaining Pure

- `config/` holds the defaults. Changes reach `@v1` projects with the next release.
- `.github/workflows/image.yml` builds the images. Pushes to `main` publish edge images (`:7.4`); release tags publish versioned ones (`:1.0.0-7.4`, `:1-7.4`). Make the package public, or give the projects that use it access.
- `tests/run.sh` runs the images against `tests/fixtures`. It also runs on every push (`self-test.yml`).
- **Releasing:** merge into `main`, then tag the release and move the major tag:

  ```bash
  git tag v1.2.0 && git push origin v1.2.0      # builds :1.2.0-<php> and :1-<php>
  git tag -f v1 && git push -f origin v1        # @v1 users now get 1.2.0
  ```

## License

MIT, see [LICENSE](LICENSE).
