"""Optional passes that reduce the number of connectors in a graph.

They work on the renderer-neutral model, so the CWL semantics stay visible:
nothing is dropped silently except what ``hide_ports`` is told to drop.

* :func:`hide_ports` - remove ports (and their connectors) whose name matches
  a regular expression, e.g. ``provenance`` plumbing.
* :func:`collapse_fanout` - a workflow input feeding many steps (a
  "broadcast" parameter such as a name or config file) is written next to
  each destination row (``◂ analysis_name``) instead of being drawn as many
  long arrows.
* :func:`merge_shared_sources` - when several destinations receive the very
  same list of sources (with the same ``linkMerge``/``pickValue``), the sources
  are drawn once into a merge node, and one arrow goes from it to each
  destination.
"""

from __future__ import annotations

import re
from collections import defaultdict

from .model import Edge, Graph, Junction, Port, PortKey

__all__ = ["hide_ports", "collapse_fanout", "merge_shared_sources", "simplify"]


def _all_ports(graph: Graph):
    for g in graph.iter_graphs():
        yield from g.inputs
        yield from g.outputs
        for step in g.steps:
            yield from step.inputs
            yield from step.outputs


def hide_ports(graph: Graph, pattern: str) -> None:
    """Remove every port whose name matches ``pattern`` (``re.search``)."""
    regex = re.compile(pattern)
    hidden: set[PortKey] = {p.key for p in _all_ports(graph) if regex.search(p.name)}
    if not hidden:
        return

    def keep(ports: list[Port]) -> list[Port]:
        return [p for p in ports if p.key not in hidden]

    for g in graph.iter_graphs():
        g.inputs = keep(g.inputs)
        g.outputs = keep(g.outputs)
        for step in g.steps:
            step.inputs = keep(step.inputs)
            step.outputs = keep(step.outputs)
        g.edges = [e for e in g.edges if e.src not in hidden and e.dst not in hidden]


def _source_label(src: PortKey, graph: Graph) -> str:
    """Short text naming a source port relative to ``graph``."""
    rel = src[len(graph.path) :]
    if len(rel) == 2:  # ("in", name): workflow input
        return rel[1]
    return f"{rel[0]}/{rel[-1]}"


def collapse_fanout(graph: Graph, max_fanout: int) -> None:
    """Replace arrows from widely shared workflow inputs by text references.

    Arrows from a workflow input that feeds more than ``max_fanout``
    destinations are removed, and each destination row names the input instead.
    """
    if max_fanout <= 0:
        return
    for g in graph.iter_graphs():
        inputs = {p.key: p for p in g.inputs}
        targets: dict[PortKey, list[Edge]] = defaultdict(list)
        for e in g.edges:
            if e.src in inputs:
                targets[e.src].append(e)
        collapse = {k for k, edges in targets.items() if len(edges) > max_fanout}
        if not collapse:
            continue
        ports = {p.key: p for p in _all_ports(g)}
        for key in collapse:
            inputs[key].fanout = len(targets[key])
            for e in targets[key]:
                dst = ports.get(e.dst)
                if dst is not None:
                    dst.refs.append(_source_label(key, g))
        g.edges = [e for e in g.edges if e.src not in collapse]


def merge_shared_sources(graph: Graph) -> None:
    """Draw identical multi-source inputs through one shared merge node."""
    for g in graph.iter_graphs():
        incoming: dict[PortKey, list[Edge]] = defaultdict(list)
        for e in g.edges:
            incoming[e.dst].append(e)
        groups: dict[tuple, list[PortKey]] = defaultdict(list)
        for dst, edges in incoming.items():
            if len(edges) < 2:
                continue
            # source order matters (e.g. merge_nested), so do not sort
            groups[(tuple(e.src for e in edges), edges[0].label)].append(dst)

        replaced: set[PortKey] = set()
        new_edges: list[Edge] = []
        for (sources, label), dsts in groups.items():
            if len(dsts) < 2:
                continue
            jkey: PortKey = (*g.path, "merge", str(len(g.junctions)))
            g.junctions.append(Junction(jkey, label))
            for i, src in enumerate(sources):
                # label the merge once, on its first incoming arrow
                new_edges.append(Edge(src, jkey, label if i == 0 else ""))
            for dst in dsts:
                scatter = any(e.scatter for e in incoming[dst])
                new_edges.append(Edge(jkey, dst, "", scatter))
                replaced.add(dst)
        if replaced:
            g.edges = [e for e in g.edges if e.dst not in replaced] + new_edges


def simplify(
    graph: Graph,
    *,
    hide: str | None = None,
    max_fanout: int = 0,
    merge_nodes: bool = True,
) -> Graph:
    """Apply the passes in a sensible order (in place); returns ``graph``."""
    if hide:
        hide_ports(graph, hide)
    collapse_fanout(graph, max_fanout)
    if merge_nodes:
        merge_shared_sources(graph)
    return graph
