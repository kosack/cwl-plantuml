#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: CommandLineTool
label: Train Disp Reconstruction Model
doc: |
  Train a geometry reconstruction model that can predict the displacement of the
  shower point-of-origin along the image axis for a single telescope from from
  DL1 and DL2 input parameters. This parameter can be used for monoscopic or
  stereoscopic shower geometry reconstruction.

baseCommand: ctapipe-train-disp-reconstructor

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
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      Sets the parameters for the ctapipe-train-disp-reconstructor tool.
  gamma_events:
    type: File
    doc: simulated gamma-ray events with known energies to train on.
    inputBinding:
      prefix: --input
  output_filename:
    type: string
    doc: filename of output geometry reconstruction model, as a zipped BagIt archive (``.zip``).
    default: disp_recomodel.zip
    inputBinding:
      prefix: --output
  provenance_log_filename:
    type: string
    doc: file in which to write the local provenance.
    default: train_disp_model.provenance.log
    inputBinding:
      prefix: --provenance-log
  cv_output_filename:
    type: string?
    doc: |
      filename for output cross-validation file, in HDF5 format (e.g.
      ``disp_cross_validation.h5``). If not set, no cross-validation output
      is written.
    inputBinding:
      prefix: --cv-output

outputs:
  reco_model:
    type: File
    doc: disp reconstruction model, as a zipped BagIt archive (``.zip``).
    outputBinding:
      glob: $(inputs.output_filename)
  cross_validation:
    type: File?
    doc: Cross-validation output for the model, if ``cv_output_filename`` is set
    outputBinding:
      glob: $(inputs.cv_output_filename)
  provenance_log:
    type: File
    doc: ctapipe-format provenance log for this step
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
