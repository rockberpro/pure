# Profiles

A profile is a named set of coding-standard rules. The project picks one in its CI file, and it can't pick more than one.

```yaml
profile: legacy   # or: default (the value used when you leave it out)
```

## What a profile changes, and what it doesn't

A profile **only changes the coding standard check (PHPCS)**. That check never blocks a merge. It only produces warnings.

| Check | Affected by the profile? | Blocks the merge? |
|---|---|---|
| Syntax (php-parallel-lint) | no | yes |
| Static analysis (PHPStan) | no | yes |
| Dependency security (composer audit) | no | yes |
| **Coding standard (PHPCS)** | **yes** | no, warning |
| PHP compatibility (PHPCompatibility) | no, use `test_version` | no, warning |
| Complexity (PHPMD) | no | no, warning |

So choosing `legacy` **never makes a failing pull request pass**. If the pull request fails, the cause is syntax, PHPStan or composer audit. For PHPStan on old code, the fix is a baseline, not a profile (see the README).

## Which profile do I use?

| Your code | Profile |
|---|---|
| New project, or code that uses namespaces and PSR-4 autoload | `default` |
| Old code with no namespaces: classes in the global namespace, `snake_case` methods, files that declare functions **and** run code | `legacy` |

If you're not sure, run both locally and compare the number of warnings:

```bash
docker run --rm -v "$PWD:/app" ghcr.io/rockberpro/pure:1-7.4
docker run --rm -v "$PWD:/app" -e PURE_PROFILE=legacy ghcr.io/rockberpro/pure:1-7.4
```

If `default` reports "Each class must be in a namespace of at least one level" or "Method name … is not in camel caps format" on almost every file, use `legacy`.

## The profiles

### `default`
File: [`config/phpcs.xml`](../config/phpcs.xml). The full PSR-12 standard.

### `legacy`
File: [`config/legacy/phpcs.xml`](../config/legacy/phpcs.xml). Everything in `default` except these rules, which a pre-namespace codebase can't follow without a rewrite:

| Rule turned off | What it would flag | Why legacy code can't follow it |
|---|---|---|
| `PSR1.Classes.ClassDeclaration.MissingNamespace` | `class Invoice {}` with no `namespace` | Adding namespaces changes every class reference in the app |
| `PSR1.Methods.CamelCapsMethodName` | `function get_total()` | Renaming public methods breaks every caller |
| `PSR1.Files.SideEffects` | A file that declares functions and also runs `echo`, `require`, etc. | Old apps mix both in the same file (`functions.php`, page scripts) |

Everything else still applies to legacy code: indentation, braces, spacing, line length, and so on. Most of it can be fixed automatically with `phpcbf`.

## Which config wins

Pure uses the first of these that exists:

1. **The project's own file** at the repo root: `phpcs.xml`, `phpcs.xml.dist`, `.phpcs.xml` or `.phpcs.xml.dist`. If one of these exists, **the profile is ignored**.
2. **The profile** chosen in CI (`profile: legacy`).
3. **`default`**.

An unknown profile name (`profile: legasy`) fails the job with `Pure: unknown profile`. It never silently falls back to `default`.

## Customising a profile for one project

Don't copy the profile's rules into your project. Extend the profile, so you still get later changes to Pure's rules:

```xml
<!-- phpcs.xml at the project root -->
<?xml version="1.0"?>
<ruleset name="My app">
    <rule ref="/opt/pure/config/legacy/phpcs.xml"/>
    <exclude-pattern>old_reports/*</exclude-pattern>
</ruleset>
```

`/opt/pure/config/...` is where the profiles live inside the Pure image, which is where Pure always runs.

## Moving from `legacy` to `default`

`legacy` is a starting point, and projects aren't expected to stay on it. As the code gains namespaces:

1. Switch the CI file to `profile: default` (or remove the line).
2. Run Pure locally and look at the new warnings. They're the rules `legacy` had turned off.
3. If there are too many, keep `legacy` for now and fix them file by file as you touch the code.

## Adding a profile (Pure maintainers)

1. Create `config/<name>/phpcs.xml`. Start it with `<rule ref="../phpcs.xml">` so it inherits the default standard.
2. Add `<name>` to the `options` list of the `profile` input in `gitlab/pure.yml`.
3. Add a row to the tables in this file and in the README.
4. Add a case to `tests/run.sh`.

The image copies all of `config/`, so no Dockerfile change is needed.
