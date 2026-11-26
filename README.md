# cwl-plantuml

Convert CWL workflows to PlantUML with more details than you get from cwlviewer
(or `cwltool --print-dot`):

* hierarchical workflows, with sub-workflows expanded down to a chosen depth
  (and shown as black boxes below it),
* every step shows its stereotype (`«CommandLineTool»`, `«ExpressionTool»`,
  `«Workflow»`, ...), its `label`, and all its input and output ports,
* connectors go from the exact output port to the exact input port,
* scatter, conditional steps, `valueFrom`, defaults and `linkMerge` are shown,
* options to keep large workflows readable: shared merge nodes, text
  references instead of arrows for widely shared inputs, hiding ports by name,
  and a different color/line style for each output's connectors,
* CTAO brand colors.

Disclaimer: this was heavily vibe-coded and was created to help me debug some
complex CWL workflows. I'm putting it here in case it's useful to others.

## Usage

```
$ pip install cwl-plantuml
$ cwl-plantuml workflow.cwl -o workflow.puml             # write PlantUML
$ cwl-plantuml workflow.cwl -o workflow.puml --render svg # ... and run plantuml
$ cwl-plantuml workflow.cwl --depth 0 --hide-ports provenance -o workflow.puml
$ cwl-plantuml --help
```

`--render` needs the [PlantUML](https://plantuml.com) executable (and Java),
e.g. `mamba install -c conda-forge plantuml`. See the documentation
(`docs/usage.rst`) for all options, the diagram conventions and examples.

The test suite includes real workflows from the CTAO DataPipe
(`src/cwl_plantuml/tests/data/workflows`). Tests that render diagrams are
skipped if `plantuml` is not installed.

