"""Allow running the command-line tool as ``python -m cwl_plantuml``."""

from .cli.main import main

if __name__ == "__main__":
    raise SystemExit(main())
