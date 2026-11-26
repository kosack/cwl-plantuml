#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow
label: Wrapper around process_dl0_dl1_multiple (adds a nesting level)
requirements:
  SubworkflowFeatureRequirement: {}
inputs:
  input_files: File[]
  output_filename: string
outputs:
  merged:
    type: File
    outputSource: multi/merged_output
  provenance:
    type: File[]
    outputSource: [multi/intermediate_provenance_log, multi/merge_provenance_log]
    linkMerge: merge_flattened
steps:
  multi:
    run: workflows/process_dl0_dl1_multiple.cwl
    in:
      input_files: input_files
      output_filename: output_filename
    out: [merged_output, merge_provenance_log, intermediate_provenance_log]
