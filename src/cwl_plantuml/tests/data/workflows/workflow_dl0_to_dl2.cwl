#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: Workflow
label: Process DL0 to DL2
doc: |
  Process an input file from DL0 to separate DL1 and DL2 outputs.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  processing_config:
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      data processing configuration for ctapipe-process.
    type: File[]
    default: []

  dl0:
    doc: DL0 data file in format supported by ctapipe.
    type: File

outputs:
  dl1:
    type: File
    doc: DL1 data file in ctapipe hdf5 format
    outputSource: dl0_to_dl1/dl1
  dl2:
    type: File
    doc: DL2 data file in ctapipe hdf5 format
    outputSource: dl1_to_dl2/dl2
  dl0_to_dl1_provenance_log:
    type: File
    doc: ctapipe format provenance log for the DL0 to DL1 step.
    outputSource: dl0_to_dl1/provenance_log
  dl1_to_dl2_provenance_log:
    type: File
    doc: ctapipe format provenance log for the DL1 to DL2 step.
    outputSource: dl1_to_dl2/provenance_log

steps:
  dl1_names:
    run: ./internal/output_names.cwl
    in:
      input_file: dl0
      data_level:
        valueFrom: dl1
    out: [output_filename]

  dl0_to_dl1:
    run: process_dl0_dl1.cwl
    in:
      processing_config: processing_config
      dl0: dl0
      dl1_filename: dl1_names/output_filename
    out: [dl1, provenance_log]

  dl2_names:
    run: ./internal/output_names.cwl
    in:
      input_file: dl0_to_dl1/dl1
      data_level:
        valueFrom: dl2
    out: [output_filename]

  dl1_to_dl2:
    run: process_dl1_dl2.cwl
    in:
      processing_config: processing_config
      dl1: dl0_to_dl1/dl1
      dl2_filename: dl2_names/output_filename
    out: [dl2, provenance_log]

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
