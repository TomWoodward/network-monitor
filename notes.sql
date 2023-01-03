

-- all hosts
select distinct case when hostname != '' then hostname when vendor != '' and mac != '' then concat(vendor, ' (', mac, ')') when mac != '' then mac else 'unkown host' end from scan_records;


-- all hosts by scan with host status
with scan_records_plus_host_string as (
  select 
    case when hostname != '' then hostname when vendor != '' and mac != '' then concat(vendor, ' (', mac, ')') when mac != '' then mac else 'unkown host' end as host,
    scan_records.*
  from scan_records
), 
distinct_hosts as (
  select host, min(scanned_at) as first_seen from scan_records_plus_host_string join scans on scans.id = scan_records_plus_host_string.scan_id group by host
)
select
  id, scanned_at, case when sum(scan_records_plus_host_string.scan_id) is null then 'host down' else 'host up' end as host_status, distinct_hosts.host
from scans
  cross join distinct_hosts left outer
  join scan_records_plus_host_string
    on distinct_hosts.host = scan_records_plus_host_string.host and scans.id = scan_records_plus_host_string.scan_id
  where distinct_hosts.first_seen <= scans.scanned_at
  group by id, scanned_at, distinct_hosts.host
;


-- TODO self join that with previous record and filter to rows that have changed
