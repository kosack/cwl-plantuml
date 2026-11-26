#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: CommandLineTool
label: Process DL0 to DL1
doc: |
  Processes a single file from DL0 to DL1 using the ctapipe-process tool.
  (*DPPS-UC-130-1.2.1*)

requirements:
  InlineJavascriptRequirement: {}
  # ctapipe_io_zfits looks for parallel streams to the main input file via globbing
  # however, by default, cwl puts each input file in a separate temporary directory,
  # preventing the globbing from finding the parallel streams.
  # this makes sure all dl0 input files are in a common directory
  InitialWorkDirRequirement:
    listing: "$(Array.isArray(inputs.dl0) ? inputs.dl0 : [inputs.dl0])"

baseCommand: ctapipe-process

arguments:
  - --DataWriter.write_dl2=False
  # add HDF5MonitoringSource to source list if calibration file is given
  - valueFrom: '$((inputs.camera_calibration != null) || (inputs.pointing != null) ? "--ProcessorTool.monitoring_sources=HDF5MonitoringSource" : null)'

stderr: $(inputs.dl1_filename).log

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
      Sets the reconstruction parameters that apply to DL0 to DL1.
      See ``ctapipe-process --help-all`` for a list of all options, or the output
      of ``ctapipe-quickstart`` for sample configuration files.

  dl0:
    type: [File, "File[]"]
    doc: |
      Input file or list of files at any data level transformable to DL1
      supported by the installed ctapipe io plugins. Paths can also be URLs.
      For a list, only the first file is passed to --input.
    inputBinding:
      prefix: --input
      valueFrom: "$(Array.isArray(self) ? self[0] : self)"

  write_images:
    doc: If true, store DL1 images in the output file
    type: boolean
    default: true
    inputBinding:
      prefix: --DataWriter.write_dl1_images
      valueFrom: '$(self ? "True" : "False")'

  write_parameters:
    doc: If true, store DL1 image parameters in the output file
    type: boolean
    default: true
    inputBinding:
      prefix: --DataWriter.write_dl1_parameters
      valueFrom: '$(self ? "True" : "False")'

  dl1_filename:
    type: string
    doc: name of the DL1 output file
    inputBinding:
      prefix: --output

  camera_calibration:
    type: File?
    doc: |
      DL1/Monitoring/Telescope/Calibration file from CalibPipe, containing pedestal and flat-field
      coefficients for the telescope(s) being processed.
    inputBinding:
      prefix: --HDF5MonitoringSource.input_files

  pointing:
    type: File?
    doc: |
      DL1/Monitoring/Telescope/Pointing file, containing the corrected pointing
      monitoring data for the telescope(s) being processed.
    inputBinding:
      prefix: --HDF5MonitoringSource.input_files

  provenance_log_filename:
    type: string
    doc: file in which to write the local ctapipe-process provenance.
    default: ctapipe-process_dl0_dl1.provenance.log
    inputBinding:
      prefix: --provenance-log

outputs:
  dl1:
    type: File
    doc: HDF5 format output file.
    outputBinding:
      glob: $(inputs.dl1_filename)

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
