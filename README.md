# cwl-plantuml

Convert CWL workflows to PlantUML with more details than you get from cwlviewer
(or `cwltool --print-dot`):

* hierarchical workflows, with sub-workflows expanded down to a chosen depth
  (and shown as black boxes below it),
* every step shows its stereotype (`«CommandLineTool»`, `«ExpressionTool»`,
  `«Workflow»`, ...), its `label`, and all its input and output ports,
* connectors go from the exact output port to the exact input port,
* scatter, conditional steps, `valueFrom`, defaults and `linkMerge` are shown,
* options to keep large workflows readable: shared merge nodes, text
  references instead of arrows for widely shared inputs, hiding ports by name,
  and a different color/line style for each output's connectors,
* CTAO brand colors.

Disclaimer: this was heavily vibe-coded and was created to help me debug some
complex CWL workflows. I'm putting it here in case it's useful to others.

## Usage

```
$ pip install cwl-plantuml
$ cwl-plantuml workflow.cwl -o workflow.puml             # write PlantUML
$ cwl-plantuml workflow.cwl -o workflow.puml --render svg # ... and run plantuml
$ cwl-plantuml workflow.cwl --depth 0 --hide-ports provenance -o workflow.puml
$ cwl-plantuml --help
```

`--render` needs the [PlantUML](https://plantuml.com) executable (and Java),
e.g. `mamba install -c conda-forge plantuml`. See the documentation
(`docs/usage.rst`) for all options, the diagram conventions and examples.

The test suite includes real workflows from the CTAO DataPipe
(`src/cwl_plantuml/tests/data/workflows`). Tests that render diagrams are
skipped if `plantuml` is not installed.

## Project Structure / Packaging

This project uses `setuptools` for packaging and defines all necessary options
in the file `pyproject.toml`. `setup.py` and `setup.cfg` are not needed.

* `setuptools` documentation: https://setuptools.pypa.io/en/latest/userguide/index.html
* `Configuring setuptools with pyproject.toml`: https://setuptools.pypa.io/en/latest/userguide/pyproject_config.html
* Relevant PEPs:
    * [PEP 517 – A build-system independent format for source trees](https://peps.python.org/pep-0517)
    * [PEP 518 – Specifying Minimum Build System Requirements for Python Projects](https://peps.python.org/pep-0518)
    * [PEP 621 – Storing project metadata in pyproject.toml](https://peps.python.org/pep-0621/)
    * [PEP 660 – Editable installs for pyproject.toml based builds (wheel based)](https://peps.python.org/pep-0660/)

This project uses the `src/` based layout, as this avoids several issues with editable installs and confusion with what
is imported (local directory or installed module).
See [setuptools/src-layout](https://setuptools.pypa.io/en/latest/userguide/package_discovery.html#src-layout).


### Editable installations

Editable installations in this setup rely on PEP 660 (see above), support was introduced in `pip` 21.3 (released 2021-10)
and setuptools 64.0 (released 2022-08). The setuptools version is required in `pyproject.toml`.

To install in editable mode, use
```
$ pip install -e .
```

you can add extras, e.g. for developing and building the docs, use
```
$ pip install -e '.[dev,doc,test]'
```

or just
```
$ pip install -e '.[all]'
```


Keep in mind that editable installations have limitations as to what changes can take effect automatically
without rerunning `pip install -e .`. Python code changes to existing files take effect, but for example
adding new entry-points, changes to the source code of compiled extensions etc. will require rerunning the
installation.

See <https://setuptools.pypa.io/en/latest/userguide/development_mode.html#limitations>

## Versioning

This project uses `setuptools_scm` to automatically generate the version from the last git tag.
For local development, `setuptools_scm` will build a development version. For releases,
version information is included in the sdist and wheel files and `setuptools_scm` is not used
when installing those. The setup is somewhat complex and was taken from astropy. It ensures that
the setuptools_scm version is only used in development setups, not in the released packages.

Because of this, `setuptools_scm` needs at least one git commit to determine a version;
if this project was just created from the `python-project-template` cookiecutter, an initial
commit has already been made for you.

## CI

For github, see `.github/workflows/`, for gitlab, see `.gitlab-ci.yml`


## Integration with the CTAO Sonarqube instances

The `.gitlab-ci.yml` contains a step to scan the project using sonarqube,
also ingesting the coverage report created in the previous step.
This needs the `SONAR_TOKEN` secret variable to be set in the CI configuration
of the repository and adapting the configuration in `sonar-project.properties`
for the given project.
Token and project key can be obtained when creating a new project in the sonarqube
instance via the GitLab integration, just follow the steps.

## Docs

Build the documentation in html format using:

```
$ make -C docs html
```

To view them, you can run:

```
$ python -m http.server -d docs/build/html
```

You can also install `sphinx-autobuild` and run

```
sphinx-autobuild docs docs/build/html
```
to get a continuously running and updating preview of the docs while you edit them.

Docs are automatically deployed on main and tags to gitlab pages.
