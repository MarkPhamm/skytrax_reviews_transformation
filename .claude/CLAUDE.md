# Project Context

I'm learning CI/CD with dbt + Snowflake in this project.

# SQL Linting

- All SQL should be lowercased (keywords, functions, identifiers, literals)
- Linting rules are configured in `setup.cfg` at the project root (SQLFluff with dbt templater, Redshift dialect)
- Key rules: trailing commas, implicit table aliases, explicit column aliases, shorthand casting (`::`), no `RF04`/`ST06`
- Run `sqlfluff lint` and `sqlfluff fix` using the setup.cfg configuration
