#!/usr/bin/env python3
"""
Local, Snowflake-free validation that a domain's manifest.yml templating config renders
cleanly against dcm/_template/ — mirrors DCM's actual Jinja2 engine behavior (StrictUndefined,
macros auto-visible across all definition files) closely enough to catch the class of bug
this project already hit once (UndefinedError on an absent optional key).

This does NOT replace a real `snow dcm plan`/`deploy` against Snowflake — it only proves the
template *renders* without error for a given domain config. Use it to sanity-check a new
domain's manifest.yml before ever pointing live DCM commands at it.

Usage: python _validate_render.py <path-to-manifest.yml> <templating-config-name>
Example: python _validate_render.py ../domains/procurement/manifest.yml PROCUREMENT
"""
import sys
import pathlib
import yaml
from jinja2 import Environment, StrictUndefined, UndefinedError

TEMPLATE_DIR = pathlib.Path(__file__).parent / "sources"


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    manifest_path = pathlib.Path(sys.argv[1])
    config_name = sys.argv[2]

    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    context = manifest["templating"]["configurations"][config_name]

    macro_files = sorted((TEMPLATE_DIR / "macros").glob("*.sql"))
    definition_files = sorted((TEMPLATE_DIR / "definitions").glob("*.sql"))

    macro_source = "\n".join(f.read_text(encoding="utf-8") for f in macro_files)

    env = Environment(undefined=StrictUndefined)
    failed = False

    for def_file in definition_files:
        combined_source = macro_source + "\n" + def_file.read_text(encoding="utf-8")
        try:
            template = env.from_string(combined_source)
            rendered = template.render(**context)
        except UndefinedError as e:
            failed = True
            print(f"FAIL  {def_file.name}: UndefinedError: {e}")
            continue
        except Exception as e:
            failed = True
            print(f"FAIL  {def_file.name}: {type(e).__name__}: {e}")
            continue

        non_empty_lines = [l for l in rendered.splitlines() if l.strip()]
        print(f"OK    {def_file.name} ({len(non_empty_lines)} non-empty lines rendered)")

    if failed:
        print("\nValidation FAILED — manifest is not deploy-ready.")
        sys.exit(1)
    else:
        print(f"\nAll {len(definition_files)} definition files rendered cleanly for '{config_name}'.")
        print("(Rendering-only check — does not replace a real `snow dcm plan` against Snowflake.)")


if __name__ == "__main__":
    main()
