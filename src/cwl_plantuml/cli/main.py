"""Command-line interface: ``cwl-plantuml workflow.cwl``."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from ..model import load_graph
from ..render import RenderOptions, render_plantuml
from ..simplification import simplify
from ..version import __version__


def _depth(value: str) -> int | None:
    if value.lower() in ("all", "-1", "inf"):
        return None
    d = int(value)
    if d < 0:
        raise argparse.ArgumentTypeError("depth must be >= 0, or 'all'")
    return d


def build_parser() -> argparse.ArgumentParser:
    """Build the argument parser of the ``cwl-plantuml`` command."""
    p = argparse.ArgumentParser(
        prog="cwl-plantuml",
        description="Generate a PlantUML diagram of a (hierarchical) CWL workflow.",
    )
    p.add_argument("workflow", help="CWL file (path or URI)")
    p.add_argument("--version", action="version", version=__version__)
    p.add_argument(
        "-o",
        "--output",
        help="output .puml file (default: stdout). With --render, the image is "
        "written next to it.",
    )
    p.add_argument(
        "-d",
        "--depth",
        type=_depth,
        default=None,
        metavar="N",
        help="number of sub-workflow levels to expand below the top-level "
        "workflow. 0 = show only the top-level steps, with every sub-workflow "
        "drawn as a collapsed black box; 1 = also expand the sub-workflows "
        "called directly by the top level; etc. Default: 'all'.",
    )
    p.add_argument(
        "--all-inputs",
        action="store_true",
        help="also list tool inputs that the step does not bind (shown in italics, marked '(unbound)')",
    )
    p.add_argument(
        "--max-fanout",
        type=int,
        default=4,
        metavar="N",
        help="a workflow input feeding more than N steps is not drawn with "
        "arrows; each destination row shows '◂ input_name' instead, and the "
        "input row shows '▸ n steps'. 0 = always draw arrows. Default: 4.",
    )
    p.add_argument(
        "--hide-ports",
        metavar="REGEX",
        help="hide every port (and its arrows) whose name matches REGEX, "
        "e.g. --hide-ports provenance",
    )
    p.add_argument(
        "--no-merge-nodes",
        action="store_true",
        help="do not route identical multi-source inputs through a shared "
        "merge node; draw every source arrow separately",
    )
    p.add_argument(
        "--monochrome-connectors",
        action="store_true",
        help="draw all connectors plain, instead of cycling color/line style "
        "per output (scattered connectors are still thick and azure)",
    )
    p.add_argument("--no-types", action="store_true", help="do not show port types")
    p.add_argument("--no-legend", action="store_true", help="do not draw the legend")
    p.add_argument(
        "--top-to-bottom",
        action="store_true",
        help="lay out the graph top-to-bottom instead of left-to-right",
    )
    p.add_argument("--title", help="diagram title")
    p.add_argument(
        "--render",
        choices=["png", "svg", "pdf"],
        help="also run 'plantuml' to render the diagram (requires --output)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    """Run the ``cwl-plantuml`` command.

    Parameters
    ----------
    argv : list of str, optional
        Command-line arguments (default: ``sys.argv[1:]``).

    Returns
    -------
    int
        Exit status.
    """
    args = build_parser().parse_args(argv)
    if args.render and not args.output:
        print("error: --render requires --output", file=sys.stderr)
        return 2

    graph = load_graph(args.workflow, depth=args.depth, all_inputs=args.all_inputs)
    simplify(
        graph,
        hide=args.hide_ports,
        max_fanout=args.max_fanout,
        merge_nodes=not args.no_merge_nodes,
    )
    text = render_plantuml(
        graph,
        RenderOptions(
            show_types=not args.no_types,
            legend=not args.no_legend,
            direction="top to bottom" if args.top_to_bottom else "left to right",
            title=args.title,
            edge_styles=not args.monochrome_connectors,
        ),
    )

    if not args.output:
        sys.stdout.write(text)
        return 0

    out = Path(args.output)
    out.write_text(text, encoding="utf-8")
    if args.render:
        exe = shutil.which("plantuml")
        if exe is None:
            print("error: 'plantuml' executable not found", file=sys.stderr)
            return 1
        return subprocess.call([exe, "-headless", f"-t{args.render}", str(out)])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
