#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: Workflow
label: Train Reconstruction Models
doc: |
  Train the energy, gammaness, and disp reconstruction models from DL2
  simulated events. The energy model is trained first and applied to the
  gamma and background events, so that the reconstructed energy is available
  as an input feature when training the gammaness model. The disp model does
  not use the reconstructed energy, so it is trained directly on the gamma
  events and can be applied independently of the energy model.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  config:
    type: File[]
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments
      to each of the training tools. Later files override conflicting
      settings from earlier files.

  gamma_events:
    type: File
    doc: |
      simulated gamma-ray events (DL2) used to train all three models, and as
      the signal sample for the gammaness model.

  background_events:
    type: File
    doc: |
      background events (DL2, e.g. protons), used only as the background
      sample for the gammaness model.

  energy_model_filename:
    type: string
    default: energy.recomodel.zip
    doc: filename of the output energy reconstruction model.

  gammaness_model_filename:
    type: string
    default: gammaness.recomodel.zip
    doc: filename of the output gammaness reconstruction model.

  disp_model_filename:
    type: string
    default: disp.recomodel.zip
    doc: filename of the output disp reconstruction model.

outputs:
  energy_model:
    type: File
    doc: energy reconstruction model, as a zipped BagIt archive.
    outputSource: train_energy/reco_model
  gammaness_model:
    type: File
    doc: gammaness reconstruction model, as a zipped BagIt archive.
    outputSource: train_gammaness/reco_model
  disp_model:
    type: File
    doc: disp reconstruction model, as a zipped BagIt archive.
    outputSource: train_disp/reco_model
  train_energy_provenance_log:
    type: File
    outputSource: train_energy/provenance_log
  apply_energy_gammas_provenance_log:
    type: File
    outputSource: apply_energy_gammas/provenance_log
  apply_energy_background_provenance_log:
    type: File
    outputSource: apply_energy_background/provenance_log
  train_gammaness_provenance_log:
    type: File
    outputSource: train_gammaness/provenance_log
  train_disp_provenance_log:
    type: File
    outputSource: train_disp/provenance_log

steps:
  train_energy:
    run: ../../train_energy_model.cwl
    in:
      config: config
      gamma_events: gamma_events
      output_filename: energy_model_filename
    out:
      - reco_model
      - provenance_log

  apply_energy_gammas:
    run: ../../apply_models.cwl
    in:
      events: gamma_events
      models:
        source: train_energy/reco_model
        valueFrom: $([self])
      output_filename:
        valueFrom: $(inputs.events.nameroot + ".energy.h5")
      provenance_log_filename:
        default: apply_energy_gammas.provenance.log
    out:
      - applied_events
      - provenance_log

  apply_energy_background:
    run: ../../apply_models.cwl
    in:
      events: background_events
      models:
        source: train_energy/reco_model
        valueFrom: $([self])
      output_filename:
        valueFrom: $(inputs.events.nameroot + ".energy.h5")
      provenance_log_filename:
        default: apply_energy_background.provenance.log
    out:
      - applied_events
      - provenance_log

  train_gammaness:
    run: ../../train_gammaness_model.cwl
    in:
      config: config
      gamma_events: apply_energy_gammas/applied_events
      background_events: apply_energy_background/applied_events
      output_filename: gammaness_model_filename
    out:
      - reco_model
      - provenance_log

  train_disp:
    run: ../../train_disp_model.cwl
    in:
      config: config
      gamma_events: gamma_events
      output_filename: disp_model_filename
    out:
      - reco_model
      - provenance_log

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
