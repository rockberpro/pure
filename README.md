# Pure

The company PHP code-quality standard for pull requests.
One Docker image per PHP version, containing every tool and the company config. Every project uses the same checks.

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
    uses: rockberpro/pure/.github/workflows/check.yml@main
    with:
      php_version: "7.4"
```

Optional inputs: `phpstan_level` (default 1, ignored if the project has `phpstan.neon`) and `test_version` (PHPCompatibility, e.g. `"7.4-8.5"`).

### GitLab

`.gitlab-ci.yml`:

```yaml
include:
  - remote: https://raw.githubusercontent.com/rockberpro/pure/main/gitlab/pure.yml
    inputs:
      php_version: "7.4"
```

This adds a `pure` job to merge request pipelines, in the `test` stage by default. If the project has custom stages, set the `stage` input. Findings go to GitLab Code Quality through the `codequality` artifact, and the log shows the same summary table. The other inputs match the GitHub workflow.

## Run it locally (same result as CI)

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:7.4                                 # all files
docker run --rm -v "$PWD:/app" -e PURE_BASE=origin/main ghcr.io/rockberpro/pure:7.4        # only your changes
```

## Legacy code: start with a baseline

The first full run on an old app reports thousands of issues. Record them once so that only **new** errors fail:

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:7.4 \
  phpstan analyse --level=1 -c /opt/pure/config/phpstan.neon --generate-baseline --allow-empty-baseline .
```

Then commit a `phpstan.neon`:

```neon
includes:
    - phpstan-baseline.neon
parameters:
    level: 1
```

Project config files (`phpstan.neon`, `phpcs.xml`) take priority over the company defaults in `config/`.

## Maintaining Pure

- `config/` holds the company defaults. Changes reach every project on the next image build.
- `.github/workflows/image.yml` pushes `ghcr.io/<owner>/pure:{7.4…8.5}` on changes to `main`. Make the package public, or give company repos access to it.
- `tests/run.sh` runs the images against `tests/fixtures`. It also runs on every push (`self-test.yml`).
