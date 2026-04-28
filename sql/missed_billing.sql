
--consultant table
create table if not exists consultants
(
consultant_id integer primary key
, name text not null
, specialty text not null
, start_date date not null
);

--apps table
create table if not exists appointments
(
appointment_id integer primary key
, consultant_id integer not null
, clinic text not null
, appointment_date date not null
, status text check (status in ('Completed', 'Cancelled', 'Did Not Attend'))
, foreign key (consultant_id) references consultants (consultant_id)
);

--billing table
create table if not exists billing
(
billing_id integer primary key
, appointment_id integer not null
, billed_amount numeric(10, 2) not null
, billed_date date not null 
, foreign key (appointment_id) references appointments (appointment_id)
);

--payments table
create table if not exists payments
(
payment_id integer primary key
, billing_id integer not null
, paid_amount numeric(10, 2) not null
, paid_date date not null
, foreign key (billing_id) references billing (billing_id)
);

--cons ranked by income
create materialized view if not exists consultant_income as
select 
con.consultant_id
, con.name as Consultant
, count(b.billing_id) as Total_Billed
, sum(b.billed_amount) as Total_Income
from billing b
join appointments apps on b.appointment_id = apps.appointment_id
join consultants con on apps.consultant_id = con.consultant_id
group by con.consultant_id, con.name
order by Total_Income desc
;

--index consultant_income table
create unique index on consultant_income(consultant_id);
create index on consultant_income(total_income desc);

--refresh con income
refresh materialized view concurrently consultant_income;

--monthly income
select 
to_char(billed_date, 'Month') as Month
, count(billing_id) as Monthly_Billed
, sum(billed_amount) as Monthly_Income
from billing b
group by Month
order by monthly_income desc
;

--income by clinic
select 
apps.clinic
, sum(b.billed_amount) as Income
from billing b
join appointments apps on b.appointment_id = apps.appointment_id
group by apps.clinic
order by Income desc
;

--overall con performance
select 
apps.consultant_id
, con.name as Consultant
, count(apps.appointment_id) as Total_Appointments
, count(b.billing_id) as Total_Billed
, ROUND((count(b.billing_id)::float/count(apps.appointment_id) * 100)::numeric, 2)
as Billing_Rate
from appointments apps
join Consultants con on apps.consultant_id = con.consultant_id
left join Billing b on apps.appointment_id = b.appointment_id
group by apps.consultant_id, con.name
order by Billing_Rate
;

--missed billing
create materialized view if not exists missed_billing as
select
apps.consultant_id
, con.name as Consultant
, apps.appointment_id
, apps.clinic
, apps.appointment_date
, b.billing_id
from appointments apps
join Consultants con on apps.consultant_id = con.consultant_id
left join Billing b on apps.appointment_id = b.appointment_id
where apps.status = 'Completed'
and b.billing_id is null
;

--create unique index for missed_billing mview
create unique index if not exists missed_billing_pk on missed_billing(appointment_id);

--refresh concurrently
refresh materialized view concurrently missed_billing;


select * from appointments;
