#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
label: Wraps fanout.cwl (merge nodes inside a sub-workflow frame)
requirements:
  SubworkflowFeatureRequirement: {}
inputs:
  name: string
  x: File
  y: File
outputs:
  result:
    type: File
    outputSource: inner/result
steps:
  inner:
    run: fanout.cwl
    in: {name: name, x: x, y: y}
    out: [result, provenance_log]
