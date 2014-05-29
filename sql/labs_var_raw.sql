drop materialized view mimic2v26_labs_raw_48hr;
create materialized view mimic2v26_labs_raw_48hr as

with labs_raw as (
  select s.subject_id, 
          s.hadm_id,
          s.icustay_id,
          extract(day from c.charttime - s.icustay_intime)*1440 + 
            extract(hour from c.charttime - s.icustay_intime)*60 + 
            extract(minute from c.charttime - s.icustay_intime) 
          as post_adm,
          case
            when c.itemid in (50383,50029)
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'HCT'
            when c.itemid in (51326,50468,50316) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'WBC'
            when c.itemid in (50112,50936,50006) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'GLUCOSE'  
            when c.itemid in (50803,50022,50172,50025) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'HCO3'
            when c.itemid in (50009,50821,50976,50149)  
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'POTASSIUM'
            when c.itemid in (50989,50823,50159,50012) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'SODIUM'
            when c.itemid in (51011,50177) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'BUN'
            when c.itemid in (50090,50916) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'CREATININE'
            when c.itemid in (50386,50007,50184) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'HGB'
            when c.itemid in (50428) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'PLATELETS'
            when c.itemid in (50083,50004) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'CHLORIDE'
            when c.itemid in (50010) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'LACTATE'
            when c.itemid in (50018) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'PH'
            when c.itemid in (50019) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'PO2'
            when c.itemid in (664,838) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'SVO2'
            when c.itemid in (50195) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'BNP'
            when c.itemid in (50189) 
              and extract(day from c.charttime - s.icustay_intime) < 3 then 'TROPONIN'
          end as category,
          valuenum
   from tbrennan.mimic2v26_48hr_vital_signs s
   join mimic2v26.labevents c on s.icustay_id = c.icustay_id
   where extract(day from c.charttime - s.icustay_intime) < 3
   and ((c.itemid in (50383,50029) -- 'HCT'
          and c.valuenum between 5 and 100) -- 0 <> 390
        or (c.itemid in (51326,50468,50316) -- 'WBC'
          and c.valuenum*1000 between 5 and 2000000) -- 0 <> 1,250,000
        or (c.itemid in (50112,50936,50006)-- 'GLUCOSE'  
          and c.valuenum between 0.5 and 1000) -- -251 <> 3555
        or (c.itemid in (50803,50022,50172,50025)--'HCO3'
          and c.valuenum between 2 and 100) -- 0 <> 231
        or (c.itemid in (50009,50821,50976,50149)-- 'POTASSIUM'
          and c.valuenum between 0.5 and 70) -- 0.7	<> 52
        or (c.itemid in (50989,50823,50159,50012)-- 'SODIUM'
          and c.valuenum between 50 and 300) -- 1.07 <>	1332
        or (c.itemid in (51011,50177) -- 'BUN'
          and c.valuenum between 1 and 100) -- 0 <> 280
        or (c.itemid in (50090,50916) -- 'CREATININE'
          and c.valuenum between 0 and 30) -- 0	<> 73
        or (c.itemid in (50386,50007,50184) -- 'HEMOGLOBIN'
          and c.valuenum between 5 and 30) -- 
        or (c.itemid in (50428) -- 'PLATELETS'
          and c.valuenum between 50 and 600) -- 
        or (c.itemid in (50083,50004) -- 'CHLORIDE'
          and c.valuenum between 50 and 200) -- 
        or (c.itemid in (50010) -- 'LACTATE'
          and c.valuenum between 0 and 10) -- 
        or (c.itemid in (50018) -- 'PH'
          and c.valuenum between 7 and 8) -- 
        or (c.itemid in (50019) -- 'PO2'
          and c.valuenum between 50 and 150) -- 
        or (c.itemid in (664,838) -- 'SVO2'
          and c.valuenum between 50 and 100) -- 
        or (c.itemid in (50195) -- 'BNP'
          and c.valuenum between 0 and 150) -- 
        or (c.itemid in (50189) -- 'TROPONIN'
          and c.valuenum between 0 and 50) -- 
        )
     and c.valuenum is not null
  order by subject_id, icustay_id, category
)
select * from labs_raw;



