{
    "$graph": [
        {
            "class": "Workflow",
            "label": "Wrapper around process_dl0_dl1_multiple (adds a nesting level)",
            "requirements": [
                {
                    "class": "SubworkflowFeatureRequirement"
                }
            ],
            "inputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "id": "#inner_wrapper.cwl/input_files"
                },
                {
                    "type": "string",
                    "id": "#inner_wrapper.cwl/output_filename"
                }
            ],
            "steps": [
                {
                    "run": "#process_dl0_dl1_multiple.cwl",
                    "in": [
                        {
                            "source": "#inner_wrapper.cwl/input_files",
                            "id": "#inner_wrapper.cwl/multi/input_files"
                        },
                        {
                            "source": "#inner_wrapper.cwl/output_filename",
                            "id": "#inner_wrapper.cwl/multi/output_filename"
                        }
                    ],
                    "out": [
                        "#inner_wrapper.cwl/multi/merged_output",
                        "#inner_wrapper.cwl/multi/merge_provenance_log",
                        "#inner_wrapper.cwl/multi/intermediate_provenance_log"
                    ],
                    "id": "#inner_wrapper.cwl/multi"
                }
            ],
            "id": "#inner_wrapper.cwl",
            "outputs": [
                {
                    "type": "File",
                    "outputSource": "#inner_wrapper.cwl/multi/merged_output",
                    "id": "#inner_wrapper.cwl/merged"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "outputSource": [
                        "#inner_wrapper.cwl/multi/intermediate_provenance_log",
                        "#inner_wrapper.cwl/multi/merge_provenance_log"
                    ],
                    "linkMerge": "merge_flattened",
                    "id": "#inner_wrapper.cwl/provenance"
                }
            ]
        },
        {
            "class": "Workflow",
            "label": "Nested test workflow",
            "doc": "Test fixture exercising: subworkflows used twice, three nesting levels,\nscatter over a subworkflow, multiple sources with linkMerge, a conditional\nstep, and an inline (non-file) ExpressionTool.\n",
            "requirements": [
                {
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "class": "MultipleInputFeatureRequirement"
                },
                {
                    "class": "ScatterFeatureRequirement"
                },
                {
                    "class": "StepInputExpressionRequirement"
                },
                {
                    "class": "SubworkflowFeatureRequirement"
                }
            ],
            "inputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "string"
                    },
                    "id": "#main/batch_names"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "array",
                            "items": "File"
                        }
                    },
                    "id": "#main/batches"
                },
                {
                    "type": "File",
                    "id": "#main/dl0"
                },
                {
                    "type": "boolean",
                    "id": "#main/do_extra"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputSource": "#main/single/dl2",
                    "id": "#main/dl2"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "outputSource": "#main/single_again/dl2",
                    "id": "#main/extra_dl2"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "outputSource": "#main/batched/merged",
                    "id": "#main/merged"
                }
            ],
            "steps": [
                {
                    "run": "#inner_wrapper.cwl",
                    "scatter": [
                        "#main/batched/input_files",
                        "#main/batched/output_filename"
                    ],
                    "scatterMethod": "dotproduct",
                    "in": [
                        {
                            "source": "#main/batches",
                            "id": "#main/batched/input_files"
                        },
                        {
                            "source": "#main/batch_names",
                            "id": "#main/batched/output_filename"
                        }
                    ],
                    "out": [
                        "#main/batched/merged",
                        "#main/batched/provenance"
                    ],
                    "id": "#main/batched"
                },
                {
                    "label": "Pick the first file",
                    "run": {
                        "class": "ExpressionTool",
                        "inputs": [
                            {
                                "type": {
                                    "type": "array",
                                    "items": "File"
                                },
                                "id": "#main/pick_first/run/files"
                            }
                        ],
                        "outputs": [
                            {
                                "type": "File",
                                "id": "#main/pick_first/run/first"
                            }
                        ],
                        "expression": "$({\"first\": inputs.files[0]})"
                    },
                    "in": [
                        {
                            "source": [
                                "#main/batched/merged",
                                "#main/single/dl1"
                            ],
                            "linkMerge": "merge_flattened",
                            "id": "#main/pick_first/files"
                        }
                    ],
                    "out": [
                        "#main/pick_first/first"
                    ],
                    "id": "#main/pick_first"
                },
                {
                    "run": "#workflow_dl0_to_dl2.cwl",
                    "in": [
                        {
                            "source": "#main/dl0",
                            "id": "#main/single/dl0"
                        }
                    ],
                    "out": [
                        "#main/single/dl1",
                        "#main/single/dl2"
                    ],
                    "id": "#main/single"
                },
                {
                    "label": "Optional extra DL0 to DL2 pass",
                    "run": "#workflow_dl0_to_dl2.cwl",
                    "when": "$(inputs.do_extra)",
                    "in": [
                        {
                            "source": "#main/pick_first/first",
                            "id": "#main/single_again/dl0"
                        },
                        {
                            "source": "#main/do_extra",
                            "id": "#main/single_again/do_extra"
                        }
                    ],
                    "out": [
                        "#main/single_again/dl2"
                    ],
                    "id": "#main/single_again"
                }
            ],
            "id": "#main"
        },
        {
            "class": "ExpressionTool",
            "label": "Compute output filenames",
            "doc": "compute output filenames from input filenames\n",
            "requirements": [
                {
                    "class": "InlineJavascriptRequirement"
                }
            ],
            "inputs": [
                {
                    "type": "string",
                    "default": "dl1",
                    "id": "#output_names.cwl/data_level"
                },
                {
                    "type": "File",
                    "id": "#output_names.cwl/input_file"
                }
            ],
            "outputs": [
                {
                    "type": "string",
                    "id": "#output_names.cwl/log_filename"
                },
                {
                    "type": "string",
                    "id": "#output_names.cwl/output_filename"
                },
                {
                    "type": "string",
                    "id": "#output_names.cwl/provenance_log_filename"
                }
            ],
            "expression": "${\n  var name = inputs.input_file.basename;\n  var ext = \".\" + inputs.data_level + \".h5\"\n  var output;\n\n  if (name.match(/simtel(\\.zst|\\.gz)?$/) !== null) {\n    output = name.replace(/\\.simtel(\\.zst|\\.gz)?$/, ext);\n  } else if (name.match(/(\\.dl.*)\\.h5$/) !== null) {\n    output = name.replace(/(\\.dl.*)\\.h5$/, ext);\n  } else {\n    throw new Error(\"Input file '\" + name + \"' does not match expected pattern.\")\n  }\n  return {\n    output_filename: output,\n    log_filename: output + \".log\",\n    provenance_log_filename: output + \".provlog\",\n  }\n}\n",
            "id": "#output_names.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        },
        {
            "class": "CommandLineTool",
            "label": "Merge Event Files",
            "doc": "Merge multiple ctapipe output files into a single output file using ctapipe-merge.\n(DPPS-UC-130-1.8)\n",
            "baseCommand": [
                "ctapipe-merge"
            ],
            "stderr": "$(inputs.output_filename).log",
            "inputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "File",
                        "inputBinding": {
                            "prefix": "--config"
                        }
                    },
                    "default": [],
                    "inputBinding": {
                        "position": 2
                    },
                    "doc": "Ordered configuration files, passed as repeated ``--config`` arguments.\nLater files override conflicting settings from earlier files.\nSets the parameters for ctapipe-merge.\n",
                    "id": "#merge.cwl/config"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "doc": "Paths to ctapipe files to be merged into output_filename\n",
                    "inputBinding": {
                        "position": 6
                    },
                    "id": "#merge.cwl/input_files"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#merge.cwl/log_level/DEBUG",
                            "#merge.cwl/log_level/INFO",
                            "#merge.cwl/log_level/WARN",
                            "#merge.cwl/log_level/ERROR",
                            "#merge.cwl/log_level/CRITICAL"
                        ]
                    },
                    "doc": "Logging level of the tool. Log output is written to stderr and captured\nin the ``log`` output.\n",
                    "default": "INFO",
                    "inputBinding": {
                        "prefix": "--log-level"
                    },
                    "id": "#merge.cwl/log_level"
                },
                {
                    "type": "string",
                    "doc": "name of the output filename",
                    "inputBinding": {
                        "position": 1,
                        "prefix": "--output"
                    },
                    "id": "#merge.cwl/output_filename"
                },
                {
                    "type": "string",
                    "doc": "file in which to write the local provenance.",
                    "default": "ctapipe-merge.provenance.log",
                    "inputBinding": {
                        "position": 4,
                        "prefix": "--provenance-log"
                    },
                    "id": "#merge.cwl/provenance_log_filename"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#merge.cwl/strategy/events-multiple-obs",
                            "#merge.cwl/strategy/events-single-ob",
                            "#merge.cwl/strategy/monitoring-only"
                        ]
                    },
                    "doc": "how to merge files",
                    "default": "events-multiple-obs",
                    "inputBinding": {
                        "position": 5,
                        "prefix": "--merge-strategy"
                    },
                    "id": "#merge.cwl/strategy"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "doc": "Log output (stderr) of the tool. When running with ``cwltool``, use\n``--log-dir`` to also keep logs of intermediate workflow steps, including\nthose that failed.\n",
                    "id": "#merge.cwl/log",
                    "outputBinding": {
                        "glob": "$(inputs.output_filename).log"
                    }
                },
                {
                    "type": "File",
                    "doc": "output file.",
                    "outputBinding": {
                        "glob": "$(inputs.output_filename)"
                    },
                    "id": "#merge.cwl/merged_output"
                },
                {
                    "type": "File",
                    "doc": "ctapipe format provenance log for this step.",
                    "outputBinding": {
                        "glob": "$(inputs.provenance_log_filename)"
                    },
                    "id": "#merge.cwl/provenance_log"
                }
            ],
            "id": "#merge.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        },
        {
            "class": "CommandLineTool",
            "label": "Process DL0 to DL1",
            "doc": "Processes a single file from DL0 to DL1 using the ctapipe-process tool.\n(*DPPS-UC-130-1.2.1*)\n",
            "requirements": [
                {
                    "listing": "$(Array.isArray(inputs.dl0) ? inputs.dl0 : [inputs.dl0])",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "class": "InlineJavascriptRequirement"
                }
            ],
            "baseCommand": "ctapipe-process",
            "arguments": [
                "--DataWriter.write_dl2=False",
                {
                    "valueFrom": "$((inputs.camera_calibration != null) || (inputs.pointing != null) ? \"--ProcessorTool.monitoring_sources=HDF5MonitoringSource\" : null)"
                }
            ],
            "stderr": "$(inputs.dl1_filename).log",
            "inputs": [
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "DL1/Monitoring/Telescope/Calibration file from CalibPipe, containing pedestal and flat-field\ncoefficients for the telescope(s) being processed.\n",
                    "inputBinding": {
                        "prefix": "--HDF5MonitoringSource.input_files"
                    },
                    "id": "#process_dl0_dl1.cwl/camera_calibration"
                },
                {
                    "type": [
                        "File",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "doc": "Input file or list of files at any data level transformable to DL1\nsupported by the installed ctapipe io plugins. Paths can also be URLs.\nFor a list, only the first file is passed to --input.\n",
                    "inputBinding": {
                        "prefix": "--input",
                        "valueFrom": "$(Array.isArray(self) ? self[0] : self)"
                    },
                    "id": "#process_dl0_dl1.cwl/dl0"
                },
                {
                    "type": "string",
                    "doc": "name of the DL1 output file",
                    "inputBinding": {
                        "prefix": "--output"
                    },
                    "id": "#process_dl0_dl1.cwl/dl1_filename"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#process_dl0_dl1.cwl/log_level/DEBUG",
                            "#process_dl0_dl1.cwl/log_level/INFO",
                            "#process_dl0_dl1.cwl/log_level/WARN",
                            "#process_dl0_dl1.cwl/log_level/ERROR",
                            "#process_dl0_dl1.cwl/log_level/CRITICAL"
                        ]
                    },
                    "doc": "Logging level of the tool. Log output is written to stderr and captured\nin the ``log`` output.\n",
                    "default": "INFO",
                    "inputBinding": {
                        "prefix": "--log-level"
                    },
                    "id": "#process_dl0_dl1.cwl/log_level"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "DL1/Monitoring/Telescope/Pointing file, containing the corrected pointing\nmonitoring data for the telescope(s) being processed.\n",
                    "inputBinding": {
                        "prefix": "--HDF5MonitoringSource.input_files"
                    },
                    "id": "#process_dl0_dl1.cwl/pointing"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File",
                        "inputBinding": {
                            "prefix": "--config"
                        }
                    },
                    "default": [],
                    "doc": "Ordered configuration files, passed as repeated ``--config`` arguments.\nLater files override conflicting settings from earlier files.\nSets the reconstruction parameters that apply to DL0 to DL1.\nSee ``ctapipe-process --help-all`` for a list of all options, or the output\nof ``ctapipe-quickstart`` for sample configuration files.\n",
                    "id": "#process_dl0_dl1.cwl/processing_config"
                },
                {
                    "type": "string",
                    "doc": "file in which to write the local ctapipe-process provenance.",
                    "default": "ctapipe-process_dl0_dl1.provenance.log",
                    "inputBinding": {
                        "prefix": "--provenance-log"
                    },
                    "id": "#process_dl0_dl1.cwl/provenance_log_filename"
                },
                {
                    "doc": "If true, store DL1 images in the output file",
                    "type": "boolean",
                    "default": true,
                    "inputBinding": {
                        "prefix": "--DataWriter.write_dl1_images",
                        "valueFrom": "$(self ? \"True\" : \"False\")"
                    },
                    "id": "#process_dl0_dl1.cwl/write_images"
                },
                {
                    "doc": "If true, store DL1 image parameters in the output file",
                    "type": "boolean",
                    "default": true,
                    "inputBinding": {
                        "prefix": "--DataWriter.write_dl1_parameters",
                        "valueFrom": "$(self ? \"True\" : \"False\")"
                    },
                    "id": "#process_dl0_dl1.cwl/write_parameters"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "doc": "HDF5 format output file.",
                    "outputBinding": {
                        "glob": "$(inputs.dl1_filename)"
                    },
                    "id": "#process_dl0_dl1.cwl/dl1"
                },
                {
                    "type": "File",
                    "doc": "Log output (stderr) of the tool. When running with ``cwltool``, use\n``--log-dir`` to also keep logs of intermediate workflow steps, including\nthose that failed.\n",
                    "id": "#process_dl0_dl1.cwl/log",
                    "outputBinding": {
                        "glob": "$(inputs.dl1_filename).log"
                    }
                },
                {
                    "type": "File",
                    "doc": "ctapipe format provenance log for this step.",
                    "outputBinding": {
                        "glob": "$(inputs.provenance_log_filename)"
                    },
                    "id": "#process_dl0_dl1.cwl/provenance_log"
                }
            ],
            "id": "#process_dl0_dl1.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        },
        {
            "class": "Workflow",
            "label": "Process multiple DL0 files to a merged DL1 file",
            "doc": "Process multiple dl0 files using process_dl0_dl1 and then merge\nthe individual result files into one common output file using\nthe merge tool.\nThis is useful for processing simulation files in DIRAC as processing\na single file per DIRAC job would result in very many, very short\njobs that are not ideal for the workflow management system.\n",
            "requirements": [
                {
                    "class": "ScatterFeatureRequirement"
                }
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "id": "#process_dl0_dl1_multiple.cwl/camera_calibration"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "id": "#process_dl0_dl1_multiple.cwl/input_files"
                },
                {
                    "type": "string",
                    "id": "#process_dl0_dl1_multiple.cwl/output_filename"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "id": "#process_dl0_dl1_multiple.cwl/pointing"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "default": [],
                    "doc": "Ordered configuration files, passed as repeated ``--config`` arguments.\nLater files override conflicting settings from earlier files.\n",
                    "id": "#process_dl0_dl1_multiple.cwl/processing_config"
                }
            ],
            "outputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "outputSource": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/provenance_log",
                    "id": "#process_dl0_dl1_multiple.cwl/intermediate_provenance_log"
                },
                {
                    "type": "File",
                    "outputSource": "#process_dl0_dl1_multiple.cwl/merge/provenance_log",
                    "id": "#process_dl0_dl1_multiple.cwl/merge_provenance_log"
                },
                {
                    "type": "File",
                    "outputSource": "#process_dl0_dl1_multiple.cwl/merge/merged_output",
                    "id": "#process_dl0_dl1_multiple.cwl/merged_output"
                }
            ],
            "steps": [
                {
                    "run": "#output_names.cwl",
                    "scatter": "#process_dl0_dl1_multiple.cwl/filenames/input_file",
                    "in": [
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/input_files",
                            "id": "#process_dl0_dl1_multiple.cwl/filenames/input_file"
                        }
                    ],
                    "out": [
                        "#process_dl0_dl1_multiple.cwl/filenames/output_filename",
                        "#process_dl0_dl1_multiple.cwl/filenames/provenance_log_filename"
                    ],
                    "id": "#process_dl0_dl1_multiple.cwl/filenames"
                },
                {
                    "run": "#merge.cwl",
                    "in": [
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl1",
                            "id": "#process_dl0_dl1_multiple.cwl/merge/input_files"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/output_filename",
                            "id": "#process_dl0_dl1_multiple.cwl/merge/output_filename"
                        }
                    ],
                    "out": [
                        "#process_dl0_dl1_multiple.cwl/merge/merged_output",
                        "#process_dl0_dl1_multiple.cwl/merge/provenance_log"
                    ],
                    "id": "#process_dl0_dl1_multiple.cwl/merge"
                },
                {
                    "run": "#process_dl0_dl1.cwl",
                    "scatter": [
                        "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl0",
                        "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl1_filename",
                        "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/provenance_log_filename"
                    ],
                    "scatterMethod": "dotproduct",
                    "in": [
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/camera_calibration",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/camera_calibration"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/input_files",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl0"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/filenames/output_filename",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl1_filename"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/pointing",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/pointing"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/processing_config",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/processing_config"
                        },
                        {
                            "source": "#process_dl0_dl1_multiple.cwl/filenames/provenance_log_filename",
                            "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/provenance_log_filename"
                        }
                    ],
                    "out": [
                        "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/dl1",
                        "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1/provenance_log"
                    ],
                    "id": "#process_dl0_dl1_multiple.cwl/process_dl0_to_dl1"
                }
            ],
            "id": "#process_dl0_dl1_multiple.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        },
        {
            "class": "CommandLineTool",
            "label": "Process DL1 to DL2",
            "doc": "Processes a single file from DL1 to DL2 using the ``ctapipe-process`` tool.\n(*DPPS-UC-130-1.2.2*). Minimally, Hillas-style geometry reconstruction is\nperformed, but energy, gammaness, mono reconstruction may be included by using\nan appropriate data processing configuration.\n",
            "requirements": [
                {
                    "class": "InlineJavascriptRequirement"
                }
            ],
            "baseCommand": [
                "ctapipe-process",
                "--DataWriter.write_dl1_images=False",
                "--DataWriter.write_dl2=True"
            ],
            "stderr": "$(inputs.dl2_filename).log",
            "inputs": [
                {
                    "type": "File",
                    "doc": "path to input file, which can be at any data level transformable to DL2\nthat is supported by the installed ctapipe io plugins. It can also be a\nURL.\n",
                    "inputBinding": {
                        "prefix": "--input"
                    },
                    "id": "#process_dl1_dl2.cwl/dl1"
                },
                {
                    "type": "string",
                    "doc": "name of the DL2 output file",
                    "inputBinding": {
                        "prefix": "--output"
                    },
                    "id": "#process_dl1_dl2.cwl/dl2_filename"
                },
                {
                    "doc": "If true, also store DL1 image parameters in the output file",
                    "type": "boolean",
                    "default": false,
                    "inputBinding": {
                        "prefix": "--DataWriter.write_dl1_parameters",
                        "valueFrom": "$(self ? \"True\" : \"False\")"
                    },
                    "id": "#process_dl1_dl2.cwl/keep_dl1_parameters"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#process_dl1_dl2.cwl/log_level/DEBUG",
                            "#process_dl1_dl2.cwl/log_level/INFO",
                            "#process_dl1_dl2.cwl/log_level/WARN",
                            "#process_dl1_dl2.cwl/log_level/ERROR",
                            "#process_dl1_dl2.cwl/log_level/CRITICAL"
                        ]
                    },
                    "doc": "Logging level of the tool. Log output is written to stderr and captured\nin the ``log`` output.\n",
                    "default": "INFO",
                    "inputBinding": {
                        "prefix": "--log-level"
                    },
                    "id": "#process_dl1_dl2.cwl/log_level"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File",
                        "inputBinding": {
                            "prefix": "--config"
                        }
                    },
                    "default": [],
                    "doc": "Ordered configuration files, passed as repeated ``--config`` arguments.\nLater files override conflicting settings from earlier files.\nSets the reconstruction parameters that apply to DL1 to DL2.\nSee ``ctapipe-process --help-all`` for a list of all options, or the output\nof ``ctapipe-quickstart`` for sample configuration files.\n",
                    "id": "#process_dl1_dl2.cwl/processing_config"
                },
                {
                    "type": "string",
                    "doc": "file in which to write the local ctapipe-process provenance.",
                    "default": "ctapipe-process_dl1_dl2.provenance.log",
                    "inputBinding": {
                        "prefix": "--provenance-log"
                    },
                    "id": "#process_dl1_dl2.cwl/provenance_log_filename"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "doc": "HDF5 format output file.",
                    "outputBinding": {
                        "glob": "$(inputs.dl2_filename)"
                    },
                    "id": "#process_dl1_dl2.cwl/dl2"
                },
                {
                    "type": "File",
                    "doc": "Log output (stderr) of the tool. When running with ``cwltool``, use\n``--log-dir`` to also keep logs of intermediate workflow steps, including\nthose that failed.\n",
                    "id": "#process_dl1_dl2.cwl/log",
                    "outputBinding": {
                        "glob": "$(inputs.dl2_filename).log"
                    }
                },
                {
                    "type": "File",
                    "doc": "ctapipe format provenance log for this step.",
                    "outputBinding": {
                        "glob": "$(inputs.provenance_log_filename)"
                    },
                    "id": "#process_dl1_dl2.cwl/provenance_log"
                }
            ],
            "id": "#process_dl1_dl2.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        },
        {
            "class": "Workflow",
            "label": "Process DL0 to DL2",
            "doc": "Process an input file from DL0 to separate DL1 and DL2 outputs.\n",
            "requirements": [
                {
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "class": "StepInputExpressionRequirement"
                }
            ],
            "inputs": [
                {
                    "doc": "DL0 data file in format supported by ctapipe.",
                    "type": "File",
                    "id": "#workflow_dl0_to_dl2.cwl/dl0"
                },
                {
                    "doc": "Ordered configuration files, passed as repeated ``--config`` arguments.\nLater files override conflicting settings from earlier files.\ndata processing configuration for ctapipe-process.\n",
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "default": [],
                    "id": "#workflow_dl0_to_dl2.cwl/processing_config"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "doc": "ctapipe format provenance log for the DL0 to DL1 step.",
                    "outputSource": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/provenance_log",
                    "id": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1_provenance_log"
                },
                {
                    "type": "File",
                    "doc": "DL1 data file in ctapipe hdf5 format",
                    "outputSource": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl1",
                    "id": "#workflow_dl0_to_dl2.cwl/dl1"
                },
                {
                    "type": "File",
                    "doc": "ctapipe format provenance log for the DL1 to DL2 step.",
                    "outputSource": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/provenance_log",
                    "id": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2_provenance_log"
                },
                {
                    "type": "File",
                    "doc": "DL2 data file in ctapipe hdf5 format",
                    "outputSource": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/dl2",
                    "id": "#workflow_dl0_to_dl2.cwl/dl2"
                }
            ],
            "steps": [
                {
                    "run": "#process_dl0_dl1.cwl",
                    "in": [
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl0",
                            "id": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl0"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl1_names/output_filename",
                            "id": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl1_filename"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/processing_config",
                            "id": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/processing_config"
                        }
                    ],
                    "out": [
                        "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl1",
                        "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/provenance_log"
                    ],
                    "id": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1"
                },
                {
                    "run": "#output_names.cwl",
                    "in": [
                        {
                            "valueFrom": "dl1",
                            "id": "#workflow_dl0_to_dl2.cwl/dl1_names/data_level"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl0",
                            "id": "#workflow_dl0_to_dl2.cwl/dl1_names/input_file"
                        }
                    ],
                    "out": [
                        "#workflow_dl0_to_dl2.cwl/dl1_names/output_filename"
                    ],
                    "id": "#workflow_dl0_to_dl2.cwl/dl1_names"
                },
                {
                    "run": "#process_dl1_dl2.cwl",
                    "in": [
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl1",
                            "id": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/dl1"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl2_names/output_filename",
                            "id": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/dl2_filename"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/processing_config",
                            "id": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/processing_config"
                        }
                    ],
                    "out": [
                        "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/dl2",
                        "#workflow_dl0_to_dl2.cwl/dl1_to_dl2/provenance_log"
                    ],
                    "id": "#workflow_dl0_to_dl2.cwl/dl1_to_dl2"
                },
                {
                    "run": "#output_names.cwl",
                    "in": [
                        {
                            "valueFrom": "dl2",
                            "id": "#workflow_dl0_to_dl2.cwl/dl2_names/data_level"
                        },
                        {
                            "source": "#workflow_dl0_to_dl2.cwl/dl0_to_dl1/dl1",
                            "id": "#workflow_dl0_to_dl2.cwl/dl2_names/input_file"
                        }
                    ],
                    "out": [
                        "#workflow_dl0_to_dl2.cwl/dl2_names/output_filename"
                    ],
                    "id": "#workflow_dl0_to_dl2.cwl/dl2_names"
                }
            ],
            "id": "#workflow_dl0_to_dl2.cwl",
            "https://schema.org/license": "https://spdx.org/licenses/BSD-3-Clause",
            "https://schema.org/codeRepository": "https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe"
        }
    ],
    "cwlVersion": "v1.2"
}
