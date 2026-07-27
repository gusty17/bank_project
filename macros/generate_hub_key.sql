{#
    Generate a Data Vault hub/link key by hashing one or more business-key
    columns. Wraps dbt_utils.generate_surrogate_key so hashing stays
    consistent everywhere a key is produced (hubs, links, satellites).
#}
{% macro generate_hub_key(columns) %}
    {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}
