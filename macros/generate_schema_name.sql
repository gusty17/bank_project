{#
    Override dbt's default schema naming.

    By default dbt builds objects into <target_schema>_<custom_schema>
    (e.g. public_bronze). This override uses the custom schema name as-is,
    so models land in clean schemas: bronze, silver, gold.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
