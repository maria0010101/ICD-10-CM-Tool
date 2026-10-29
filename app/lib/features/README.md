# Feature boundaries

Search, hierarchy/detail, package management, and personal data are composed by
`../ui/dictionary_app.dart` and coordinated by `../app/controller.dart`.
SQL lives only in `../data`, and the package contract lives in `../domain`.
No dictionary data, source downloads, or Python code belongs in this directory.
