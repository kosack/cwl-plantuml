#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
label: Fan-out test workflow
doc: |
  Test fixture for the connector-reduction passes: a broadcast input used by
  five steps, two steps sharing the same multi-source list (merge node), one
  step with the same sources in a different order (no merge node), and
  provenance-style ports.
requirements:
  MultipleInputFeatureRequirement: {}
inputs:
  name: string
  x: File
  y: File
outputs:
  result:
    type: File
    outputSource: c1/out
  provenance_log:
    type: File
    outputSource: c3/provenance_log
steps:
  a:
    run: &producer
      class: CommandLineTool
      baseCommand: "true"
      inputs:
        name: string
        data: File
      outputs:
        out: {type: File, outputBinding: {glob: out}}
        provenance_log: {type: File, outputBinding: {glob: prov}}
    in: {name: name, data: x}
    out: [out, provenance_log]
  b:
    run: *producer
    in: {name: name, data: y}
    out: [out, provenance_log]
  c1:
    run: &consumer
      class: CommandLineTool
      baseCommand: "true"
      inputs:
        name: string
        models: File[]
      outputs:
        out: {type: File, outputBinding: {glob: out}}
        provenance_log: {type: File, outputBinding: {glob: prov}}
    in:
      name: name
      models:
        source: [a/out, b/out]
        linkMerge: merge_flattened
    out: [out, provenance_log]
  c2:
    run: *consumer
    in:
      name: name
      models:
        source: [a/out, b/out]
        linkMerge: merge_flattened
    out: [out]
  c3:
    run: *consumer
    in:
      name: name
      models:
        source: [b/out, a/out]
        linkMerge: merge_flattened
    out: [out, provenance_log]
