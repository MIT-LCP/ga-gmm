/*
  ards_data_extraction
  To extract related data for the cohort for ARDS study
  Created on   : Mar 2013 by Mornin Feng
  Last updated : May 2013 by mornin

*/
--drop materialized view ards_data_v3;
--drop table ards_data_v3_1;
--drop table ards_data_mar13_v2;
--create table ards_data_Apr13 as


drop table ards2_data_may13;
create table ards2_data_may13 as
with pnuemonia_group as
(select distinct ards.icustay_id, 1 as flg
from mornin.ards2_cohort_may13 ards join mimic2v26.icd9 icd9
on ards.hadm_id=icd9.hadm_id
where code 
  in ('003.22', '020.3', '020.4', '020.5', '021.2', '022.1', '031.0', '039.1', '052.1', '055.1', '073.0', '083.0', '112.4', '114.0', '114.4', '114.5', '115.05', '115.15', '115.95', '130.4'
     ,'136.3', '480.0', '480.1', '480.2', '480.3', '480.8', '480.9', '481', '482.0', '482.1', '482.2', '482.3', '482.30', '482.31', '482.32', '482.39', '482.4', '482.40', '482.41', '482.42'
     ,'482.49', '482.8', '482.81', '482.82', '482.83', '482.84', '482.89', '482.9', '483', '483.0', '483.1', '483.8', '484.1', '484.3', '484.5', '484.6', '484.7', '484.8', '485', '486'
     ,'513.0', '517.1')
)
--select count(*) from pnuemonia_group; --1053

, sepsis_group as
(select distinct ards.icustay_id, 1 as flg
from mornin.ards2_cohort_may13 ards join mimic2devel.martin_sepsis_admissions sep
on ards.hadm_id = sep.hadm_id
)
--select count(*) from sepsis_group; --784

, vent_time as
(select
distinct ards.icustay_id
, sum(round((extract(day from (vent.end_time-vent.begin_time))+
extract(hour from (vent.end_time-vent.begin_time))/24+
extract(minute from (vent.end_time-vent.begin_time))/60/24), 3)) as vent_time_day
from mornin.ards2_cohort_may13 ards
join mimic2devel.ventilation vent
on ards.icustay_id = vent.icustay_id
group by ards.icustay_id
order by 1
)

--select * from vent_time;
--select count(*) from vent_time;
--where vent_time_day<=0;

, survive_day as
(select 
ards.icustay_id
, (case when d.dod is null then 730 -- 2 years
        when (extract(day from (d.dod-ards.icustay_intime))+extract(hour from (d.dod-ards.icustay_intime))/24)>730 then 730
    else round((extract(day from (d.dod-ards.icustay_intime))+
    extract(hour from (d.dod-ards.icustay_intime))/24), 3) 
  end)as survival_day
, (case when d.dod is null then 1 
        when (extract(day from (d.dod-ards.icustay_intime))+extract(hour from (d.dod-ards.icustay_intime))/24)>730 then 1
        else 0 end) as sensor_flg
from mornin.ards2_cohort_may13 ards
join mimic2devel.d_patients d 
  on ards.subject_id=d.subject_id 
)

--select * from survive_day order by 2 desc;


--------------------- icd9 groupings --------------------------------------
, icd9_group as
(select
icustay_id
, replace(ICD9_GROUPINGS, ' ','') as icd9_group
from mornin.ARDS_ICD9_GROUPING
)

, icd9_codes as
(select distinct
icd9.code
, icd9.description
, gp.icd9_group
from icd9_group gp
join mimic2v26.icustay_detail icud on gp.icustay_id=icud.icustay_id
join mimic2v26.icd9 icd9 on icd9.hadm_id=icud.hadm_id and icd9.sequence=1
where gp.icd9_group in ('malignancy', 'neurological', 'headinjury')
order by 3
)

--select * from icd9_codes;
, icd9_flg as
(select
ards.icustay_id
, case when icd9.code in (select code from icd9_codes where icd9_group='malignancy') then 1 else 0 end as malignancy_flg
, case when icd9.code in (select code from icd9_codes where icd9_group='neurological') then 1 else 0 end as neurological_flg
, case when icd9.code in (select code from icd9_codes where icd9_group='headinjury') then 1 else 0 end as headinjury_flg
from mornin.ards2_cohort_may13 ards
join mimic2v26.icd9 icd9 on icd9.hadm_id=ards.hadm_id and icd9.sequence=1
)

--select * from icd9_flg;

,demo_data as
(select
ards.subject_id
, ards.hadm_id
, ards.icustay_id
, ards.icustay_intime
--
, ards.category
, (case when ards.category='ADMIN' then 1 when ards.category='LATE' then 2 else 0 end) as category_num
--
, ards.ARDS_SEVERITY
, (case when ards.ARDS_SEVERITY = 'MILD' then 1
        when ards.ARDS_SEVERITY = 'MODERATE' then 2
        when ards.ARDS_SEVERITY = 'SEVERE' then 3
        else 0
  end) as ARDS_SEVERITY_NUM
--
, ards.day_to_onset

--
, icud.gender as gender
,case when icud.gender='M' then 1 else 0 end as gender_num
,case when icud.ICUSTAY_ADMIT_AGE>120 then 91.4 else icud.ICUSTAY_ADMIT_AGE end as age --correction for age
,icud.WEIGHT_FIRST
,icud.HEIGHT
--
,icud.SAPSI_FIRST
,icud.SOFA_FIRST
, elix.TWENTY_EIGHT_DAY_MORT_PT as elix_mimic_28_day
, elix.ONE_YR_MORT_PT as elix_mimic_1_year
, elix.TWO_YR_MORT_PT as elix_mimic_2_year
, elix.TWO_YEAR_SURVIVAL_PT as elix_mimic_surv
--
, ards.service_unit
, case when service_unit is null then null 
      when service_unit='CCU' then 3
      when service_unit='CSRU' then 2
      when service_unit='SICU' then 1
      else 0 end as service_unit_num
, ards.chf_flg
, ards.vent_48hr_flg
, case when pnu.flg is null then 0 else 1 end as pnuemonia_flg
, case when sep.flg is null then 0 else 1 end as sepsis_flg
, icd9.malignancy_flg
, icd9.neurological_flg
, icd9.headinjury_flg
--
, (case when icud.ICUSTAY_EXPIRE_FLG='Y' then 1 else 0 end) as icu_exp_flg
,round(icud.ICUSTAY_LOS/60/24,3) as icustay_los
--
, v.vent_time_day
, s.survival_day
, s.sensor_flg
, (case when s.survival_day<=28 then 1 else 0 end) as mort_28_day
, (case when s.survival_day<=365 then 1 else 0 end) as mort_1_year
, (case when s.survival_day<730 then 1 else 0 end) as mort_2_year
from mornin.ARDS2_COHORT_may13 ards
join mimic2v26.icustay_detail icud on ards.icustay_id=icud.icustay_id
left join MIMIC2DEVEL.elixhauser_points elix on elix.hadm_id=ards.hadm_id
left join  pnuemonia_group pnu on pnu.icustay_id=ards.icustay_id
left join sepsis_group sep on sep.icustay_id=ards.icustay_id
left join icd9_flg icd9 on icd9.icustay_id=ards.icustay_id
left join vent_time v on ards.icustay_id=v.icustay_id
left join survive_day s on ards.icustay_id=s.icustay_id
)
select * from demo_data;
--select count(*) from demo_data where sepsis_flg=1;
--select sum(sensor_flg*mort_2_year) from demo_data;








/*********************************** remove missing values ********************/
drop table ards2_surv_data_may13;
create table ards2_surv_data_may13 as
select *
from mornin.ards2_data_may13
where 
--chf_flg=0 -- exclude chf patients
--and 
service_unit_num<2 --exclude csru and ccu
and gender_num is not null
and age is not null
and weight_first is not null
and sapsi_first is not null
and elix_mimic_surv is not null
and sepsis_flg is not null
and malignancy_flg is not null
and neurological_flg is not null
and headinjury_flg is not null;










--------------------------- correct for missing value -------------------------
--drop table ards_data_mar13_nonan;
create table ards_data_Apr13_named as
select 
ICUSTAY_ID
,CATEGORY
,CATEGORY_NUM
,ADMIN_FLG
,LATE_FLG
,ARDS_SEVERITY
, ARDS_SEVERITY_NUM
/*,SEVER_GROUP
,SEVER_1_FLG
,SEVER_2_FLG
,SEVER_3_FLG
,SEVER_4_FLG
,SEVER_5_FLG
,SEVER_6_FLG*/
,DAY_TO_ONSET
,SUBJECT_ID
,HADM_ID
,GENDER
,GENDER_NUM
, (case 
    when age is null then (select median(age) from mornin.ARDS_DATA_MAR13) 
    else age end) as AGE
, (case 
    when WEIGHT_FIRST is null then (select median(WEIGHT_FIRST) from mornin.ARDS_DATA_MAR13) 
    else WEIGHT_FIRST end) as WEIGHT_FIRST
, (case 
    when HEIGHT is null then (select median(HEIGHT) from mornin.ARDS_DATA_MAR13) 
    else HEIGHT end) as HEIGHT
, (case 
    when SAPSI_FIRST is null then (select median(SAPSI_FIRST) from mornin.ARDS_DATA_MAR13) 
    else SAPSI_FIRST end) as SAPSI_FIRST
, (case 
    when SOFA_FIRST is null then (select median(SOFA_FIRST) from mornin.ARDS_DATA_MAR13) 
    else SOFA_FIRST end) as SOFA_FIRST
,ICU_EXP_FLG
,ICUSTAY_LOS
,ICUSTAY_FIRST_SERVICE
,MICU_FLG
,ICUSTAY_INTIME
,VENT_TIME_DAY
,SEPSIS_FLG
, (case 
    when ELIX_28_DAY is null then (select median(ELIX_28_DAY) from mornin.ARDS_DATA_MAR13) 
    else ELIX_28_DAY end) as ELIX_28_DAY
, (case 
    when ELIX_1_YEAR is null then (select median(ELIX_1_YEAR) from mornin.ARDS_DATA_MAR13) 
    else ELIX_1_YEAR end) as ELIX_1_YEAR
, (case 
    when ELIX_2_YEAR is null then (select median(ELIX_2_YEAR) from mornin.ARDS_DATA_MAR13) 
    else ELIX_2_YEAR end) as ELIX_2_YEAR
, (case 
    when ELIX_SURV is null then (select median(ELIX_SURV) from mornin.ARDS_DATA_MAR13) 
    else ELIX_SURV end) as ELIX_SURV
, (case 
    when ELIX_MIMIC_28_DAY is null then (select median(ELIX_MIMIC_28_DAY) from mornin.ARDS_DATA_MAR13) 
    else ELIX_MIMIC_28_DAY end) as ELIX_MIMIC_28_DAY
, (case 
    when ELIX_MIMIC_1_YEAR is null then (select median(ELIX_MIMIC_1_YEAR) from mornin.ARDS_DATA_MAR13) 
    else ELIX_MIMIC_1_YEAR end) as ELIX_MIMIC_1_YEAR
, (case 
    when ELIX_MIMIC_2_YEAR is null then (select median(ELIX_MIMIC_2_YEAR) from mornin.ARDS_DATA_MAR13) 
    else ELIX_MIMIC_2_YEAR end) as ELIX_MIMIC_2_YEAR
, (case 
    when ELIX_MIMIC_SURV is null then (select median(ELIX_MIMIC_SURV) from mornin.ARDS_DATA_MAR13) 
    else ELIX_MIMIC_SURV end) as ELIX_MIMIC_SURV
,ICD9_GROUP
,ICD9_INF
,ICD9_MAL
,ICD9_NEU
,ICD9_CAR
,ICD9_RES
,ICD9_GAS
,ICD9_TRA
,ICD9_HEA
,SURVIVAL_DAY
,MORT_28_DAY
,MORT_1_YEAR
,MORT_2_YEAR
,SENSOR_FLG
from mornin.ARDS_DATA_Apr13;

--select * from mornin.ARDS_DATA_MAR13;

---------------- Add in admission date ---------------------------------
create table mornin.ards_admin_dt as
select 
ards.subject_id
--, (case when hr_to_onset is null then 735 else round(ards.hr_to_onset/24, 3) end) as day_to_onset --735 means never onsets
, to_char(adm.admit_dt, 'dd-mm-yyyy') as admin_date
from mornin.ARDS_DATA_MAR13_NONAN ards
left join mimic2v26.admissions adm on ards.hadm_id=adm.hadm_id;

-------------- Output data with adminssion year group: 0: 2001~2002; 1: 2003; 2: 2004; 3: 2005; 4: 2006~2007 ---------------------------
drop table mornin.ARDS_DATA_MAR13_NONNAN_V2;

create table mornin.ARDS_DATA_MAR13_NONNAN_V2 as
select 
ards.*
, (case when ards.sever_group in (1,4) then 1
        when ards.sever_group in (2,5) then 2
        when ards.sever_group in (3,6) then 3
        else 0
        end) as sever_3grp
, (case when hr_to_onset is null then 735 else round(ards.hr_to_onset/24, 3) end) as day_to_onset --735 means never onsets
, adm.admin_yr_grp
from mornin.ARDS_DATA_MAR13_NONAN ards
left join mornin.ards_admin_yr adm on adm.subject_id=ards.subject_id;