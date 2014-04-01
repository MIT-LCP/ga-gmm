--created by mpimentel, GA-GMM project 
-- Last Updated: August 2013

-- drop materialized view physiological_variables;
create materialized view physiological_variables as

with cohort as (
  select cd.icustay_id
  , ca.*
  , cd.icustay_intime
  from TBRENNAN.angus_sepsis_cohort ca
  left join MIMIC2V26.icustay_detail cd
    on cd.subject_id=ca.subject_id
    and cd.hadm_id=ca.hadm_id
)
--select * from cohort order by 1;

-- Datatype:
-- 1 - NBP Systolic, 2 - NBP Diastolic, 3 - NBP MAP, 4 - NBP PP
-- 5 - IBP Systolic, 6 - IBP Diastolic, 7 - IBP MAP, 8 - IBP PP
-- 9 - HR, 10 - Central Venous Pressure (CVP), 11 - SpO2, 12 - RR  
-- 13 - urine output, 14 - temperature

, sysbp as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime
         , extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) as min_post_adm
         , ce.value1num val
         , ce.value1uom unit
         , '1' datatype
    from mimic2v26.chartevents ce 
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (442, 455) --noninvasive (442, 455) & invasive blood pressure (51)
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
)
--select count(distinct icustay_id) from sysbp; -- 29785

, diabp as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value2num val,
          ce.value2uom unit,
          '2' datatype
    from mimic2v26.chartevents ce 
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (442,455) --noninvasive & invasive blood pressure
      and ce.value2num <> 0
      and ce.value2num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select count(distinct icustay_id) from diabp; --29780

-- get mean arterial blood pressure blood prssure
, mbp as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '3' datatype
    from mimic2v26.chartevents ce 
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where itemid in (443, 456) -- invasive (52, 224)
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select count(distinct icustay_id) from mbp; --29765

, pulsep as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num - ce.value2num val,
          ce.value1uom unit,
          '4' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (442,455) --noninvasive & invasive blood pressure
      and ce.value1num <> 0
      and ce.value1num is not null
      and ce.value2num <> 0
      and ce.value2num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4

)
--select * from pulsep;

, sysibp as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val,
          ce.value1uom unit,
          '5' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51) --invasive blood pressure (51)
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from sysibp order by 5;

, diaibp as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value2num val,
          ce.value2uom unit,
          '6' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51) --invasive blood pressure
      and ce.value2num <> 0
      and ce.value2num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from diaibp;

-- get mean arterial blood pressure blood prssure
, mibp as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '7' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where itemid in (52) -- invasive
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from mibp order by 5;

, pulsepi as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
         extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
         ce.value1num - ce.value2num val,
         ce.value1uom unit,
         '8' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51) --invasive blood pressure
      and ce.value1num <> 0
      and ce.value1num is not null
      and ce.value2num <> 0
      and ce.value2num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from pulsepi;

-- get heart rate for icustay
, hr as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '9' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid = 211 --heart rate
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from hr;

-- get central venous pressure for icustay
, cvp as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '10' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (113, 1103) --cvp
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from cvp;

-- get peripheral oxygen saturation for icustay
, spo2 as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '11' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (646, 834) -- spo2
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from spo2;

-- get respiration/breathing rate for icustay
, br as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '12' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (614, 615, 618, 1635, 1884, 3603, 3337) 
      -- resp. rate (1635 only appears for one patient; 
      --             1884 values are crazy and only appears for 2 or 3 patients)
      --             3603 values look somehow elevated (check if it corresponds to neonates)
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from br;

, urine_output as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.volume val, 
          ce.volumeuom unit,
          '13' datatype
    from mimic2v26.ioevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (651, 715, 55, 56, 57, 61, 65, 69, 85, 94, 96, 288, 405,
                       428, 473, 2042, 2068, 2111, 2119, 2130, 1922, 2810, 2859,
                       3053, 3462, 3519, 3175, 2366, 2463, 2507, 2510, 2592,
                       2676, 3966, 3987, 4132, 4253, 5927)              
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
      and volume is not null
      order by subject_id, icustay_id, min_post_adm
)
--select * from urine_output;

-- get temperature for icustay (NOT CONVERTED)
, temp as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) min_post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '14' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (676, 677, 678, 679) -- temperature
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, min_post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 4
)
--select * from temp;

-- finally, assemble
  select * from sysbp 
  union
  select * from diabp
  union
  select * from mbp
  union 
  select * from pulsep
  union 
  select * from sysibp 
  union
  select * from diaibp
  union
  select * from mibp
  union 
  select * from pulsepi
  union
  select * from hr 
  union 
  select * from cvp
  union 
  select * from spo2
  union 
  select * from br 
  union 
  select * from urine_output
  union 
  select * from temp;