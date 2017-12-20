
report_sanity_checker looks at a report, widget, or table view and runs a basic sanity check.

# usage

```bash
vmdb
../gems/miq_tools/report_sanity_checker/report_sanity_checker.rb # reads product/reports
../gems/miq_tools/report_sanity_checker/report_sanity_checker.rb ../manageiq-ui-classic/product/views/
../gems/miq_tools/report_sanity_checker/report_sanity_checker.rb underutilized.yml
../gems/miq_tools/report_sanity_checker/report_sanity_checker.rb -w # widgets
```

Currenty the views are now in a separate repo, so those files need to be referenced.

# Sample output

```bash
../gems/miq_tools/report_sanity_checker/report_sanity_checker.rb underutilized.yml
```

### underutilized.yaml (Vm):

| column                                         | virtual | sql  | sort | hidden    | cond | 
|:-----------------------------------------------|:--------|:-----|:-----|:----------|:-----|
| managed.cust_portfolio                         | custom  | ruby | sort |           |      | 
| managed.cust_owner                             | custom  | ruby |      |           |      | 
| name                                           |         | sql  |      |           |      | 
| created_on                                     |         | sql  |      |           |      | 
| active                                         | attr    | sql  |      |           |      | 
| cpu_total_cores                                | attr    | sql  |      |           |      | 
| overallocated_vcpus_pct                        | attr    | ruby |      |           | cond | 
| cpu_usagemhz_rate_average_max_over_time_period | attr    | sql  |      |           |      | 
| mem_cpu                                        | attr    | sql  |      |           |      | 
| overallocated_mem_pct                          | attr    | ruby |      |           | cond | 
| derived_memory_used_max_over_time_period       | attr    | sql  |      |           |      | 
| allocated_disk_storage                         | attr    | sql  |      |           |      | 
| used_disk_storage                              | attr    | sql  |      |           |      | 
| v_pct_free_disk_space                          | attr    | sql  |      |           | cond | 
| v_pct_used_disk_space                          | attr    | sql  |      |           |      | 


This tells us a few things:

- This report is based upon the `Vm` model (first line)
- `managed.cust_portfolio` is sorting on a tag - this is determined in ruby. sorting in ruby requires all records to be in memory.
- `name` is a regular sql column
- `active` is a virtual attribute but is derived in sql - you can sort or filter on this
- Record filter uses 3 columns. Since `overallocated_vcpus_pct` is determined in ruby, filtering is performed in ruby. All records are brought back from the database.
- `v_pct_free_disk_space` is calculated on the fly, but can be calculated in sql. Filtering on this field does not require all records be loaded into memory. Since the `MiqExpression` has an `OR` for these fields, this optimization can not be used.

Take away:
- A report that only filters by `v_pct_free_disk_space` would be much quicker and wouldn't download every VM into memory.
- the whole `Vm` table is downloaded. This report will run slowly.
