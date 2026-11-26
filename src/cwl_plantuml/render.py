"""Render a :class:`~cwl_plantuml.model.Graph` as a PlantUML class-style diagram.

Why class diagrams (and not component diagrams with ports)?  PlantUML lets
links attach to individual *members* of a class (``A::member --> B::member``),
and Graphviz then draws each arrow to the exact row (record port) for that
member.  Steps therefore become boxes with one row per input and per output,
and connectors go row-to-row.  Component ``portin``/``portout`` exist too, but
Graphviz places ports on arbitrary sides of the box, which gets unreadable
quickly.

PlantUML resolves ``A::member`` by taking the *first* member whose text
contains ``member`` as a substring.  That is ambiguous for CWL (a step
can have an input and an output with the same name, and ``dl1`` matches
``dl1_filename``).  So every row gets an invisible, fixed-width, unique token
(e.g. ``Qx00042x``), and links refer to that token instead of the port name.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .model import Edge, Graph, Node, Port, PortKey

__all__ = ["RenderOptions", "render_plantuml"]

# -- CTAO brand colors ------------------------------------------------------
# main colors
CTAO_GALAXY_BLUE = "#00004A"
CTAO_CHERENKOV_BLUE = "#00E4D8"
CTAO_MOON_GRAY = "#F5F5F5"
# secondary colors
CTAO_WHITE = "#FFFFFF"
CTAO_COSMIC_AZURE = "#007AFF"
CTAO_INTERSTELLAR_INDIGO = "#00009C"

#: (background, text color) by process class
CLASS_COLORS = {
    "CommandLineTool": (CTAO_CHERENKOV_BLUE, CTAO_GALAXY_BLUE),
    "ExpressionTool": (CTAO_WHITE, CTAO_GALAXY_BLUE),
    "Workflow": (CTAO_INTERSTELLAR_INDIGO, CTAO_WHITE),
    "Operation": (CTAO_GALAXY_BLUE, CTAO_WHITE),
}
DEFAULT_COLORS = (CTAO_MOON_GRAY, CTAO_GALAXY_BLUE)
INK_COLOR = CTAO_GALAXY_BLUE  # default text, borders, arrows
IO_COLOR = CTAO_MOON_GRAY
#: expanded (sub-)workflow frames alternate between these with nesting depth
FRAME_COLORS = (CTAO_MOON_GRAY, CTAO_WHITE)
FRAME_BORDER_COLOR = CTAO_INTERSTELLAR_INDIGO
SCATTER_COLOR = CTAO_COSMIC_AZURE
CONDITIONAL_COLOR = CTAO_COSMIC_AZURE  # drawn dashed, scatter is solid
SCATTER_THICKNESS = 5

#: Connector styles, cycled per source port so that the arrows leaving
#: neighbouring outputs can be told apart: (color, line style, thickness).
#: Consecutive entries differ in both color and style.  Cosmic Azure is not
#: used here: it is reserved for scattered connectors, which keep the line
#: style of their source but are drawn azure and thick.
EDGE_STYLES = [
    (CTAO_GALAXY_BLUE, "", 1),
    (CTAO_CHERENKOV_BLUE, "dashed", 2),  # light color: drawn thicker
    (CTAO_INTERSTELLAR_INDIGO, "dotted", 1),
    (CTAO_GALAXY_BLUE, "dashed", 1),
    (CTAO_CHERENKOV_BLUE, "dotted", 2),
    (CTAO_INTERSTELLAR_INDIGO, "", 1),
    (CTAO_GALAXY_BLUE, "dotted", 1),
    (CTAO_CHERENKOV_BLUE, "", 2),
    (CTAO_INTERSTELLAR_INDIGO, "dashed", 1),
]

SCATTER_MARK = "⇶"
REF_MARK = "◂"  # value comes from the named source (no arrow drawn)
FANOUT_MARK = "▸"  # input feeds this many steps (arrows not drawn)
VALUE_FROM_MARK = "ƒ"
DEFAULT_MARK = "≔"


@dataclass
class RenderOptions:
    """Options controlling the PlantUML output."""

    show_types: bool = True
    legend: bool = True
    direction: str = "left to right"  # or "top to bottom"
    title: str | None = None
    #: cycle connector color/line style per source port (else all plain)
    edge_styles: bool = True


@dataclass
class _Ctx:
    opts: RenderOptions
    counter: int = 0
    #: port key -> (plantuml alias of owning box, unique token of the row)
    #: (a token of None means the link attaches to the whole element)
    anchors: dict[PortKey, tuple[str, str | None]] = field(default_factory=dict)
    lines: list[str] = field(default_factory=list)
    #: source port key -> index into EDGE_STYLES, in order of first use
    source_styles: dict[PortKey, int] = field(default_factory=dict)

    def alias(self, prefix: str) -> str:
        self.counter += 1
        return f"{prefix}{self.counter:05d}"

    def token(self) -> str:
        self.counter += 1
        # fixed width + delimiters: no token is a substring of another
        return f"Qx{self.counter:05d}x"

    def emit(self, indent: int, text: str) -> None:
        self.lines.append("  " * indent + text)


# --------------------------------------------------------------------------
# text helpers


def _esc(text: str) -> str:
    """Escape text used inside a quoted PlantUML display string."""
    return text.replace("\\", "\\\\").replace('"', "'").replace("\n", " ")


def _row(ctx: _Ctx, owner: str, port: Port, direction: str) -> str:
    tok = ctx.token()
    ctx.anchors[port.key] = (owner, tok)
    name = port.name
    marks = []
    if port.scattered:
        name = f"<b>{SCATTER_MARK} {name}</b>"
    if port.value_from:
        marks.append(VALUE_FROM_MARK)
    elif port.defaulted:
        marks.append(DEFAULT_MARK)
    text = name
    if ctx.opts.show_types and port.type:
        text += f" : {port.type}"
    if marks:
        text += " " + " ".join(marks)
    if port.refs:
        text += f" <i>{REF_MARK} {_esc(', '.join(port.refs))}</i>"
    if port.fanout:
        text += f" <i>{FANOUT_MARK} {port.fanout} steps</i>"
    if port.unbound:
        text = f"<i>{text} (unbound)</i>"
    # A leading "{field}" stops PlantUML from parsing "name()" as a method or
    # "-name"/"+name" as visibility.  The token is invisible.
    return f"{{field}} {text}<size:1><color:transparent>{tok}</color></size>"


def _title(
    name: str, run_label: str, label: str, step_label: str, extra: list[str]
) -> str:
    """Box/frame title.

    The headline is the friendliest name available: the step's ``label``, else
    the ``label`` of the process it runs, else the step id.  The step id (which
    is what the CWL file refers to) and the run file follow in small print.
    """
    headline = step_label or label or name
    parts = [f"<b>{_esc(headline)}</b>"]
    sub = []
    if headline != name:
        sub.append(f"<font:monospaced>{_esc(name)}</font>")
    if run_label:
        sub.append(f"<i>{_esc(run_label)}</i>")
    if sub:
        parts.append(f"<size:10>{' · '.join(sub)}</size>")
    # both labels given: the step label is the headline, keep the tool's too
    if step_label and label and label != step_label:
        parts.append(f"<size:10>{_esc(label)}</size>")
    parts.extend(extra)
    return "\\n".join(parts)


def _scatter_badge(node: Node) -> str:
    method = node.scatter_method or ("" if len(node.scatter) <= 1 else "dotproduct")
    text = f"{SCATTER_MARK} scatter" + (f" ({method})" if method else "")
    return f"<b>{text}</b>"


def _conditional_badge() -> str:
    return "<b>◇ conditional (when)</b>"


def _badges(node: Node) -> list[str]:
    out = []
    if node.scatter:
        out.append(_scatter_badge(node))
    if node.conditional:
        out.append(_conditional_badge())
    return out


def _stereotypes(node: Node) -> str:
    return f"<<{node.process_class}>>"


def _box_style(
    background: str,
    node: Node | None = None,
    text: str | None = None,
    line: str | None = None,
) -> str:
    """Return an inline PlantUML style (``line:``/``text:`` colors take no '#')."""
    style = background
    if text and text != INK_COLOR:
        style += f";text:{text.lstrip('#')}"
    if node is not None and node.scatter:
        style += f";line:{SCATTER_COLOR.lstrip('#')};line.bold"
    elif node is not None and node.conditional:
        style += f";line:{CONDITIONAL_COLOR.lstrip('#')};line.dashed;line.bold"
    elif line:
        style += f";line:{line.lstrip('#')}"
    return style


# --------------------------------------------------------------------------
# emitters


def _emit_io_box(
    ctx: _Ctx, indent: int, title: str, ports: list[Port], direction: str
) -> None:
    if not ports:
        return
    alias = ctx.alias("IO")
    ctx.emit(indent, f'class "<i>{title}</i>" as {alias} {IO_COLOR} {{')
    for p in ports:
        ctx.emit(indent + 1, _row(ctx, alias, p, direction))
    ctx.emit(indent, "}")


def _emit_leaf(ctx: _Ctx, indent: int, node: Node) -> None:
    alias = ctx.alias("S")
    fill, text = CLASS_COLORS.get(node.process_class, DEFAULT_COLORS)
    extra = _badges(node)
    if node.is_workflow:
        extra.insert(0, "<size:10>▣ collapsed sub-workflow</size>")
    title = _title(node.name, node.run_label, node.label, node.step_label, extra)
    ctx.emit(
        indent,
        f'class "{title}" as {alias} {_stereotypes(node)} {_box_style(fill, node, text)} {{',
    )
    for p in node.inputs:
        ctx.emit(indent + 1, _row(ctx, alias, p, "in"))
    ctx.emit(indent + 1, "--")
    for p in node.outputs:
        ctx.emit(indent + 1, _row(ctx, alias, p, "out"))
    ctx.emit(indent, "}")


def _emit_graph(
    ctx: _Ctx, indent: int, graph: Graph, node: Node | None, level: int = 0
) -> None:
    """Emit a frame containing the workflow's inputs, steps and outputs."""
    alias = ctx.alias("F")
    extra = _badges(node) if node is not None else []
    title = _title(graph.name, graph.run_label, graph.label, graph.step_label, extra)
    title = "<size:10>«Workflow»</size>\\n" + title
    ctx.emit(
        indent,
        f'frame "{title}" as {alias} {_box_style(FRAME_COLORS[level % 2], node, line=FRAME_BORDER_COLOR)} {{',
    )
    _emit_io_box(ctx, indent + 1, "inputs", graph.inputs, "out")
    for step in graph.steps:
        if step.subgraph is not None:
            _emit_graph(ctx, indent + 1, step.subgraph, step, level + 1)
        else:
            _emit_leaf(ctx, indent + 1, step)
    for junction in graph.junctions:
        jalias = ctx.alias("J")
        ctx.anchors[junction.key] = (jalias, None)
        ctx.emit(indent + 1, f"<> {jalias}")
    _emit_io_box(ctx, indent + 1, "outputs", graph.outputs, "in")
    ctx.emit(indent, "}")


def _arrow(ctx: _Ctx, edge: Edge) -> str:
    """PlantUML arrow with the style of the edge's source port."""
    color, style, thickness = INK_COLOR, "", 1
    if ctx.opts.edge_styles:
        idx = ctx.source_styles.setdefault(edge.src, len(ctx.source_styles))
        color, style, thickness = EDGE_STYLES[idx % len(EDGE_STYLES)]
    if edge.scatter:
        color, thickness = SCATTER_COLOR, SCATTER_THICKNESS
    attrs = [color]
    if style:
        attrs.append(style)
    if thickness != 1:
        attrs.append(f"thickness={thickness}")
    if attrs == [INK_COLOR]:
        return "-->"
    return f"-[{','.join(attrs)}]->"


def _emit_edge(ctx: _Ctx, edge: Edge) -> None:
    try:
        src_alias, src_tok = ctx.anchors[edge.src]
        dst_alias, dst_tok = ctx.anchors[edge.dst]
    except KeyError as err:  # pragma: no cover - indicates a model bug
        ctx.emit(0, f"' unresolved edge {edge.src} -> {edge.dst} ({err})")
        return
    arrow = _arrow(ctx, edge)
    label = f' : "{_esc(edge.label)}"' if edge.label else ""
    src = f"{src_alias}::{src_tok}" if src_tok else src_alias
    dst = f"{dst_alias}::{dst_tok}" if dst_tok else dst_alias
    ctx.emit(0, f"{src} {arrow} {dst}{label}")


_HEADER = """\
set separator none
{direction} direction
hide circle
hide empty methods
hide empty fields
skinparam shadowing false
skinparam nodesep 30
skinparam ranksep 120
skinparam defaultFontName Helvetica
skinparam defaultFontColor {ink}
skinparam ArrowColor {ink}
skinparam ArrowFontColor {ink}
skinparam class {{
  BorderColor {ink}
  FontColor {ink}
  AttributeFontColor {ink}
  AttributeFontSize 12
  StereotypeFontColor {ink}
  StereotypeFontColor<<Workflow>> {white}
  StereotypeFontColor<<Operation>> {white}
}}
<style>
diamond {{
  BackgroundColor {ink}
  LineColor {ink}
}}
</style>
skinparam legend {{
  BackgroundColor {legend_bg}
  BorderColor {ink}
  FontColor {ink}
}}
skinparam frame {{
  BorderColor {frame_border}
  FontColor {ink}
  FontStyle normal
}}"""


def _header(direction: str) -> list[str]:
    return _HEADER.format(
        direction=direction,
        ink=INK_COLOR,
        white=CTAO_WHITE,
        legend_bg=CTAO_MOON_GRAY,
        frame_border=FRAME_BORDER_COLOR,
    ).splitlines()


def _legend(opts: RenderOptions) -> list[str]:
    def swatch(process_class: str) -> str:
        fill, _ = CLASS_COLORS[process_class]
        return f"<back:{fill}>{chr(0xA0) * 8}</back>"

    return [
        "legend right",
        f"  | {swatch('CommandLineTool')} | CommandLineTool |",
        f"  | {swatch('ExpressionTool')} | ExpressionTool |",
        f"  | {swatch('Workflow')} | Workflow (▣ collapsed; a frame when expanded) |",
        f"  | <color:{SCATTER_COLOR}><b>━━</b></color> | scattered step (border) / scattered input (thick arrow) |",
        f"  | <b>{SCATTER_MARK}</b> | scattered input |",
        f"  | <color:{CONDITIONAL_COLOR}><b>╍╍</b></color> | conditional step (when), also marked ◇ |",
        f"  | {VALUE_FROM_MARK} | value computed by valueFrom |",
        f"  | {DEFAULT_MARK} | default value, no incoming link |",
        f"  | <i>{REF_MARK} x</i> | value comes from x (widely shared input, arrows omitted) |",
        f"  | <i>{FANOUT_MARK} n steps</i> | input used by n steps (arrows omitted) |",
        "  | ◆ | merge node: the same list of sources fed to several inputs |",
        "  | ── | upper section: inputs; lower section: outputs |",
        *(
            [
                f"  | <color:{CTAO_GALAXY_BLUE}>──</color><color:{CTAO_CHERENKOV_BLUE}><b>╌╌</b></color>"
                f"<color:{CTAO_INTERSTELLAR_INDIGO}>┈┈</color> "
                "| connector color / line style changes from one output to the next |"
            ]
            if opts.edge_styles
            else []
        ),
        "endlegend",
    ]


def render_plantuml(graph: Graph, opts: RenderOptions | None = None) -> str:
    """Render a graph as PlantUML text.

    Parameters
    ----------
    graph : Graph
        The workflow graph, e.g. from `~cwl_plantuml.load_graph`.
    opts : RenderOptions, optional
        Rendering options.

    Returns
    -------
    str
        The PlantUML document, from ``@startuml`` to ``@enduml``.
    """
    opts = opts or RenderOptions()
    ctx = _Ctx(opts)
    ctx.emit(0, "@startuml")
    ctx.lines.extend(_header(opts.direction))
    if opts.title:
        ctx.emit(0, f"title {_esc(opts.title)}")
    ctx.emit(0, "")
    _emit_graph(ctx, 0, graph, None)
    ctx.emit(0, "")
    for edge in graph.iter_edges():
        _emit_edge(ctx, edge)
    if opts.legend:
        ctx.emit(0, "")
        ctx.lines.extend(_legend(opts))
    ctx.emit(0, "@enduml")
    return "\n".join(ctx.lines) + "\n"


TOKEN_RE = re.compile(r"Qx\d{5}x")
