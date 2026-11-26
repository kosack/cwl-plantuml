#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: Workflow
label: Process OB to DL1
doc: |
  Processes all the DL0/Event files for a given OB into a merged DL1b output
  file. Files from different telescopes and chunks are processed in parallel,
  while those with different SDH instances are merged with each telescope-chunk
  job (*DPPS UC-130-3.1.1*).  In this implementation, scattering is done by parsing the filenames, which must be in the format specified by the ACADA-DPPS ICD.

requirements:
  ScatterFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  dl0_files:
    type: File[]
    doc: List of all DL0/Event files for a given OB.

  processing_config:
    doc: |
      Ordered configuration files, passed as repeated ``--config`` arguments.
      Later files override conflicting settings from earlier files.
      configuration for ctapipe-process containing necessary parameters for this workflow.
    type: File[]
    default: []

  camera_calibration:
    type: File?
    doc: |
      HDF5 file containing DL1/Monitoring/Telescope/CameraCalibration
      information for all telescopes in the OB. If not provided, no DL1
      calibration (corrections to the R1 calibration) will be performed.

  pointing:
    type: File?
    doc: |
      DL1/Monitoring/Telescope/Pointing file, containing the corrected pointing
      monitoring data for the telescope(s) being processed.

outputs:
  dl1:
    type: File
    outputSource: merge_dl1/merged_output
    doc: Merged DL1b file for the OB containing all telescope parameters.
  dl1_provenance:
    type: File[]
    outputSource: process_to_dl1/provenance_log
    doc: Provenance logs for each processed telescope-chunk, in ctapipe JSON format
  merge_provenance:
    type: File
    outputSource: merge_dl1/provenance_log
    doc: Provenance log for the final merge, in ctapipe JSON format.

steps:
  group_by_obs_tel_chunk:
    run: internal/group_by_obs_tel_chunk.cwl
    in:
      input_files: dl0_files
    out:
      - tel_chunks

  process_to_dl1:
    run: process_dl0_dl1.cwl
    # each job gets all SDH streams of one tel/chunk, so they are all staged
    # in its working directory, where ctapipe_io_zfits finds them.
    scatter: dl0
    in:
      dl0: group_by_obs_tel_chunk/tel_chunks

      processing_config: processing_config

      write_images:
        valueFrom: $(false)

      write_parameters:
        valueFrom: $(true)

      # inputs.dl0 is the group of files of this scatter job
      dl1_filename:
        valueFrom: $(inputs.dl0[0].basename.replace(/\.fits\.fz$/, ".dl1b.h5"))

      provenance_log_filename:
        valueFrom: $(inputs.dl0[0].basename.replace(/\.fits\.fz$/, ".dl1b.provenance.log"))

      camera_calibration: camera_calibration
      pointing: pointing

    out:
      - dl1
      - provenance_log

  merge_dl1:
    run: merge.cwl
    in:
      input_files:
        source: process_to_dl1/dl1
      output_filename:
        # this transforms the name by dropping SDH and CHUNK parts, which should now be merged.
        valueFrom: |
          ${
            var newname = inputs.input_files[0].basename;
            var parts = newname.split("_");

            var filtered = parts.filter(function(part) {
                return !part.startsWith("SDH")
                    && !part.startsWith("CHUNK")
                    && !part.startsWith("TEL")
                    && !part.startsWith("SBID")
            });
            filtered = filtered.slice(0,-1);
            return filtered.join("_") + ".dl1.h5";
           }
      strategy:
        valueFrom: |
          ${return "events-single-ob";}
    out:
      - merged_output
      - provenance_log

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
