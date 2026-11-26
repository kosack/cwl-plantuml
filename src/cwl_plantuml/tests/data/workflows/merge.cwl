#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: CommandLineTool
label: Merge Event Files
doc: |
  Merge multiple ctapipe output files into a single output file using ctapipe-merge.
  (DPPS-UC-130-1.8)

baseCommand:
  - ctapipe-merge

stderr: $(inputs.output_filename).log

inputs:
  log_level:
    type:
      type: enum
      symbols: [DEBUG, INFO, WARN, ERROR, CRITICAL]
    doc: |
      Logging level of the tool. Log output is written to stderr and captured
      in the ``log`` output.
    default: INFO
    inputBinding:
      prefix: --log-level

  output_filename:
    type: string
    doc: name of the output filename
    inputBinding:
      position: 1
      prefix: --output

  config:
    type:
      type: array
      items: File
      inputBinding:
        prefix: --config
    default: []
    inputBinding:
      position: 2
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      Sets the parameters for ctapipe-merge.

  provenance_log_filename:
    type: string
    doc: file in which to write the local provenance.
    default: ctapipe-merge.provenance.log
    inputBinding:
      position: 4
      prefix: --provenance-log

  strategy:
    type:
      type: enum
      symbols:
        - events-multiple-obs
        - events-single-ob
        - monitoring-only
    doc: how to merge files
    default: events-multiple-obs
    inputBinding:
      position: 5
      prefix: --merge-strategy

  input_files:
    type: File[]
    doc: |
      Paths to ctapipe files to be merged into output_filename
    inputBinding:
      position: 6

outputs:
  merged_output:
    type: File
    doc: output file.
    outputBinding:
      glob: $(inputs.output_filename)

  provenance_log:
    type: File
    doc: ctapipe format provenance log for this step.
    outputBinding:
      glob: $(inputs.provenance_log_filename)

  log:
    type: stderr
    doc: |
      Log output (stderr) of the tool. When running with ``cwltool``, use
      ``--log-dir`` to also keep logs of intermediate workflow steps, including
      those that failed.

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
