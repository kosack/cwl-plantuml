#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: CommandLineTool
label: Process DL1 to DL2
doc: |
  Processes a single file from DL1 to DL2 using the ``ctapipe-process`` tool.
  (*DPPS-UC-130-1.2.2*). Minimally, Hillas-style geometry reconstruction is
  performed, but energy, gammaness, mono reconstruction may be included by using
  an appropriate data processing configuration.

requirements:
  InlineJavascriptRequirement: {}

baseCommand:
  - ctapipe-process
  - --DataWriter.write_dl1_images=False
  - --DataWriter.write_dl2=True

stderr: $(inputs.dl2_filename).log

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

  processing_config:
    type:
      type: array
      items: File
      inputBinding:
        prefix: --config
    default: []
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      Sets the reconstruction parameters that apply to DL1 to DL2.
      See ``ctapipe-process --help-all`` for a list of all options, or the output
      of ``ctapipe-quickstart`` for sample configuration files.

  dl1:
    type: File
    doc: |
      path to input file, which can be at any data level transformable to DL2
      that is supported by the installed ctapipe io plugins. It can also be a
      URL.
    inputBinding:
      prefix: --input

  keep_dl1_parameters:
    doc: If true, also store DL1 image parameters in the output file
    type: boolean
    default: false
    inputBinding:
      prefix: --DataWriter.write_dl1_parameters
      valueFrom: '$(self ? "True" : "False")'

  dl2_filename:
    type: string
    doc: name of the DL2 output file
    inputBinding:
      prefix: --output

  provenance_log_filename:
    type: string
    doc: file in which to write the local ctapipe-process provenance.
    default: ctapipe-process_dl1_dl2.provenance.log
    inputBinding:
      prefix: --provenance-log

outputs:
  dl2:
    type: File
    doc: HDF5 format output file.
    outputBinding:
      glob: $(inputs.dl2_filename)

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
