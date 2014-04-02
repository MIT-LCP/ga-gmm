/*
  
  Created on   : Dec 2012 by Mornin Feng
  Last updated : August 2013
 Extract data for echo project and  project

*/

--SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

--explain plan for



--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Data Extraction -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
drop table echo_sepsis_data_jan14;
create table echo_sepsis_data_jan14 as
with population_1 as
(select * from mornin.SEPSIS_COHORT_JAN14
)

--select count(distinct icustay_id) from population;
--select * from population;


--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Demographic and basic data  -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
, population_2 as
(select distinct
pop.*
, round(icud.icustay_los/60/24, 2) as icu_los_day
, round(icud.hospital_los/60/24,2) as hospital_los_day
, case when icud.icustay_admit_age>120 then 91.4 else  icud.icustay_admit_age end as age
--, icud.gender as gender
, case when icud.gender is null then null
  when icud.gender = 'M' then 1 else 0 end as gender_num
, icud.WEIGHT_FIRST
, bmi.bmi
, icud.SAPSI_FIRST
, icud.SOFA_FIRST
, elix.TWENTY_EIGHT_DAY_MORT_PT
, elix.ONE_YEAR_SURVIVAL_PT
, elix.TWO_YEAR_SURVIVAL_PT
, icud.ICUSTAY_FIRST_SERVICE as service_unit
, case when ICUSTAY_FIRST_SERVICE='SICU' then 1
      when ICUSTAY_FIRST_SERVICE='CCU' then 2
      when ICUSTAY_FIRST_SERVICE='CSRU' then 3
      else 0 --MICU & FICU
      end
  as service_num
, icud.icustay_intime 
, icud.icustay_outtime
, to_char(icud.ICUSTAY_INTIME, 'Day') as day_icu_intime
, to_number(to_char(icud.ICUSTAY_INTIME, 'D')) as day_icu_intime_num
, extract(hour from icud.ICUSTAY_INTIME) as hour_icu_intime
, round((extract(day from d.dod-icud.icustay_intime)+extract(hour from d.dod-icud.icustay_intime)/24),2) as mort_day
from population_1 pop 
left join  mimic2v26.icustay_detail icud on pop.icustay_id = icud.icustay_id
left join mimic2devel.obesity_bmi bmi on bmi.icustay_id=pop.icustay_id
left join MIMIC2DEVEL.d_patients d on d.subject_id=pop.subject_id
left join mimic2devel.ELIXHAUSER_POINTS elix on elix.hadm_id=pop.hadm_id
)

--select distinct service_unit from population_2;
--select max(hour_icu_intime) from population_2;
--select * from population_2;


, population as
(select p.*
, case when p.mort_day<=28 then 1 else 0 end as day_28_flg
, case when p.mort_day <=730 then p.mort_day 
     else 731  end as mort_day_censored
, case when p.mort_day<=730 then 0 else 1 end as censor_flg from population_2 p where icu_los_day>=0.5 --- stayed in icu for more than 12 hours
)

--select * from population; --6517


--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Vent patients  -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

,vent_group_1 as
(select distinct 
--pop.hadm_id
pop.icustay_id
, 1 as flg
--, icud.icustay_id
--, vent.end_time
--, vent.begin_time
--, (vent.end_time-vent.begin_time) as time_diff
,  sum(round((extract(day from (vent.end_time-vent.begin_time))+
extract(hour from (vent.end_time-vent.begin_time))/24+1/24+
extract(minute from (vent.end_time-vent.begin_time))/60/24), 3)) as time_total_day
, pop.icu_los_day
from population pop
--join mimic2v26.icustay_detail icud on icud.icustay_id = pop.icustay_id
join mimic2devel.ventilation vent on vent.icustay_id = pop.icustay_id
group by pop.icustay_id, pop.icu_los_day
order by 1
)

--select * from vent_group_1; ---4161
--select * from vent_group where hadm_id=2798;
, vent_group as
(select v.*
, case when (icu_los_day-time_total_day)>0 then (icu_los_day-time_total_day) else 0 end  as vent_free_day
from vent_group_1 v
)

--select * from vent_group order by vent_free_day asc;


------------ label vent patients at 1st 12 hour-------------------------------
,vent_12hr_group as
(select distinct 
--pop.hadm_id
pop.icustay_id
, 1 as flg
--, vent.begin_time
--, icud.icustay_intime
from population pop
--join mimic2v26.icustay_detail icud on icud.hadm_id = pop.hadm_id and icud.icustay_seq=1
join mimic2devel.ventilation vent 
  on vent.icustay_id = pop.icustay_id 
    --and vent.seq=1
    and vent.begin_time<=pop.icustay_intime+12/24
order by 1
)

--select * from vent_12hr_group; --3488

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Mediaction Dat: vasopressor & Anesthetic -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------


-------------------------------------------  label vaso patients ----------------------------
--- a more accurate calculation of vaso time may be necessary!!!!!
, vaso_group_1 as
(select 
distinct 
--pop.hadm_id
pop.icustay_id
, pop.icustay_intime
, pop.icustay_outtime
--, pop.icustay_outtime-pop.icustay_intime as temp
, pop.icu_los_day
, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime asc) as begin_time
, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime desc) as end_time
, 1 as flg
from population pop
--join mimic2v26.icustay_detail icud on icud.hadm_id = pop.hadm_id
join mimic2v26.medevents med on med.icustay_id=pop.icustay_id and med.itemid in (46,47,120,43,307,44,119,309,51,127,128)
where med.charttime is not null
)

--select extract(day from temp) as temp_day from vaso_group_1 where icustay_id=2613;
--select count(distinct icustay_id) from vaso_group;

, vaso_group_2 as
(select
--hadm_id
icustay_id
, round(extract(day from (end_time-begin_time)) 
    + extract(hour from (end_time-begin_time))/24 +1/24 --- add additional 1 hour
    + extract(minute from (end_time-begin_time))/60/24, 2) as time_diff_day
, icu_los_day
--, round(extract(day from (icustay_outtime-icustay_intime)) 
--    + extract(hour from (icustay_outtime-icustay_intime))/24 
--    + extract(minute from (icustay_outtime-icustay_intime))/60/24, 2) as temp
, flg
from vaso_group_1
)


--select * from vaso_group_2 where icustay_id=2613;

, vaso_group as
(select distinct
icustay_id
, flg
, time_diff_day
, icu_los_day
, case when (icu_los_day-time_diff_day)<0 then 0 else (icu_los_day-time_diff_day) end as vaso_free_Day
from vaso_group_2
)

--select * from vaso_group_final order by vaso_free_day;  ---2915

--------------  label vaso patients for 1st 12 hours ----------------------------
--, vaso_group_12_hr_1 as
--(select 
--distinct 
----pop.hadm_id
--pop.icustay_id
--, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime asc) as begin_time
--, pop.ICUSTAY_INTIME
--from population pop
----join mimic2v26.icustay_detail icud on icud.hadm_id = pop.hadm_id and ICUSTAY_SEQ =1
--join mimic2v26.medevents med on med.icustay_id=pop.icustay_id and med.itemid in (46,47,120,43,307,44,119,309,51,127,128)
--where med.charttime is not null
--order by 1
--)

--select count(distinct hadm_id) from vaso_group_12_hr_1;
--select * from vaso_group_12_hr_1; --2991


, vaso_12hr_group as
(select distinct icustay_id
, 1 as flg
from vaso_group_1
where begin_time <= ICUSTAY_INTIME+12/24
)

--select * from vaso_12hr_group; --2016

-------------------------------------------  label Anesthetic patients ----------------------------
, anes_group_1 as
(select 
distinct 
--pop.hadm_id
pop.icustay_id
, pop.icustay_intime
, pop.icustay_outtime
--, pop.icustay_outtime-pop.icustay_intime as temp
, pop.icu_los_day
, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime asc) as begin_time
, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime desc) as end_time
, 1 as flg
from population pop
--join mimic2v26.icustay_detail icud on icud.hadm_id = pop.hadm_id
join mimic2v26.medevents med on med.icustay_id=pop.icustay_id and med.itemid in (124,118,149,150,308,163,131)
where med.charttime is not null
)

--select * from anes_group_1;

, anes_group_2 as
(select
--hadm_id
icustay_id
, round(extract(day from (end_time-begin_time)) 
    + extract(hour from (end_time-begin_time))/24 + 1/24 -- add additional 1 hour for edge consideration
    + extract(minute from (end_time-begin_time))/60/24, 2) as time_diff_day
, icu_los_day
--, round(extract(day from (icustay_outtime-icustay_intime)) 
--    + extract(hour from (icustay_outtime-icustay_intime))/24 
--    + extract(minute from (icustay_outtime-icustay_intime))/60/24, 2) as temp
, flg
from anes_group_1
)

--select * from anes_group_2;

, anes_group as
(select distinct
icustay_id
, flg
, time_diff_day
, icu_los_day
--, (icu_los_day-time_diff_day)
, case when (icu_los_day-time_diff_day)<0 then 0 else (icu_los_day-time_diff_day) end as anes_free_Day
from anes_group_2
)

--select * from anes_group_final order by 5;

--------------  label anesthetic patients for 1st 12 hours ----------------------------

, anes_12hr_group as
(select distinct icustay_id
, 1 as flg
from anes_group_1
where begin_time <= ICUSTAY_INTIME+12/24
)

--select * from anes_12hr_group; --2016 --2583

------------------------------------- dobutamine medication group -------------------

, dabu_group_1 as
(select 
distinct 
--pop.hadm_id
pop.icustay_id
, pop.icustay_intime
--, pop.icustay_outtime
--, pop.icustay_outtime-pop.icustay_intime as temp
, pop.icu_los_day
, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime asc) as begin_time
--, first_value(med.charttime) over (partition by pop.icustay_id order by med.charttime desc) as end_time
, 1 as flg
from population pop
--join mimic2v26.icustay_detail icud on icud.hadm_id = pop.hadm_id
join mimic2v26.medevents med on med.icustay_id=pop.icustay_id and med.itemid in (306,42)
where med.charttime is not null
)

, dabu_12hr_group as
(select distinct icustay_id
, 1 as flg
from dabu_group_1
where begin_time <= ICUSTAY_INTIME+12/24
)

--select * from dabu_12hr_group; --123
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- commorbidity variables -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
, icd9code as
(select
pop.icustay_id
, pop.hadm_id
, regexp_substr(code,'^\D')                       AS icd9_alpha
, to_number(regexp_substr(code,'\d+$|\d+\.\d+$')) AS icd9_numeric
from population pop
join mimic2v26.icd9 icd on pop.hadm_id=icd.hadm_id
)

--select * from icd9code;

--endocarditis diagnosis group
, endocarditis_group as
(select distinct pop.hadm_id, pop.icustay_id, 1 as flg
from population pop join mimic2v26.icd9 icd on pop.hadm_id=icd.hadm_id
where icd.code in ('036.42','074.22','093.20','093.21','093.22','093.23','093.24','098.84','112.81','115.04','115.14','115.94','391.1','421.0','421.1','421.9','424.90','424.91','424.99')
)

--select count(*) from endocarditis_group; --113
--select adm.subject_id, adm.hadm_id, adm.admit_dt,dpat.dod  from mimic2v26.admissions adm,  mimic2devel.d_patients dpat where adm.subject_id=dpat.subject_id and adm.hadm_id = 9679;

, chf_group as
(select distinct pop.hadm_id,pop.icustay_id,  1 as flg
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93', '428.0', '428.1', '428.20', '428.21', '428.22', '428.23', '428.30', '428.31', '428.32', '428.33', '428.40', '428.41', '428.42', '428.43', '428.9', '428', '428.2', '428.3', '428.4')
order by 1
)
--select * from chf_group; --2518

, afib_group as
(select distinct pop.hadm_id, pop.icustay_id,  1 as flg
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code like '427.3%'
order by 1
)

--select count(*) from population; --6517
--select count(*) from afib_group; --1896

, renal_group as -- end stage or chronic renal disease
(select distinct pop.hadm_id, pop.icustay_id,  1 as flg
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code like '585.%%'
order by 1
)

--select count(*) from renal_group; --539

, liver_group as -- end stage liver disease
(select distinct pop.hadm_id, pop.icustay_id, 1 as flg
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code like '571.%%'
order by 1
)

--select count(*) from liver_group; --478

, copd_group as  --- following definition of PQI5 paper
(select distinct pop.hadm_id, pop.icustay_id,  1 as flg
--, icd9.code
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code in ('466.0', '490', '491.0', '491.1', '491.20', '491.21', '491.8', '491.9', '492.0', '492.8', '494', '494.0', '494.1', '496')
order by 1
)

--select * from copd_group; --1091

, cad_group as -- coronary artery disease
(select distinct pop.hadm_id, pop.icustay_id,  1 as flg
--, icd9.code
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code like '414.%'
order by 1
)

--select * from cad_group; --1289

, stroke_group as
(select distinct pop.hadm_id, pop.icustay_id,  1 as flg
--, icd9.code
--, icd9.code
from population pop
join mimic2v26.icd9 icd9 on icd9.hadm_id=pop.hadm_id
--where icd9.code in ('398.91','402.01','402.91','404.91', '404.13', '404.93','428.0','428.1','428.9')
where icd9.code like '430%%%' or icd9.code like '431%%%' or icd9.code like '432%%%' or icd9.code like '433%%%'  or icd9.code like '434%%%'
order by 1
)

--select * from stroke_group; --616

, malignancy_group as
(select distinct icustay_id
, hadm_id
, 1 as flg
--, icd9_alpha
--, icd9_numeric
from icd9code
where icd9_alpha is null
and icd9_numeric between 140 and 239
)

--select * from malignancy_group; --1865

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- vital signs variables -----------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
----  MAP ----
 , map_group_1 as
 (select pop.icustay_id
 , ch.charttime
 , ch.value1num as bp
 from population pop 
 left join mimic2v26.chartevents ch 
  on pop.icustay_id=ch.icustay_id 
    and ch.itemid in (52,456)
    and ch.charttime <= pop.icustay_intime+12/24
 )
 
 --select * from map_group;
 , map_group as
 (select distinct icustay_id
 , first_value(bp) over (partition by icustay_id order by charttime asc) as map_1st
 , first_value(bp) over (partition by icustay_id order by bp asc) as map_lowest
 , first_value(bp) over (partition by icustay_id order by bp desc) as map_highest
 from map_group_1
 )

--select * from map_group;

-------- Temperature -------------

 , t_group_1 as
 (select pop.icustay_id
 , ch.charttime
 , ch.value1num as temp
 from population pop 
 left join mimic2v26.chartevents ch 
  on pop.icustay_id=ch.icustay_id 
    and ch.itemid in (678,679)
    and ch.charttime <= pop.icustay_intime+12/24
 )
 
 --select * from map_group;
 , t_group as
 (select distinct icustay_id
 , first_value(temp) over (partition by icustay_id order by charttime asc) as temp_1st
 , first_value(temp) over (partition by icustay_id order by temp asc) as temp_lowest
 , first_value(temp) over (partition by icustay_id order by temp desc) as temp_highest
 from t_group_1
 )

--select * from t_group;


-------- HR -------------

 , hr_group_1 as
 (select pop.icustay_id
 , ch.charttime
 , ch.value1num as hr
 from population pop 
 left join mimic2v26.chartevents ch 
  on pop.icustay_id=ch.icustay_id 
    and ch.itemid =211
    and ch.charttime <= pop.icustay_intime+12/24
 )
 
 , hr_group as
 (select distinct icustay_id
 , first_value(hr) over (partition by icustay_id order by charttime asc) as hr_1st
 , first_value(hr) over (partition by icustay_id order by hr asc) as hr_lowest
 , first_value(hr) over (partition by icustay_id order by hr desc) as hr_highest
 from hr_group_1
 )

--select * from hr_group where hr_1st is not null;


-------- HR -------------

 ,cvp_group_1 as
 (select pop.icustay_id
 , ch.charttime
 , ch.value1num as cvp
 from population pop 
 left join mimic2v26.chartevents ch 
  on pop.icustay_id=ch.icustay_id 
    and ch.itemid =113
    and ch.charttime <= pop.icustay_intime+12/24
 )
 
 , cvp_group as
 (select distinct icustay_id
 , first_value(cvp) over (partition by icustay_id order by charttime asc) as cvp_1st
 , first_value(cvp) over (partition by icustay_id order by cvp asc) as cvp_lowest
 , first_value(cvp) over (partition by icustay_id order by cvp desc) as cvp_highest
 from cvp_group_1
 )

--select * from cvp_group where cvp_1st is not null;

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Lab data -------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

--- WBC ---
, lab_wbc_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valuenum as wbc
, case when lab.valuenum between 4.5 and 10 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50316,50468)
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
order by 1
)

--select * from lab_wbc_1;

, lab_wbc as
(select distinct icustay_id
, first_value(wbc) over (partition by hadm_id order by charttime asc) as wbc_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(wbc) over (partition by hadm_id order by wbc asc) as wbc_lowest
, first_value(wbc) over (partition by hadm_id order by wbc desc) as wbc_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) wbc_abnormal_flg
from lab_wbc_1
order by 1
)

--select * from lab_wbc; --6399

--- hemoglobin ----

, lab_hgb_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valuenum as hgb
, case when pop.gender_num=1 and lab.valuenum between 13.8 and 17.2 then 0 
       when pop.gender_num=0 and lab.valuenum between 12.1 and 15.1 then 0 
       --when pop.gender_num is null then null
       else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50386,50007,50184)
  --(50377,50386,50388,50391,50411,50454,50054,50003,50007,50011,50184,50183,50387,50389,50390,50412)
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  and pop.gender_num is not null
order by 1
)

--select * from lab_hgb_1;

, lab_hgb as
(select distinct icustay_id
, first_value(hgb) over (partition by hadm_id order by charttime asc) as hgb_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(hgb) over (partition by hadm_id order by hgb asc) as hgb_lowest
, first_value(hgb) over (partition by hadm_id order by hgb desc) as hgb_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) hgb_abnormal_flg
from lab_hgb_1
order by 1
)

--select * from lab_hgb; --6457

---- platelets ---
, lab_platelet_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.itemid
, lab.valueuom
, lab.valuenum as platelet
, case when lab.valuenum between 150 and 400 then 0 
       else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50428
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)
--select distinct itemid from lab_platelet_1;
--select * from lab_platelet_1;

, lab_platelet as
(select distinct icustay_id
, first_value(platelet) over (partition by hadm_id order by charttime asc) as platelet_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(platelet) over (partition by hadm_id order by platelet asc) as platelet_lowest
, first_value(platelet) over (partition by hadm_id order by platelet desc) as platelet_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) platelet_abnormal_flg
from lab_platelet_1
order by 1
)

--select * from lab_platelet; --6435

--- sodium ---
, lab_sodium_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.itemid
, lab.valueuom
, lab.valuenum as sodium
, case when lab.valuenum between 135 and 145 then 0 
       else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50159, 50012) ---- 50012 is for blood gas
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)
--select distinct itemid from lab_platelet_1;
--select * from lab_sodium_1;

, lab_sodium as
(select distinct icustay_id
, first_value(sodium) over (partition by hadm_id order by charttime asc) as sodium_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(sodium) over (partition by hadm_id order by sodium asc) as sodium_lowest
, first_value(sodium) over (partition by hadm_id order by sodium desc) as sodium_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) sodium_abnormal_flg
from lab_sodium_1
order by 1
)

--select * from lab_sodium; --6356

--- potassium ---
, lab_potassium_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
--, lab.itemid
, lab.valueuom
, lab.valuenum as potassium
, case when lab.valuenum between 3.7 and 5.2 then 0 
       else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50149, 50009) ---- 50009 is from blood gas
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)
--select distinct itemid from lab_platelet_1;
--select * from lab_potassium_1;

, lab_potassium as
(select distinct icustay_id
, first_value(potassium) over (partition by hadm_id order by charttime asc) as potassium_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(potassium) over (partition by hadm_id order by potassium asc) as potassium_lowest
, first_value(potassium) over (partition by hadm_id order by potassium desc) as potassium_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) potassium_abnormal_flg
from lab_potassium_1
order by 1
)

--select * from lab_potassium; --6371

--- bicarbonate ---
, lab_tco2_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
--, lab.itemid
, lab.valueuom
, lab.valuenum as tco2
, case when lab.valuenum between 22 and 28 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50025,50022,50172)--- (50025,50022) are from blood gas
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_tco2_1;

, lab_tco2 as
(select distinct icustay_id
, first_value(tco2) over (partition by hadm_id order by charttime asc) as tco2_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(tco2) over (partition by hadm_id order by tco2 asc) as tco2_lowest
, first_value(tco2) over (partition by hadm_id order by tco2 desc) as tco2_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) tco2_abnormal_flg
from lab_tco2_1
order by 1
)

--select * from lab_tco2; --6400

--- chloride ---
, lab_chloride_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
--, lab.itemid
, lab.valueuom
, lab.valuenum as chloride
, case when lab.valuenum between 96 and 106 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid in (50083,50004) --- 50004 is from blood gas
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_chloride_1;

, lab_chloride as
(select distinct icustay_id
, first_value(chloride) over (partition by hadm_id order by charttime asc) as chloride_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(chloride) over (partition by hadm_id order by chloride asc) as chloride_lowest
, first_value(chloride) over (partition by hadm_id order by chloride desc) as chloride_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) chloride_abnormal_flg
from lab_chloride_1
order by 1
)

--select * from lab_chloride; --6400

--- bun ---
, lab_bun_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
--, lab.itemid
, lab.valueuom
, lab.valuenum as bun
, case when lab.valuenum between 6 and 20 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50177 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_bun_1;

, lab_bun as
(select distinct icustay_id
, first_value(bun) over (partition by hadm_id order by charttime asc) as bun_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(bun) over (partition by hadm_id order by bun asc) as bun_lowest
, first_value(bun) over (partition by hadm_id order by bun desc) as bun_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) bun_abnormal_flg
from lab_bun_1
order by 1
)

--select * from lab_bun; --6438

--- creatinine ---
, lab_creatinine_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valueuom
, lab.valuenum as creatinine
, case when pop.gender_num=1 and lab.valuenum <= 1.3 then 0 
       when pop.gender_num=0 and lab.valuenum <= 1.1 then 0 
        else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50090 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  and pop.gender_num is not null
order by 1
)

--select * from lab_creatinine_1;

, lab_creatinine as
(select distinct icustay_id
, first_value(creatinine) over (partition by hadm_id order by charttime asc) as creatinine_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(creatinine) over (partition by hadm_id order by creatinine asc) as creatinine_lowest
, first_value(creatinine) over (partition by hadm_id order by creatinine desc) as creatinine_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) creatinine_abnormal_flg
from lab_creatinine_1
order by 1
)

--select * from lab_creatinine; --6439


--- Lactate ---
, lab_lactate_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valueuom
, lab.valuenum as lactate
, case when lab.valuenum between 0.5 and 2.2 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid =50010 -- 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_lactate_1;

, lab_lactate as
(select distinct icustay_id
, first_value(lactate) over (partition by hadm_id order by charttime asc) as lactate_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(lactate) over (partition by hadm_id order by lactate asc) as lactate_lowest
, first_value(lactate) over (partition by hadm_id order by lactate desc) as lactate_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) lactate_abnormal_flg
from lab_lactate_1
order by 1
)

--select * from lab_lactate; --4455

--- PH ---
, lab_ph_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valueuom
, lab.valuenum as ph
, case when lab.valuenum between 7.38 and 7.42 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50018 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_ph_1;

, lab_ph as
(select distinct icustay_id
, first_value(ph) over (partition by hadm_id order by charttime asc) as ph_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(ph) over (partition by hadm_id order by ph asc) as ph_lowest
, first_value(ph) over (partition by hadm_id order by ph desc) as ph_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) ph_abnormal_flg
from lab_ph_1
order by 1
)
--select * from lab_ph; --5054

--- po2 ---
, lab_po2_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valueuom
, lab.valuenum as po2
, case when lab.valuenum between 75 and 100 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50019 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_po2_1;

, lab_po2 as
(select distinct icustay_id
, first_value(po2) over (partition by hadm_id order by charttime asc) as po2_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(po2) over (partition by hadm_id order by po2 asc) as po2_lowest
, first_value(po2) over (partition by hadm_id order by po2 desc) as po2_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) po2_abnormal_flg
from lab_po2_1
order by 1
)

--select * from lab_po2; --4948

--- paco2 ---
, lab_pco2_1 as
(select pop.hadm_id
, pop.icustay_id
, pop.ICUSTAY_INTIME
, lab.charttime
, lab.valueuom
, lab.valuenum as pco2
, case when lab.valuenum between 35 and 45 then 0 else 1 end as abnormal_flg
from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
join mimic2v26.labevents lab 
  on pop.hadm_id=lab.hadm_id 
  and lab.itemid = 50016 
  and lab.valuenum is not null
  and lab.charttime<=pop.ICUSTAY_INTIME+12/24
  --and pop.gender_num is not null
order by 1
)

--select * from lab_pco2_1;

, lab_pco2 as
(select distinct icustay_id
, first_value(pco2) over (partition by hadm_id order by charttime asc) as pco2_first
--, first_value(abnormal_flg) over (partition by hadm_id order by chartime asc) as wbs_first_abn_flg
, first_value(pco2) over (partition by hadm_id order by pco2 asc) as pco2_lowest
, first_value(pco2) over (partition by hadm_id order by pco2 desc) as pco2_highest
, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) pco2_abnormal_flg
from lab_pco2_1
order by 1
)

--select * from lab_pco2; --4946



----- SVO2 ---
--, lab_svo2_1 as
--(select pop.hadm_id
--, icud.ICUSTAY_INTIME
--, ch.charttime
--, ch.value1num as svo2
--, case when ch.value1num between 60 and 80 then 0 else 1 end as abnormal_flg
--from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id and ICUSTAY_SEQ =1
--join mimic2v26.chartevents ch 
--  on icud.icustay_id=ch.icustay_id 
--  and ch.itemid in (664,838)
--  and ch.value1num is not null
--  and ch.charttime<=icud.ICUSTAY_INTIME+12/24
--order by 1
--)
--
----select * from lab_svo2_1;
--
--, lab_svo2 as
--(select distinct hadm_id
--, first_value(svo2) over (partition by hadm_id order by svo2 asc) as svo2_lowest
--, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) as abnormal_flg
--from lab_svo2_1
--order by 1
--)
--
----select * from lab_svo2; --471 (not to be included)

----- BNP --- should be excluded
--, lab_bnp_1 as
--(select pop.hadm_id
--, icud.ICUSTAY_INTIME
--, lab.charttime
--, lab.valuenum as bnp
--, case when lab.valuenum <= 100 then 0
--        else 1 end as abnormal_flg
--from population pop
--join mimic2v26.icustay_detail icud 
--  on pop.hadm_id=icud.hadm_id 
--  and icud.ICUSTAY_SEQ =1 
----  and icud.gender is not null
--join mimic2v26.labevents lab 
--  on pop.hadm_id=lab.hadm_id 
--  and lab.itemid in (50195)
--  and lab.valuenum is not null
--  and lab.charttime<=icud.ICUSTAY_INTIME+12/24
--order by 1
--)
--
----select * from lab_bnp_1;
--
--, lab_bnp as
--(select distinct hadm_id
--, first_value(bnp) over (partition by hadm_id order by bnp desc) as bnp_highest
--, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) as abnormal_flg
--from lab_bnp_1
--order by 1
--)
--
----select * from lab_bnp; --346 

----- Troponin T--- 
--, lab_troponin_1 as
--(select pop.hadm_id
--, icud.ICUSTAY_INTIME
--, lab.charttime
--, lab.valuenum as troponin
--, case when lab.valuenum <= 0.1 then 0
--        else 1 end as abnormal_flg
--from population pop
--join mimic2v26.icustay_detail icud 
--  on pop.hadm_id=icud.hadm_id 
--  and icud.ICUSTAY_SEQ =1 
----  and icud.gender is not null
--join mimic2v26.labevents lab 
--  on pop.hadm_id=lab.hadm_id 
--  and lab.itemid in (50189)
--  and lab.valuenum is not null
--  and lab.charttime<=icud.ICUSTAY_INTIME+12/24
--order by 1
--)
--
----select * from lab_troponin_1;
--
--, lab_troponin_t as
--(select distinct hadm_id
--, first_value(troponin) over (partition by hadm_id order by troponin desc) as troponin_t_highest
--, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) as abnormal_flg
--from lab_troponin_1
--order by 1
--)
--
----select * from lab_troponin_t; --2124
--
----- Troponin I--- 
--, lab_troponin_i_1 as
--(select pop.hadm_id
--, icud.ICUSTAY_INTIME
--, lab.charttime
--, lab.valuenum as troponin
--, case when lab.valuenum <= 10 then 0
--        else 1 end as abnormal_flg
--from population pop
--join mimic2v26.icustay_detail icud 
--  on pop.hadm_id=icud.hadm_id 
--  and icud.ICUSTAY_SEQ =1 
----  and icud.gender is not null
--join mimic2v26.labevents lab 
--  on pop.hadm_id=lab.hadm_id 
--  and lab.itemid in (50188)
--  and lab.valuenum is not null
--  and lab.charttime<=icud.ICUSTAY_INTIME+12/24
--order by 1
--)
--
----select * from lab_troponin_1;
--
--, lab_troponin_i as
--(select distinct hadm_id
--, first_value(troponin) over (partition by hadm_id order by troponin desc) as troponin_i_highest
--, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) as abnormal_flg
--from lab_troponin_i_1
--order by 1
--)
--
----select distinct hadm_id from (
----select * from lab_troponin_i
----union
----select * from lab_troponin_t); --2552
--
----- CK test--- 
--, lab_ck_1 as
--(select pop.hadm_id
--, icud.ICUSTAY_INTIME
--, lab.charttime
--, lab.valuenum as ck
--, case when lab.valuenum <= 120 then 0
--        else 1 end as abnormal_flg
--from population pop
--join mimic2v26.icustay_detail icud 
--  on pop.hadm_id=icud.hadm_id 
--  and icud.ICUSTAY_SEQ =1 
----  and icud.gender is not null
--join mimic2v26.labevents lab 
--  on pop.hadm_id=lab.hadm_id 
--  and lab.itemid in (50087)
--  and lab.valuenum is not null
--  and lab.charttime<=icud.ICUSTAY_INTIME+12/24
--order by 1
--)
--
----select * from lab_ck_1;
--
--, lab_ck as
--(select distinct hadm_id
--, first_value(ck) over (partition by hadm_id order by ck desc) as ck_highest
--, first_value(abnormal_flg) over (partition by hadm_id order by abnormal_flg desc) as abnormal_flg
--from lab_ck_1
--order by 1
--)
--
----select * from lab_ck; --2948

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- fluids data -------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

, total_fluid_in_1st as
(select distinct pop.icustay_id
--, tb.charttime
, first_value(tb.CUMVOLUME) over (partition by pop.icustay_id order by tb.charttime asc) as total_fluid_1st
from population pop
join mimic2v26.totalbalevents tb on tb.icustay_id=pop.icustay_id and tb.itemid=1
where tb.cumvolume>100
order by 1
)
--select * from total_fluid_in_1st;

, total_fluid_in_1 as
(select distinct pop.icustay_id
--, pop.hadm_id
--, pop.icustay_intime
--, pop.icustay_outtime
--, count(distinct tb.charttime) as count
, tb.charttime
, tb.CUMVOLUME
from population pop
join mimic2v26.totalbalevents tb on tb.icustay_id=pop.icustay_id and tb.itemid=1 
--and tb.charttime between pop.icustay_intime-1 and pop.icustay_outtime+1
--group by pop.icustay_id
)

--select * from total_fluid_in_1 order by 1; -- 2212
, total_fluid_count as
(select icustay_id
, count(distinct charttime) as count
from total_fluid_in_1
group by icustay_id
)

--select * from total_fluid_count;
, total_fluid as
(select icustay_id
, sum(cumvolume) as totalvolume
from total_fluid_in_1
group by icustay_id
)
--select * from total_fluid;

, normalized_fluid_in as
(select distinct t.icustay_id
, round(t.totalvolume/c.count, 2) as fluid_per_day
--, c.count
from total_fluid t
join total_fluid_count c on t.icustay_id=c.icustay_id
)

--select * from normalized_fluid_in;

----------- extract total fluid ---------------
--, total_fluid_in_24_echo as
--(select distinct pop.hadm_id
----, icud.icustay_id
----, icud.HOSPITAL_ADMIT_DT
----, icud.HOSPITAL_DISCH_DT
----, icud.icustay_intime
----, icud.icustay_outtime
----, tb.CHARTTIME
----, tb.CUMVOLUME
--, first_value(tb.CUMVOLUME) over (partition by pop.hadm_id order by tb.charttime asc) as fluid_24hr
----, tb.ACCUMPERIOD
----, echo.flg
----, echo.echo_time
--from population pop
----join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id
--join mimic2v26.totalbalevents tb on tb.icustay_id=icud.icustay_id and tb.itemid=1 
--and icud.icustay_outtime>=tb.charttime+1
--and tb.charttime>=icud.icustay_intime+1
--join echo_group echo on pop.hadm_id=echo.hadm_id and tb.charttime>=echo.echo_time
--)
--
----select * from total_fluid_in_24_echo order by 1; -- 2212
--
--, total_fluid_in_24_noecho as
--(select distinct pop.hadm_id
----, icud.icustay_id
----, icud.HOSPITAL_ADMIT_DT
----, icud.HOSPITAL_DISCH_DT
----, tb.CHARTTIME
----, icud.icustay_intime
----, icud.icustay_outtime
----, tb.CUMVOLUME
--, first_value(tb.CUMVOLUME) over (partition by pop.hadm_id order by tb.charttime asc) as fluid_24hr
----, tb.ACCUMPERIOD
--from population pop
--join mimic2v26.icustay_detail icud on pop.hadm_id=icud.hadm_id
--join mimic2v26.totalbalevents tb on tb.icustay_id=icud.icustay_id 
--  and tb.itemid=1 
--  and tb.charttime>=icud.icustay_intime+1
--  and icud.icustay_outtime>=tb.charttime+1
--)
--
----select * from total_fluid_in_24_noecho order by 1; --4511
--
--, total_fluid_in as
--(select distinct pop.hadm_id
--, case when pop.hadm_id in (select hadm_id from echo_group_final) then e.fluid_24hr else ne.fluid_24hr  end as fluid_24hr
--from population pop
--left join total_fluid_in_24_echo e on pop.hadm_id=e.hadm_id
--left join total_fluid_in_24_noecho ne on pop.hadm_id=ne.hadm_id
--)
--
----select * from total_fluid_in order by 1;
--
----, total_fluid_in as
----(select distinct hadm_id
----, count(distinct charttime) as cnt
----, sum(cumvolume) as total_vol
----, round(sum(cumvolume)/count(distinct charttime),2) as vol_per_day
----from total_fluid_in_1
----group by hadm_id)

--select * from total_fluid_in;

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Raw data -------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------


, echo_data as
(select distinct
pop.*

, coalesce(vent.flg,0) as vent_flg
, case when vent.vent_free_day is null then pop.icu_los_day else vent.vent_free_day  end as vent_free_day
, coalesce(vent12.flg,0) as vent_12hr_flg
, coalesce(vaso.flg,0) as vaso_flg
, case when vaso.vaso_free_day is null then pop.icu_los_day else vaso.vaso_free_day  end as vaso_free_day
, coalesce(vaso12.flg,0) as vaso_12hr_flg
, coalesce(anes.flg,0) as anes_flg
, case when anes.anes_free_day is null then pop.icu_los_day else anes.anes_free_day  end as anes_free_day
, coalesce(anes12.flg,0) as anes_12hr_flg

, coalesce(chf.flg,0) as chf_flg
, coalesce(afib.flg,0) as afib_flg
, coalesce(renal.flg,0) as renal_flg
, coalesce(liver.flg,0) as liver_flg
, coalesce(copd.flg,0) as copd_flg
, coalesce(cad.flg,0) as cad_flg
, coalesce(stroke.flg,0) as stroke_flg
, coalesce(mal.flg,0) as mal_flg

, m.map_1st
, m.map_lowest
, m.map_highest
, hr.hr_1st
, hr.hr_lowest
, hr.hr_highest
, t.temp_1st
, t.temp_lowest
, t.temp_highest
--, cvp.cvp_1st
--, cvp.cvp_lowest
--, cvp.cvp_highest

, wbc.wbc_first
, wbc.wbc_lowest
, wbc.wbc_highest
, wbc.wbc_abnormal_flg
, hgb.hgb_first
, hgb.hgb_lowest
, hgb.hgb_highest
, hgb.hgb_abnormal_flg
, platelet.platelet_first
, platelet.platelet_lowest
, platelet.platelet_highest
, platelet.platelet_abnormal_flg
, sodium.sodium_first
, sodium.sodium_lowest
, sodium.sodium_highest
, sodium.sodium_abnormal_flg
, potassium.potassium_first
, potassium.potassium_lowest
, potassium.potassium_highest
, potassium.potassium_abnormal_flg
, tco2.tco2_first
, tco2.tco2_lowest
, tco2.tco2_highest
, tco2.tco2_abnormal_flg
, chloride.chloride_first
, chloride.chloride_lowest
, chloride.chloride_highest
, chloride.chloride_abnormal_flg
, bun.bun_first
, bun.bun_lowest
, bun.bun_highest
, bun.bun_abnormal_flg
, lactate.lactate_first
, lactate.lactate_lowest
, lactate.lactate_highest
, lactate.lactate_abnormal_flg
, creatinine.creatinine_first
, creatinine.creatinine_lowest
, creatinine.creatinine_highest
, creatinine.creatinine_abnormal_flg
, ph.ph_first
, ph.ph_lowest
, ph.ph_highest
, ph.ph_abnormal_flg
, po2.po2_first
, po2.po2_lowest
, po2.po2_highest
, po2.po2_abnormal_flg
, pco2.pco2_first
, pco2.pco2_lowest
, pco2.pco2_highest
, pco2.pco2_abnormal_flg

, f1.total_fluid_1st
, nf.fluid_per_day

from population pop
left join vent_group vent on vent.icustay_id=pop.icustay_id
left join vent_12hr_group vent12 on vent12.icustay_id=pop.icustay_id
left join vaso_group vaso on vaso.icustay_id=pop.icustay_id
left join vaso_12hr_group vaso12 on vaso12.icustay_id=pop.icustay_id
left join anes_group anes on anes.icustay_id=pop.icustay_id
left join anes_12hr_group anes12 on anes12.icustay_id=pop.icustay_id

left join chf_group chf on chf.hadm_id=pop.hadm_id
left join afib_group afib on afib.hadm_id=pop.hadm_id
left join renal_group renal on renal.hadm_id=pop.hadm_id
left join liver_group liver on liver.hadm_id=pop.hadm_id
left join copd_group copd on copd.hadm_id=pop.hadm_id
left join cad_group cad on cad.hadm_id=pop.hadm_id
left join stroke_group stroke on stroke.hadm_id=pop.hadm_id
left join malignancy_group mal on mal.hadm_id=pop.hadm_id

left join map_group m on m.icustay_id=pop.icustay_id
left join hr_group hr on hr.icustay_id=pop.icustay_id
left join t_group t on t.icustay_id=pop.icustay_id
--left join cvp_group cvp on cvp.icustay_id=pop.icustay_id

left join lab_wbc wbc on wbc.icustay_id=pop.icustay_id
left join lab_hgb hgb on hgb.icustay_id=pop.icustay_id
left join lab_platelet platelet on platelet.icustay_id=pop.icustay_id
left join lab_sodium sodium on sodium.icustay_id=pop.icustay_id
left join lab_potassium potassium on potassium.icustay_id=pop.icustay_id
left join lab_tco2 tco2 on tco2.icustay_id=pop.icustay_id
left join lab_chloride chloride on chloride.icustay_id=pop.icustay_id
left join lab_bun bun on bun.icustay_id=pop.icustay_id
left join lab_creatinine creatinine on creatinine.icustay_id=pop.icustay_id
left join lab_lactate lactate on lactate.icustay_id=pop.icustay_id
left join lab_ph ph on ph.icustay_id=pop.icustay_id
left join lab_po2 po2 on po2.icustay_id=pop.icustay_id
left join lab_pco2 pco2 on pco2.icustay_id=pop.icustay_id

left join total_fluid_in_1st f1 on f1.icustay_id=pop.icustay_id
left join normalized_fluid_in nf on nf.icustay_id=pop.icustay_id
)

select * from echo_data;


--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- Clean version of the data -------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
drop table echo_sepsis_clean_dec13;
create table echo_sepsis_clean_dec13 as
select
SUBJECT_ID
,HADM_ID
,ICU_LOS_DAY
,HOSPITAL_LOS_DAY
,AGE
,HOSP_EXP_FLG
,GENDER_MALE
,WEIGHT
,SAPS
,SOFA
,TWENTY_EIGHT_DAY_MORT_PT
,ONE_YR_MORT_PT
,ONE_YEAR_SURVIVAL_PT 
,VENT_FLG
,VENT_TIME_DAY
,VASO_FLG
,VASO_TIME_DAY
,VENT_12HR_FLG
,VASO_12HR_FLG
,DOBUTAMINE_FLG
,ENDOCARDITIS_FLG
,CHF_FLG
,AFIB_FLG
,RENAL_FLG
,LIVER_FLG
,COPD_FLG
,CAD_FLG
,STROKE_FLG
,WBC_HIGHEST
,WBC_FLG
,LACTATE_HIGHEST
,LAC_FLG
,PH_LOWEST
,PH_FLG
,PO2_LOWEST
,PO2_FLG
,CREATININE_HIGHEST
,CR_FLG
,TCO2_LOWEST
,TCO2_FLG
,CK_HIGHEST
,CK_FLG
,SERVICE_UNIT
,SERVICE_NUM
,FLUID_24HR
,DAY_28_FLG
,DAY_365_FLG
,DAY_365_CENSOR
,SURVIVE_DAY
,ECHO_FLG
,ECHO_TIME_DAY
--,ECHO_1DAY_FLG
--,ECHO_2DAY_FLG
from mornin.echo_sepsis_raw_dec13
where SUBJECT_ID is not null
and HADM_ID is not null
and ICU_LOS_DAY is not null
and HOSPITAL_LOS_DAY is not null
and AGE is not null
and HOSP_EXP_FLG is not null
and GENDER_MALE is not null
and WEIGHT is not null
and SAPS is not null
and SOFA is not null
and TWENTY_EIGHT_DAY_MORT_PT is not null
and ONE_YR_MORT_PT is not null
and ONE_YEAR_SURVIVAL_PT is not null

and VENT_FLG is not null
--and VENT_TIME_DAY is not null
and VASO_FLG is not null
--and VASO_TIME_DAY is not null
and VENT_12HR_FLG is not null
and VASO_12HR_FLG is not null

and DOBUTAMINE_FLG is not null
and ENDOCARDITIS_FLG is not null
and CHF_FLG is not null
and AFIB_FLG is not null
and RENAL_FLG is not null
and LIVER_FLG is not null
and COPD_FLG is not null
and CAD_FLG is not null
and STROKE_FLG is not null

and WBC_HIGHEST is not null
and WBC_FLG is not null
--and LACTATE_HIGHEST is not null
--and LAC_FLG is not null
and PH_LOWEST is not null
and PH_FLG is not null
and PO2_LOWEST is not null
and PO2_FLG is not null
and CREATININE_HIGHEST is not null
and CR_FLG is not null
and TCO2_LOWEST is not null
and TCO2_FLG is not null
--and CK_HIGHEST is not null --exclude
--and CK_FLG is not null

and SERVICE_UNIT is not null
and SERVICE_NUM is not null
----and FLUID_24HR is not null
and DAY_28_FLG is not null
and DAY_365_FLG is not null
and DAY_365_CENSOR is not null
and SURVIVE_DAY is not null
and ECHO_FLG is not null
--and ECHO_TIME_DAY is not null
--and ECHO_1DAY_FLG is not null
--and ECHO_2DAY_FLG is not null;
;
 


--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------- PS score matching  -------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------


select hadm_id, echo_flg
from echo_ps_dec13
where echo_flg=1 and weight is not null;

select hadm_id
from echo_ps_dec13
where echo_flg=0 and weight is not null;







