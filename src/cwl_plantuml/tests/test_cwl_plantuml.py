import re
import shutil
import subprocess
from collections import Counter
from pathlib import Path

import pytest
from schema_salad.exceptions import ValidationException

from cwl_plantuml import RenderOptions, load_graph, render_plantuml
from cwl_plantuml.cli.main import main
from cwl_plantuml.render import SCATTER_THICKNESS, TOKEN_RE
from cwl_plantuml.simplification import simplify

DATA = Path(__file__).parent / "data"
#: real-world workflows (CTAO DataPipe); may be skipped if they cannot be loaded
WORKFLOWS = DATA / "workflows"
EXAMPLES = sorted(WORKFLOWS.rglob("*.cwl"))
NESTED = DATA / "nested.cwl"
FANOUT = NESTED.with_name("fanout.cwl")
FANOUT_NESTED = NESTED.with_name("fanout_nested.cwl")
ALL = EXAMPLES + [NESTED, NESTED.with_name("nested_packed.cwl"), FANOUT, FANOUT_NESTED]

# endpoints are either ALIAS::TOKEN (a member row) or a bare ALIAS (merge node)
LINK_RE = re.compile(r"^(\w+)(?:::(Qx\d{5}x))? -\S*-> (\w+)(?:::(Qx\d{5}x))?", re.M)
ROW_RE = re.compile(r"^\s*\{field\}.*?(Qx\d{5}x)</color></size>$", re.M)


def _ids(path):
    return path.relative_to(DATA).as_posix()


def _load(path, **kwargs):
    """Load a workflow; example files that cannot be loaded (e.g. a missing
    dependency) are skipped with the reason, test fixtures must load."""
    try:
        return load_graph(str(path), **kwargs)
    except ValidationException as err:
        if WORKFLOWS not in path.parents:
            raise
        first = str(err).strip().splitlines()[-1].strip()
        pytest.skip(f"cannot load {path.name}: {first}")


@pytest.fixture(scope="module", params=ALL, ids=_ids)
def puml(request):
    graph = _load(request.param, all_inputs=True)
    return render_plantuml(simplify(graph, max_fanout=4))


def test_tokens_unique_and_links_resolve(puml):
    """Every link must hit exactly one member row (guards PlantUML's
    first-substring member matching)."""
    rows = ROW_RE.findall(puml)
    assert rows, "no member rows generated"
    counts = Counter(TOKEN_RE.findall(puml))
    links = LINK_RE.findall(puml)
    row_set = set(rows)
    assert len(rows) == len(row_set)
    merge_nodes = set(re.findall(r"^\s*<> (\w+)$", puml, re.M))
    for src_alias, src, dst_alias, dst in links:
        assert (src in row_set) if src else (src_alias in merge_nodes)
        assert (dst in row_set) if dst else (dst_alias in merge_nodes)
    # each token occurs once in its row, plus once per link using it
    used = Counter(t for _, s, _, d in links for t in (s, d) if t)
    for tok in row_set:
        assert counts[tok] == 1 + used[tok]
    assert "unresolved edge" not in puml


def _frames(puml):
    return len(re.findall(r"^\s*frame ", puml, re.M))


@pytest.mark.parametrize(("depth", "frames"), [(0, 1), (1, 4), (2, 5), (None, 5)])
def test_depth(depth, frames):
    puml = render_plantuml(load_graph(str(NESTED), depth=depth))
    assert _frames(puml) == frames
    collapsed = puml.count("collapsed sub-workflow</size>")
    # nested.cwl: 3 sub-workflow steps at level 1, 1 at level 2
    assert collapsed == {0: 3, 1: 1}.get(depth, 0)


def test_reused_subworkflow_is_drawn_twice():
    graph = load_graph(str(NESTED))
    names = {s.name: s for s in graph.steps}
    a, b = names["single"].subgraph, names["single_again"].subgraph
    assert a is not None
    assert b is not None
    assert {s.name for s in a.steps} == {s.name for s in b.steps}
    assert {p.key for p in a.inputs}.isdisjoint({p.key for p in b.inputs})


def test_scatter_and_conditional_model():
    graph = load_graph(str(NESTED), depth=0)
    steps = {s.name: s for s in graph.steps}
    batched = steps["batched"]
    assert batched.scatter == ["input_files", "output_filename"]
    assert batched.scatter_method == "dotproduct"
    assert all(p.scattered for p in batched.inputs)
    assert steps["single_again"].conditional
    assert steps["pick_first"].process_class == "ExpressionTool"
    assert steps["pick_first"].run_label == ""  # inline
    merged = [e for e in graph.edges if e.dst[-1] == "files"]
    assert len(merged) == 2
    assert all(e.label == "merge_flattened" for e in merged)
    assert [e.scatter for e in graph.edges if e.dst[0] == "batched"] == [True, True]


def test_document_order():
    graph = load_graph(str(WORKFLOWS / "process_dl0_dl1_multiple.cwl"))
    assert [s.name for s in graph.steps] == ["filenames", "process_dl0_to_dl1", "merge"]


def test_no_types_option():
    puml = render_plantuml(
        load_graph(str(NESTED)), RenderOptions(show_types=False, legend=False)
    )
    assert " : File" not in puml
    assert "endlegend" not in puml


@pytest.mark.skipif(shutil.which("plantuml") is None, reason="plantuml not installed")
@pytest.mark.parametrize("path", ALL, ids=_ids)
def test_plantuml_renders(path, tmp_path):
    _load(path)  # skips examples that cannot be loaded
    out = tmp_path / "diagram.puml"
    assert main([str(path), "-o", str(out), "--all-inputs"]) == 0
    result = subprocess.run(
        ["plantuml", "-headless", "-tsvg", str(out)], capture_output=True, text=True
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert (tmp_path / "diagram.svg").exists()


def test_labels_used_as_titles():
    graph = load_graph(str(NESTED), depth=0)
    steps = {s.name: s for s in graph.steps}
    assert steps["pick_first"].step_label == "Pick the first file"
    assert steps["single_again"].step_label == "Optional extra DL0 to DL2 pass"
    assert steps["single"].step_label == ""
    puml = render_plantuml(graph, RenderOptions(legend=False))
    # step label wins; step id kept in small print
    assert (
        '"<b>Pick the first file</b>\\n<size:10><font:monospaced>pick_first</font>'
        in puml
    )
    # no step label: fall back to the label of the process that is run
    assert (
        '"<b>Process DL0 to DL2</b>\\n<size:10><font:monospaced>single</font>' in puml
    )
    # both labels: the tool's label is kept as a subtitle
    assert "<b>Optional extra DL0 to DL2 pass</b>" in puml
    # an expanded sub-workflow frame uses the step label too
    expanded = render_plantuml(
        load_graph(str(NESTED), depth=1), RenderOptions(legend=False)
    )
    assert re.search(r'frame "[^"]*<b>Optional extra DL0 to DL2 pass</b>', expanded)


# --------------------------------------------------------------------------
# connector reduction (cwl_plantuml.simplification)


def _edges(graph):
    return [(e.src, e.dst) for e in graph.iter_edges()]


def test_fanout_collapsed_to_references():
    graph = simplify(load_graph(str(FANOUT)), max_fanout=4)
    name = next(p for p in graph.inputs if p.name == "name")
    assert name.fanout == 5
    assert all(src != name.key for src, _ in _edges(graph))
    refs = {s.name: p.refs for s in graph.steps for p in s.inputs if p.name == "name"}
    assert refs == {k: ["name"] for k in ("a", "b", "c1", "c2", "c3")}
    puml = render_plantuml(graph)
    assert "◂ name</i>" in puml
    assert "▸ 5 steps</i>" in puml


def test_fanout_threshold_and_disable():
    assert (
        next(
            p
            for p in simplify(load_graph(str(FANOUT)), max_fanout=5).inputs
            if p.name == "name"
        ).fanout
        == 0
    )
    graph = simplify(load_graph(str(FANOUT)), max_fanout=0, merge_nodes=False)
    assert len(_edges(graph)) == len(_edges(load_graph(str(FANOUT))))


def test_merge_node_for_identical_source_lists():
    graph = simplify(load_graph(str(FANOUT)), max_fanout=0)
    assert len(graph.junctions) == 1
    j = graph.junctions[0].key
    edges = _edges(graph)
    into = [src[-3] for src, dst in edges if dst == j]
    assert into == ["a", "b"]  # source order preserved
    assert sorted(dst[-3] for src, dst in edges if src == j) == ["c1", "c2"]
    # c3 has the same sources in another order: drawn directly
    c3_models = ("c3", "in", "models")
    assert sorted(src[-3] for src, dst in edges if dst == c3_models) == ["a", "b"]
    # the linkMerge label appears once, on the way into the merge node
    labels = [e.label for e in graph.iter_edges() if e.label]
    assert labels.count("merge_flattened") == 3  # 1 at the merge node + 2 for c3


def test_merge_node_emitted_inside_its_frame():
    graph = simplify(load_graph(str(FANOUT_NESTED)), max_fanout=0)
    puml = render_plantuml(graph, RenderOptions(legend=False))
    lines = puml.splitlines()
    frames = [i for i, line in enumerate(lines) if line.lstrip().startswith("frame ")]
    assert len(frames) == 2
    inner_start = frames[1]
    depth, inner_end = 0, None
    for i in range(inner_start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            inner_end = i
            break
    merges = [i for i, line in enumerate(lines) if line.lstrip().startswith("<> ")]
    assert merges
    assert all(inner_start < i < inner_end for i in merges)


def test_hide_ports():
    graph = simplify(load_graph(str(FANOUT)), hide="provenance")
    puml = render_plantuml(graph, RenderOptions(legend=False))
    assert "provenance" not in puml
    assert all("provenance_log" not in (src[-1], dst[-1]) for src, dst in _edges(graph))


# --------------------------------------------------------------------------
# connector styles

ARROW_RE = re.compile(r"^(\w+(?:::Qx\d{5}x)?) (-\S*->) ", re.M)


def test_scatter_connectors_are_thick():
    puml = render_plantuml(load_graph(str(WORKFLOWS / "process_dl0_dl1_multiple.cwl")))
    scatter_arrows = [a for _, a in ARROW_RE.findall(puml) if "#007AFF" in a]
    assert len(scatter_arrows) == 4
    assert all(f"thickness={SCATTER_THICKNESS}" in a for a in scatter_arrows)


def test_connector_style_per_source():
    puml = render_plantuml(
        simplify(load_graph(str(FANOUT)), max_fanout=0, merge_nodes=False)
    )
    by_source = {}
    for src, arrow in ARROW_RE.findall(puml):
        by_source.setdefault(src, set()).add(arrow)
    # every connector leaving one output looks the same ...
    assert all(len(arrows) == 1 for arrows in by_source.values())
    # ... and the first outputs (fewer than the cycle length) all differ
    styles = [next(iter(a)) for a in by_source.values()]
    assert len(set(styles[:9])) == min(9, len(styles))


def test_monochrome_connectors():
    puml = render_plantuml(load_graph(str(NESTED)), RenderOptions(edge_styles=False))
    scatter = f"-[#007AFF,thickness={SCATTER_THICKNESS}]->"
    arrows = {a for _, a in ARROW_RE.findall(puml)}
    assert arrows <= {"-->", scatter}
    assert scatter in arrows
