#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: CommandLineTool
label: Compute IRF
doc: |
  Compute IRF and IRF metrics from pre-processed events and event selection
  cuts. (DPPS-UC-130-1.6)

baseCommand: ctapipe-compute-irf

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

  config:
    type:
      type: array
      items: File
      inputBinding:
        prefix: --config
    default: []
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      Sets the parameters for the ctapipe-compute-irf tool.

  gammas:
    type: File
    doc: |
      path to input file containing pre-processed gamma-ray signal events.
    inputBinding:
      prefix: --gamma-file

  protons:
    type: File
    doc: |
      path to input file containing pre-processed proton background events.
    inputBinding:
      prefix: --proton-file

  electrons:
    type: File
    doc: |
      path to input file containing pre-processed electron background events.
    inputBinding:
      prefix: --electron-file

  event_selection:
    type: File
    doc: FITS file containing optimized cuts to apply
    inputBinding:
      prefix: --cuts

  output_filename:
    type: string
    doc: filename of output IRF file.
    default: irf.fits.gz
    inputBinding:
      prefix: --output

  output_metrics_filename:
    type: string
    doc: filename of output IRF benchmarks file.
    default: performance_metrics.fits.gz
    inputBinding:
      prefix: --benchmark-output

  provenance_log_filename:
    type: string
    doc: file in which to write the local provenance.
    default: compute_irf.provenance.log
    inputBinding:
      prefix: --provenance-log

outputs:
  irf:
    type: File
    doc: File containing computed IRF
    outputBinding:
      glob: $(inputs.output_filename)
  metrics:
    type: File
    doc: File containing IRF performance metrics
    outputBinding:
      glob: $(inputs.output_metrics_filename)
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
