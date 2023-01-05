

-- all hosts
select distinct
  case
    when hostname != '' then hostname
    when device_name is not null and vendor != '' and scan_records.mac != '' then concat(device_name, ' (', vendor, ' ', scan_records.mac, ')')
    when vendor != '' and scan_records.mac != '' then concat(vendor, ' (', scan_records.mac, ')')
    when device_name is not null and scan_records.mac != '' then concat(device_name, ' (', scan_records.mac, ')')
    when scan_records.mac != '' then scan_records.mac
    else 'unkown host'
  end
from scan_records
  left join device_names on scan_records.mac = device_names.mac;


-- all hosts by scan with host status, only when the status changes
with scan_records_plus_host_string as (
  select 
    case
      when hostname != '' then hostname
      when device_name is not null and vendor != '' and scan_records.mac != '' then concat(device_name, ' (', vendor, ' ', scan_records.mac, ')')
      when vendor != '' and scan_records.mac != '' then concat(vendor, ' (', scan_records.mac, ')')
      when device_name is not null and scan_records.mac != '' then concat(device_name, ' (', scan_records.mac, ')')
      when scan_records.mac != '' then scan_records.mac
      else 'unkown host'
    end as host,
    scan_records.*
  from scan_records
    left join device_names on scan_records.mac = device_names.mac
), 
distinct_hosts as (
  select host, min(scanned_at) as first_seen from scan_records_plus_host_string join scans on scans.id = scan_records_plus_host_string.scan_id group by host
),
status_stream as (
  select
  id, scanned_at, case when sum(scan_records_plus_host_string.scan_id) is null then 'host down' else 'host up' end as host_status, distinct_hosts.host
from scans
  cross join distinct_hosts left outer
  join scan_records_plus_host_string
    on distinct_hosts.host = scan_records_plus_host_string.host and scans.id = scan_records_plus_host_string.scan_id
  where distinct_hosts.first_seen <= scans.scanned_at
  group by id, scanned_at, distinct_hosts.host
),
status_stream_with_lag as (
  select *, lag(host_status) over (partition by host order by scanned_at) as previous_status from status_stream
)
select scanned_at, host, host_status from status_stream_with_lag
  where previous_status is null or host_status != previous_status
  order by scanned_at
;
