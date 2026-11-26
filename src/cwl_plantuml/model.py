"""Load a CWL document with cwltool and turn it into a renderer-neutral graph model.

Every port in the model is identified by a *hierarchy key*: a tuple built from
the path of step names leading to the node, plus a direction and a port name::

    (*path, "in" | "out", port_name)

The same formula is used for the ports of a step and for the inputs/outputs of
the workflow that the step runs.  Hence, when a sub-workflow step is expanded,
the step's input ports *are* the inner workflow's input ports, and edges from
the parent graph connect straight into the inner graph without any extra
bookkeeping.  Keys are based on the hierarchy (not on CWL ids), so the same
sub-workflow file embedded twice yields distinct nodes.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from typing import Any
from urllib.parse import unquote, urlparse

from cwltool.context import LoadingContext
from cwltool.load_tool import load_tool
from cwltool.process import Process
from cwltool.workflow import Workflow, WorkflowStep, default_make_tool

PortKey = tuple[str, ...]

__all__ = [
    "Port",
    "Edge",
    "Junction",
    "Node",
    "Graph",
    "load_graph",
    "build_graph",
    "format_type",
]


@dataclass
class Port:
    """An input or output port of a step, or of a workflow's inputs/outputs box."""

    name: str
    key: PortKey
    type: str = ""
    scattered: bool = False
    #: True if the value is computed by ``valueFrom`` on the step input.
    value_from: bool = False
    #: True if the input has a default (step-level or tool-level) and no source.
    defaulted: bool = False
    #: True if the input is not bound by the step at all (only with all_inputs).
    unbound: bool = False
    #: Sources written next to the row instead of drawn as arrows (see
    #: :func:`cwl_plantuml.simplification.collapse_fanout`).
    refs: list[str] = field(default_factory=list)
    #: Number of destinations whose arrows were replaced by ``refs``.
    fanout: int = 0


@dataclass
class Edge:
    """A connection from a source port to a destination port."""

    src: PortKey
    dst: PortKey
    label: str = ""
    #: True if the destination input is scattered over.
    scatter: bool = False


@dataclass
class Junction:
    """A merge point that combines several sources into one value.

    The merged value (see ``linkMerge``) is fed to every destination that
    shares exactly the same list of sources.
    """

    key: PortKey
    label: str = ""


@dataclass
class Node:
    """A workflow step (or the root process when the root is not a Workflow)."""

    name: str
    path: tuple[str, ...]
    process_class: str
    run_label: str  # file name of the run target, or "" when inline
    #: ``label`` of the process that the step runs
    label: str = ""
    #: ``label`` of the workflow step itself (takes precedence over ``label``)
    step_label: str = ""
    inputs: list[Port] = field(default_factory=list)
    outputs: list[Port] = field(default_factory=list)
    scatter: list[str] = field(default_factory=list)
    scatter_method: str = ""
    conditional: bool = False
    #: Populated when this step runs a sub-workflow that is shown expanded.
    subgraph: Graph | None = None

    @property
    def is_workflow(self) -> bool:
        """Whether the step runs a sub-workflow."""
        return self.process_class == "Workflow"


@dataclass
class Graph:
    """The contents of one (expanded) workflow."""

    name: str
    path: tuple[str, ...]
    label: str
    run_label: str
    #: ``label`` of the step that runs this (sub-)workflow, if any
    step_label: str = ""
    inputs: list[Port] = field(default_factory=list)
    outputs: list[Port] = field(default_factory=list)
    steps: list[Node] = field(default_factory=list)
    edges: list[Edge] = field(default_factory=list)
    junctions: list[Junction] = field(default_factory=list)

    def iter_graphs(self):
        """Iterate over this graph and all expanded sub-graphs, depth first."""
        yield self
        for step in self.steps:
            if step.subgraph is not None:
                yield from step.subgraph.iter_graphs()

    def iter_edges(self):
        """All edges in this graph and in expanded sub-graphs."""
        yield from self.edges
        for step in self.steps:
            if step.subgraph is not None:
                yield from step.subgraph.iter_edges()


# --------------------------------------------------------------------------
# helpers


def format_type(t: Any) -> str:
    """Compact human-readable rendering of a CWL type."""
    if t is None:
        return ""
    if isinstance(t, str):
        # strip URIs (e.g. schema-salad expanded names)
        return t.rsplit("#", 1)[-1].rsplit("/", 1)[-1]
    if isinstance(t, list):
        non_null = [x for x in t if x != "null"]
        optional = len(non_null) != len(t)
        if len(non_null) == 1:
            s = format_type(non_null[0])
        else:
            s = "|".join(format_type(x) for x in non_null)
            if optional:
                s = f"({s})"
        return s + ("?" if optional else "")
    if isinstance(t, dict):
        kind = t.get("type")
        if kind == "array":
            inner = format_type(t.get("items"))
            if "|" in inner and not inner.startswith("("):
                inner = f"({inner})"
            return inner + "[]"
        if kind == "enum":
            return "enum"
        if kind == "record":
            return "record"
        return format_type(kind)
    return str(t)


def _fragment(uri: str) -> str:
    """Part of an id after '#', or the whole thing if there is none."""
    return uri.split("#", 1)[1] if "#" in uri else uri


def _relative(uri: str, base: str) -> str:
    """Express ``uri`` relative to ``base`` (an id of a workflow or step)."""
    if uri.startswith(base):
        rest = uri[len(base) :]
        return rest.lstrip("#/")
    return _fragment(uri)


def _run_label(step: WorkflowStep) -> str:
    run = step.tool.get("run")
    if isinstance(run, str) and not run.startswith("_:"):
        path = urlparse(run).path or run
        name = os.path.basename(unquote(path))
        frag = run.split("#", 1)[1] if "#" in run else ""
        # in packed ($graph) documents, the fragment names the process
        return frag if frag and frag != "main" else name
    return ""


def _doc_label(process: Process) -> str:
    return str(process.tool.get("label") or "")


def _as_list(x: Any) -> list:
    if x is None:
        return []
    return list(x) if isinstance(x, list) else [x]


def _line(obj: Any) -> int:
    """Source line of a ruamel-loaded mapping (or a large number if unknown)."""
    lc = getattr(obj, "lc", None)
    line = getattr(lc, "line", None)
    return line if isinstance(line, int) else 1 << 30


def _doc_order(items: list) -> list:
    """Sort mappings into document order.

    schema-salad turns ``id``-keyed maps into lists sorted by id; the ruamel
    line information survives, so use it to restore the order of the file.
    """
    return sorted(items, key=_line)


def _ordered_steps(wf: Workflow) -> list[WorkflowStep]:
    """Return steps in document order (``wf.steps`` does not preserve it)."""
    return sorted(wf.steps, key=lambda s: (_line(s.tool), s.id))


# --------------------------------------------------------------------------
# model construction


def _source_key(src: str, wf_id: str, path: tuple[str, ...]) -> PortKey:
    rel = _relative(src, wf_id)
    parts = rel.split("/")
    if len(parts) == 1:
        return (*path, "in", parts[0])
    # step/port (step names cannot contain '/')
    return (*path, parts[-2], "out", parts[-1])


def _link_label(entry: dict) -> str:
    bits = []
    if entry.get("linkMerge") and len(_as_list(entry.get("source"))) > 1:
        bits.append(str(entry["linkMerge"]))
    if entry.get("pickValue"):
        bits.append(str(entry["pickValue"]))
    return ", ".join(bits)


def _build_step(
    step: WorkflowStep,
    wf_id: str,
    path: tuple[str, ...],
    depth: int | None,
    all_inputs: bool,
) -> tuple[Node, list[Edge]]:
    name = _relative(step.id, wf_id)
    spath = (*path, name)
    embedded = step.embedded_tool
    pclass = str(embedded.tool.get("class", "Process"))

    scatter_names = [_relative(s, step.id) for s in _as_list(step.tool.get("scatter"))]
    scatter_method = str(step.tool.get("scatterMethod") or "")
    if len(scatter_names) > 1 and not scatter_method:
        scatter_method = "dotproduct"

    node = Node(
        name=name,
        path=spath,
        process_class=pclass,
        run_label=_run_label(step),
        label=_doc_label(embedded),
        step_label=str(step.tool.get("label") or ""),
        scatter=scatter_names,
        scatter_method=scatter_method,
        conditional=bool(step.tool.get("when")),
    )

    edges: list[Edge] = []
    bound = set()
    for entry in _doc_order(step.tool["inputs"]):
        pname = _relative(entry["id"], step.id)
        bound.add(pname)
        sources = _as_list(entry.get("source"))
        port = Port(
            name=pname,
            key=(*spath, "in", pname),
            type=format_type(entry.get("type")),
            scattered=pname in scatter_names,
            value_from="valueFrom" in entry,
            defaulted=not sources
            and "valueFrom" not in entry
            and ("default" in entry or "default" in entry.get("_tool_entry", {})),
        )
        node.inputs.append(port)
        label = _link_label(entry)
        for src in sources:
            edges.append(
                Edge(_source_key(src, wf_id, path), port.key, label, port.scattered)
            )

    if all_inputs:
        for inp in _doc_order(embedded.tool.get("inputs", [])):
            pname = _relative(inp["id"], embedded.tool["id"])
            if pname in bound:
                continue
            node.inputs.append(
                Port(
                    name=pname,
                    key=(*spath, "in", pname),
                    type=format_type(inp.get("type")),
                    defaulted="default" in inp,
                    unbound=True,
                )
            )

    for entry in _doc_order(step.tool["outputs"]):
        pname = _relative(entry["id"], step.id)
        node.outputs.append(
            Port(
                name=pname,
                key=(*spath, "out", pname),
                type=format_type(entry.get("type")),
            )
        )

    if isinstance(embedded, Workflow) and (depth is None or depth > 0):
        node.subgraph = build_graph(
            embedded,
            path=spath,
            name=name,
            run_label=node.run_label,
            depth=None if depth is None else depth - 1,
            all_inputs=all_inputs,
        )
        node.subgraph.step_label = node.step_label
        # The expanded frame's "inputs"/"outputs" boxes share keys with the
        # step's ports; mirror scatter/valueFrom flags so they show there too.
        flags = {p.name: p for p in node.inputs}
        for p in node.subgraph.inputs:
            if p.name in flags:
                p.scattered = flags[p.name].scattered
                p.value_from = flags[p.name].value_from
        # step-level output types reflect scatter (arrays); prefer those
        out_types = {p.name: p.type for p in node.outputs}
        for p in node.subgraph.outputs:
            p.type = out_types.get(p.name, p.type)
        known = {p.name for p in node.subgraph.inputs}
        # step inputs that the sub-workflow does not declare (e.g. used only
        # by `when`) still need a row to connect to
        for p in node.inputs:
            if p.name not in known:
                node.subgraph.inputs.append(p)

    return node, edges


def build_graph(
    wf: Workflow,
    path: tuple[str, ...] = (),
    name: str | None = None,
    run_label: str = "",
    depth: int | None = None,
    all_inputs: bool = False,
) -> Graph:
    """Build a :class:`Graph` from a loaded cwltool ``Workflow``.

    ``depth`` is the number of sub-workflow levels to expand below ``wf``
    (``None`` = unlimited, ``0`` = show sub-workflows as black boxes).
    """
    wf_id = wf.tool["id"]
    graph = Graph(
        name=name
        if name is not None
        else _relative(wf_id, wf_id.split("#")[0]) or run_label,
        path=path,
        label=_doc_label(wf),
        run_label=run_label,
    )
    for inp in _doc_order(wf.tool.get("inputs", [])):
        pname = _relative(inp["id"], wf_id)
        graph.inputs.append(
            Port(
                pname,
                (*path, "in", pname),
                format_type(inp.get("type")),
                defaulted="default" in inp,
            )
        )
    for out in _doc_order(wf.tool.get("outputs", [])):
        pname = _relative(out["id"], wf_id)
        port = Port(pname, (*path, "out", pname), format_type(out.get("type")))
        graph.outputs.append(port)
        label = ""
        sources = _as_list(out.get("outputSource"))
        if len(sources) > 1 and out.get("linkMerge"):
            label = str(out["linkMerge"])
        if out.get("pickValue"):
            label = ", ".join(x for x in (label, str(out["pickValue"])) if x)
        for src in sources:
            graph.edges.append(Edge(_source_key(src, wf_id, path), port.key, label))

    for step in _ordered_steps(wf):
        node, edges = _build_step(step, wf_id, path, depth, all_inputs)
        graph.steps.append(node)
        graph.edges.extend(edges)
    return graph


def _root_as_graph(tool: Process, run_label: str, all_inputs: bool) -> Graph:
    """Wrap a non-workflow root (e.g. a single CommandLineTool) in a Graph."""
    tid = tool.tool["id"]
    node = Node(
        name=run_label or "tool",
        path=("tool",),
        process_class=str(tool.tool.get("class", "Process")),
        run_label=run_label,
        label=_doc_label(tool),
    )
    graph = Graph(name=node.name, path=(), label=node.label, run_label=run_label)
    for inp in tool.tool.get("inputs", []):
        pname = _relative(inp["id"], tid)
        t = format_type(inp.get("type"))
        graph.inputs.append(Port(pname, ("in", pname), t, defaulted="default" in inp))
        node.inputs.append(
            Port(pname, ("tool", "in", pname), t, defaulted="default" in inp)
        )
        graph.edges.append(Edge(("in", pname), ("tool", "in", pname)))
    for out in tool.tool.get("outputs", []):
        pname = _relative(out["id"], tid)
        t = format_type(out.get("type"))
        graph.outputs.append(Port(pname, ("out", pname), t))
        node.outputs.append(Port(pname, ("tool", "out", pname), t))
        graph.edges.append(Edge(("tool", "out", pname), ("out", pname)))
    graph.steps.append(node)
    return graph


def load_process(path_or_uri: str) -> Process:
    """Load (and validate) a CWL document using cwltool."""
    for logger_name in ("cwltool", "salad"):
        logging.getLogger(logger_name).setLevel(logging.WARNING)
    ctx = LoadingContext({"construct_tool_object": default_make_tool})
    return load_tool(path_or_uri, ctx)


def load_graph(
    path_or_uri: str, depth: int | None = None, all_inputs: bool = False
) -> Graph:
    """Load a CWL file and build the graph model, expanding ``depth`` levels."""
    process = load_process(path_or_uri)
    tid = process.tool["id"]
    base = os.path.basename(unquote(urlparse(tid).path)) or os.path.basename(
        path_or_uri
    )
    if isinstance(process, Workflow):
        frag = tid.split("#", 1)[1] if "#" in tid else ""
        return build_graph(
            process,
            name=os.path.splitext(base)[0],
            run_label=f"{base}#{frag}" if frag and frag != "main" else base,
            depth=depth,
            all_inputs=all_inputs,
        )
    return _root_as_graph(process, base, all_inputs)
