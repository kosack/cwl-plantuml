"""
Configuration file for the Sphinx documentation builder.

This file only contains a selection of the most common options. For a full
list see the documentation:
https://www.sphinx-doc.org/en/master/usage/configuration.html
"""

import os

# -- Project information -----------------------------------------------------
# import your own package here
import cwl_plantuml

project = "cwl-plantuml"
copyright = ""
author = "Karl Kosack"
version = cwl_plantuml.__version__
# The full version, including alpha/beta/rc tags.
release = version


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    "sphinx.ext.githubpages",
    "sphinx.ext.intersphinx",
    "sphinx.ext.autodoc",
    "sphinx.ext.autosummary",
    "numpydoc",
    "sphinx_changelog",
]

# Add any paths that contain templates here, relative to this directory.
templates_path = []

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ["changes"]

# have all links automatically associated with the right domain.
default_role = "py:obj"


# intersphinx allows referencing other packages sphinx docs
intersphinx_mapping = {
    "python": ("https://docs.python.org/3/", None),
}

# -- Options for HTML output -------------------------------------------------

html_theme = "pydata_sphinx_theme"
html_theme_options = dict(
    navigation_with_keys=False,
    # setup for displaying multiple versions, also see setup in .gitlab-ci.yml
    switcher=dict(
        json_url=os.getenv("CI_PAGES_URL", "") + "/versions.json",
        version_match="latest" if ".dev" in version else f"v{version}",
    ),
    navbar_center=["version-switcher", "navbar-nav"],
    # versions.json does not exist yet before the first release is published,
    # and pydata-sphinx-theme treats an unparsable response as a fatal build
    # error rather than a warning (unlike the local-file-not-found case) -
    # skip the eager validation so early docs builds don't fail because of it
    check_switcher=False,
    logo=dict(text="cwl-plantuml", alt_text="cwl-plantuml"),
)

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = []

# -- numpydoc / nitpicky settings ----------------------------------------------
# do not generate autosummary tables for class members (needs stub pages)
numpydoc_show_class_members = False
# cwltool does not provide an intersphinx inventory
nitpick_ignore_regex = [("py:class", r"cwltool\..*")]
