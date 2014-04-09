--created by mpimentel, GA-GMM project 
-- Last Updated: August 2013

drop materialized view mimic2v26_24hr_vital_signs;

create materialized view mimic2v26_24hr_vital_signs as

with cohort as (
  select 
    subject_id, 
    hadm_id,
    icustay_id,
    icustay_seq,
    icustay_intime,
    weight_first weight,
    sapsi_first sapsi
  from MIMIC2V26.icustay_detail cd
    where icustay_los > 24*60
      and hadm_id is not null
      and icustay_id is not null
      and weight_first is not null
      and sapsi_first is not null
)
--select * from cohort order by subject_id; --19,550 rows

-- Datatype:
-- 1 - NBP Systolic, 2 - NBP Diastolic, 3 - NBP MAP, 4 - NBP PP
-- 5 - IBP Systolic, 6 - IBP Diastolic, 7 - IBP MAP, 8 - IBP PP
-- 9 - HR, 10 - Central Venous Pressure (CVP), 11 - SpO2, 12 - RR  
-- 13 - urine output, 14 - temperature

, sysbp_raw as (
  select fc.subject_id
         , fc.hadm_id
         , fc.icustay_id
         , fc.icustay_intime
         , extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) as post_adm
         , ce.value1num val
         , ce.value1uom unit
         , '1' datatype
    from mimic2v26.chartevents ce 
    join cohort fc on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51, 442, 455) --noninvasive (442, 455) & invasive blood pressure (51)
      and ce.value1num <> 0
      and ce.value1num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select * from sysbp; -- 29785

, sysbp as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) sysbp_med,
        round(min(val) over (partition by icustay_id),2) sysbp_max,
        round(max(val) over (partition by icustay_id),2) sysbp_min,
        round(stddev(val) over (partition by icustay_id),2) sysbp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) sysbp_slp
        from sysbp_raw 
)
--select * from sysbp;

, diabp_raw as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value2num val,
          ce.value2uom unit,
          '2' datatype
    from mimic2v26.chartevents ce 
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51, 442,455) --noninvasive & invasive blood pressure
      and ce.value2num <> 0
      and ce.value2num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select count(distinct icustay_id) from diabp_raw; --29780

, diabp as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) diabp_med,
        round(min(val) over (partition by icustay_id),2) diabp_min,
        round(max(val) over (partition by icustay_id),2) diabp_max,
        round(stddev(val) over (partition by icustay_id),2) diabp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) diabp_slp
        from diabp_raw 
)
--select count(*) from diabp where diabp = 0;

-- get mean arterial blood pressure blood prssure
, mbp_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '3' datatype
    from mimic2v26.chartevents ce 
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where itemid in (52, 224, 443, 456) -- invasive (52, 224)
      and ce.value1num <> 0
      and ce.value1num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select count(distinct icustay_id) from mbp_raw; --29765

, mbp as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) mbp_med,
        round(min(val) over (partition by icustay_id),2) mbp_min,
        round(max(val) over (partition by icustay_id),2) mbp_max,
        round(stddev(val) over (partition by icustay_id),2) mbp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) mbp_slp
        from mbp_raw 
)
--select count(*) from mbp where mbp = 0;

, pulsep_raw as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num - ce.value2num val,
          ce.value1uom unit,
          '4' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
      on ce.icustay_id = fc.icustay_id
      where ce.itemid in (51,442,455) --noninvasive & invasive blood pressure
      and ce.value1num <> 0
      and ce.value1num is not null
      and ce.value2num <> 0
      and ce.value2num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm

)
--select * from pulsep_raw;

, pulsep as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) pp_med,
        round(min(val) over (partition by icustay_id),2) pp_min,
        round(max(val) over (partition by icustay_id),2) pp_max,
        round(stddev(val) over (partition by icustay_id),2) pp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) pp_slp
        from pulsep_raw 
)
--select * from pulsep;


-- get heart rate for icustay
, hr_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '9' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid = 211 --heart rate
      and ce.value1num <> 0
      and ce.value1num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select * from hr_raw;

, hr as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) hr_med,
        round(min(val) over (partition by icustay_id),2) hr_min,
        round(max(val) over (partition by icustay_id),2) hr_max,
        round(stddev(val) over (partition by icustay_id),2) hr_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) hr_slp
        from hr_raw 
)
--select count(*) from hr where hr = 0;

-- get central venous pressure for icustay
, cvp_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '10' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (113, 1103) --cvp
      and ce.value1num <> 0
      and ce.value1num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select * from cvp;

, cvp as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) cvp_med,
        round(min(val) over (partition by icustay_id),2) cvp_min,
        round(max(val) over (partition by icustay_id),2) cvp_max,
        round(stddev(val) over (partition by icustay_id),2) cvp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) cvp_slp
        from hr_raw 
)
--select count(*) missing_cvp from cvp where cvp = 0; --32


-- get peripheral oxygen saturation for icustay
, spo2_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '11' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (646, 834) -- spo2
      and ce.value1num <> 0
      and ce.value1num is not null
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select * from spo2_raw;

, spo2 as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) spo2_med,
        round(min(val) over (partition by icustay_id),2) spo2_min,
        round(max(val) over (partition by icustay_id),2) spo2_max,
        round(stddev(val) over (partition by icustay_id),2) spo2_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) spo2_slp
        from hr_raw 
)
--select count(*) missing_spo2 from spo2 where spo2 = 0; --32


-- get respiration/breathing rate for icustay
, br_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
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
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      order by subject_id, icustay_id, post_adm
)
--select * from br_raw;

, br as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) br_med,
        round(min(val) over (partition by icustay_id),2) br_min,
        round(max(val) over (partition by icustay_id),2) br_max,
        round(stddev(val) over (partition by icustay_id),2) br_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) br_slp
        from br_raw 
)
--select count(*) missing_br from br where br = 0; --37


, urine_output_raw as (
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
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
      and extract(day from ce.charttime - fc.icustay_intime) < 1
      and volume is not null
      order by subject_id, icustay_id, post_adm
)
--select * from urine_output_raw;

, urine_output as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) uo_med,
        round(min(val) over (partition by icustay_id),2) uo_min,
        round(max(val) over (partition by icustay_id),2) uo_max,
        round(stddev(val) over (partition by icustay_id),2) uo_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) uo_slp
        from urine_output_raw 
)
--select count(*) missing_uo from urine_output where uo = 0; --234


-- get temperature for icustay (NOT CONVERTED)
, temp_raw as ( 
  select fc.subject_id
         , fc.icustay_id
         , fc.hadm_id
         , fc.icustay_intime,
          extract(day from ce.charttime - fc.icustay_intime)*1440 + extract(hour from ce.charttime - fc.icustay_intime)*60 + extract(minute from ce.charttime - fc.icustay_intime) post_adm, 
          ce.value1num val, 
          ce.value1uom unit,
          '14' datatype
    from mimic2v26.chartevents ce
    join cohort fc 
    on ce.icustay_id = fc.icustay_id
      where itemid in (676, 677, 678, 679) -- temperature
      and ce.value1num <> 0
      and ce.value1num is not null
      order by subject_id, icustay_id, post_adm
      --and extract(day from ce.charttime - fc.icustay_intime) < 1
)
--select * from temp_raw;

, temp as (
  select distinct 
        subject_id,
        hadm_id,
        icustay_id,
        round(median(val) over (partition by icustay_id),2) temp_med,
        round(min(val) over (partition by icustay_id),2) temp_min,
        round(max(val) over (partition by icustay_id),2) temp_max,
        round(stddev(val) over (partition by icustay_id),2) temp_std,
        round(regr_slope(post_adm,val) over (partition by icustay_id),2) temp_slp
        from temp_raw 
)
--select count(*) missing_temp from temp where temp = 0; --234

/*

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
  
  */
  
, final as (
  select distinct
        fc.*,
        sbp.sysbp_med,
        sbp.sysbp_min,
        sbp.sysbp_std,
        sbp.sysbp_slp,
        
        dbp.diabp_med,
        dbp.diabp_min,
        dbp.diabp_std,
        dbp.diabp_slp,
        
        mbp.mbp_med,
        mbp.mbp_min,
        mbp.mbp_std,
        mbp.mbp_slp,
        
        pp.pp_med,
        pp.pp_min,
        pp.pp_std,
        pp.pp_slp,
        
        hr.hr_med,
        hr.hr_min,
        hr.hr_std,
        hr.hr_slp,
        
        cvp.cvp_med,
        cvp.cvp_min,
        cvp.cvp_std,
        cvp.cvp_slp,
        
        spo2.spo2_med,
        spo2.spo2_min,
        spo2.spo2_std,
        spo2.spo2_slp,

        br.br_med,
        br.br_min,
        br.br_std,
        br.br_slp,
        
        uo.uo_med,
        uo.uo_min,
        uo.uo_std,
        uo.uo_slp,
        
        t.temp_med,
        t.temp_min,
        t.temp_std,
        t.temp_slp
        
  from cohort fc
  join sysbp sbp on fc.icustay_id = sbp.icustay_id and sbp.sysbp_std <> 0
  join diabp dbp on fc.icustay_id = dbp.icustay_id and dbp.diabp_std <> 0
  join mbp on fc.icustay_id = mbp.icustay_id and mbp.mbp_std <> 0
  join pulsep pp on fc.icustay_id = pp.icustay_id and pp.pp_std <> 0
  join hr on fc.icustay_id = hr.icustay_id and hr.hr_std <> 0
  join cvp on fc.icustay_id = cvp.icustay_id and cvp.cvp_std <> 0
  join spo2 on fc.icustay_id = spo2.icustay_id and spo2.spo2_std <> 0
  join br on fc.icustay_id = br.icustay_id and br.br_std <> 0
  join urine_output uo on fc.icustay_id = uo.icustay_id and uo.uo_std <> 0
  join temp t on fc.icustay_id = t.icustay_id and t.temp_std <> 0
)
select * from final;