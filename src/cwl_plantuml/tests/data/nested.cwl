#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
label: Nested test workflow
doc: |
  Test fixture exercising: subworkflows used twice, three nesting levels,
  scatter over a subworkflow, multiple sources with linkMerge, a conditional
  step, and an inline (non-file) ExpressionTool.
requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
inputs:
  dl0: File
  batches:
    type: {type: array, items: {type: array, items: File}}
  batch_names: string[]
  do_extra: boolean
outputs:
  dl2:
    type: File
    outputSource: single/dl2
  merged:
    type: File[]
    outputSource: batched/merged
  extra_dl2:
    type: File?
    outputSource: single_again/dl2
steps:
  single:
    run: workflows/workflow_dl0_to_dl2.cwl
    in:
      dl0: dl0
    out: [dl1, dl2]

  batched:
    run: inner_wrapper.cwl
    scatter: [input_files, output_filename]
    scatterMethod: dotproduct
    in:
      input_files: batches
      output_filename: batch_names
    out: [merged, provenance]

  pick_first:
    label: Pick the first file
    run:
      class: ExpressionTool
      inputs:
        files: File[]
      outputs:
        first: File
      expression: '$({"first": inputs.files[0]})'
    in:
      files:
        source: [batched/merged, single/dl1]
        linkMerge: merge_flattened
    out: [first]

  single_again:
    label: Optional extra DL0 to DL2 pass
    run: workflows/workflow_dl0_to_dl2.cwl
    when: $(inputs.do_extra)
    in:
      dl0: pick_first/first
      do_extra: do_extra
    out: [dl2]
