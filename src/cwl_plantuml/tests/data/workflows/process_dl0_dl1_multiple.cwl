#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: Workflow
label: Process multiple DL0 files to a merged DL1 file
doc: |
  Process multiple dl0 files using process_dl0_dl1 and then merge
  the individual result files into one common output file using
  the merge tool.
  This is useful for processing simulation files in DIRAC as processing
  a single file per DIRAC job would result in very many, very short
  jobs that are not ideal for the workflow management system.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  input_files: File[]
  output_filename: string
  processing_config:
    type: File[]
    default: []
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
  camera_calibration: File?
  pointing: File?

outputs:
  merged_output:
    type: File
    outputSource: merge/merged_output

  merge_provenance_log:
    type: File
    outputSource: merge/provenance_log

  intermediate_provenance_log:
    type: File[]
    outputSource: process_dl0_to_dl1/provenance_log

steps:
  filenames:
    run: ./internal/output_names.cwl
    scatter: input_file
    in:
      input_file: input_files
    out: [output_filename, provenance_log_filename]

  process_dl0_to_dl1:
    run: process_dl0_dl1.cwl
    scatter: [dl0, dl1_filename, provenance_log_filename]
    scatterMethod: dotproduct # zip arguments
    in:
      dl0: input_files
      camera_calibration: camera_calibration
      pointing: pointing
      dl1_filename: filenames/output_filename
      provenance_log_filename: filenames/provenance_log_filename
      processing_config: processing_config
    out:
      - dl1
      - provenance_log
  merge:
    run: merge.cwl
    in:
      input_files: process_dl0_to_dl1/dl1
      output_filename: output_filename
    out:
      - merged_output
      - provenance_log

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
