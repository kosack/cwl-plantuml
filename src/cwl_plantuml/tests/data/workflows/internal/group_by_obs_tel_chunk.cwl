#!/usr/bin/env cwl-runner
%YAML 1.1
---
cwlVersion: v1.2
class: ExpressionTool
label: Group DL0 files by obs, tel, and chunk
doc: Groups DL0 input files into groups by the key (obs_id, tel_id, chunk_id), for scattering.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  input_files:
    type: File[]

outputs:
  tel_chunks:
    type:
      type: array
      items:
        type: array
        items: File

expression: |
  ${
    var groups = {};

    for (var i = 0; i < inputs.input_files.length; i++) {
      var file = inputs.input_files[i];

      var stem = file.basename.replace(/\.fits\.fz$/, "");
      var parts = stem.split("_");

      if (parts.length !== 8) {
        throw new Error(
          "Expected 8 underscore-separated fields, got " +
          parts.length + ": " + file.basename
        );
      }

      var tel_id = parts[0];
      var obs_id = parts[4].substring(5);
      var data_type = parts[5] + "_" + parts[6];
      var chunk = parts[7].substring(5);

      var key = obs_id + ":" + data_type + ":" + tel_id + ":" + chunk;

      if (!(key in groups)) {
        groups[key] = [];
      }

      groups[key].push(file);
    }

    var result = [];
    for (var key in groups) {
      if (groups.hasOwnProperty(key)) {
        result.push(groups[key]);
      }
    }

    return {
      tel_chunks: result
    };
  }

$namespaces:
  s: https://schema.org/
s:license: https://spdx.org/licenses/BSD-3-Clause
s:codeRepository: https://gitlab.cta-observatory.org/cta-computing/dpps/datapipe/datapipe
