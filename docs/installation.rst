Installation
============

User Installation
-----------------

As a user, install from pypi:

.. code-block:: shell

    $ pip install cwl-plantuml

Or ``conda-forge``:

.. code-block:: shell

    $ mamba install -c conda-forge cwl-plantuml



Developer Setup
---------------

As a developer, clone the repository, create a virtual environment
and then install the package in development mode:

.. code-block:: shell

   $ git clone git@gitlab.cta-observatory.org:cta-computing/common/cwl-plantuml
   $ cd cwl-plantuml
   $ python -m venv venv
   $ source venv/bin/activate
   $ pip install -e .[test,doc,dev]

The same also works with conda, create a conda env instead of a venv above.
