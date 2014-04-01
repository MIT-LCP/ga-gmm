-- Variables used in SAPS from mimic2v26
-- Li Lehman (lilehman@mit.edu)

--creatinine
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50090)
  AND valuenum BETWEEN 0 AND 30
  AND valuenum IS NOT NULL
  order by subject_id, charttime
  

--pH
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50018)
  AND valuenum IS NOT NULL
  order by subject_id, charttime
  
  

--lactate in blood, blood gas, LOINC_CODE 32693-4 [Moles/volume]
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50010)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  
  
  
--pco2 in blood, blood gas, LOINC_CODE 11557-6 Carbon dioxide [Partial pressure] in Blood
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50016)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  



-- hematocrit (50383)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50383)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  


-- wbc  (50316, 50468)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50316, 50468)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  

-- glucose (50006, 50112)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50006, 50112)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  

-- potassium(50009, 50149)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50009, 50149)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  

-- sodium (50012, 50159)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50012, 50159)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  

-- hco3(50022, 50025, 50172)
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in (50022, 50025, 50172)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  

-- BUN (50177) labevents
select subject_id, hadm_id, icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, valuenum from mimic2v26.labevents
where itemid in  (50177)
  AND valuenum IS NOT NULL
  order by subject_id, charttime  



---------------------------CHARTEVENTS----------------------  
--hr (676, 677, 678, 679)
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in (676, 677, 678, 679)
  AND value1num IS NOT NULL
  order by subject_id, charttime
  
  

--abpmean
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in (52)
  AND value1num BETWEEN 0 AND 300
  AND value1num IS NOT NULL
  order by subject_id, charttime
  
  

--abpsys
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in (51)
  AND value1num IS NOT NULL
  order by subject_id, charttime
  

--temp(676, 677, 678, 679)
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in (676, 677, 678, 679)
  AND value1num IS NOT NULL
  order by subject_id, charttime
  
--Glasgow Coma Score
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in  (198) --GCS total
  AND value1num IS NOT NULL
  order by subject_id, charttime




-- ventilated resp 

select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, value1num from mimic2v26.chartevents
where itemid in  (543, 544, 545, 619, 39, 535, 683, 720, 721, 722, 732)
  AND value1num IS NOT NULL
  order by subject_id, charttime
  
-- extract ventilated resp as -1 
WITH all_icustay_days AS
  (SELECT icud.subject_id,
    icud.hadm_id,
    icud.icustay_id,
    idays.seq,
    idays.begintime,
    idays.endtime
  FROM mimic2v26.icustay_detail icud
  JOIN mimic2v26.icustay_days idays
  ON icud.icustay_id          =idays.icustay_id
  WHERE icud.icustay_age_group='adult'
  AND icud.icustay_los        > 3*24*60
  AND idays.seq              <= 3
    --     and icud.subject_id < 100
  )
  --select * from all_icustay_days;
  ,
  pivot_begintime AS
  (SELECT *
  FROM
    (SELECT subject_id, hadm_id, icustay_id, seq, begintime FROM all_icustay_days
    ) pivot (MIN(begintime) FOR seq IN ('1' AS begintime_day1, '2' AS begintime_day2, '3' AS begintime_day3))
  )
  --select * from pivot_begintime;
  ,
  pivot_endtime AS
  (SELECT *
  FROM
    (SELECT subject_id, hadm_id, icustay_id, seq, endtime FROM all_icustay_days
    ) pivot (MIN(endtime) FOR seq IN ('1' AS endtime_day1, '2' AS endtime_day2, '3' AS endtime_day3))
  )  --select * from pivot_endtime;
,icustay_days_in_columns AS
  (SELECT b.subject_id,
    b.hadm_id,
    b.icustay_id,
    b.begintime_day1,
    e.endtime_day1,
    b.begintime_day2,
    e.endtime_day2,
    b.begintime_day3,
    e.endtime_day3
  FROM pivot_begintime b
  JOIN pivot_endtime e
  ON b.icustay_id=e.icustay_id
  ),
 VentilatedRespParams AS
  (SELECT s.subject_id,
    s.hadm_id,
    s.icustay_id,
    CASE
      WHEN c.charttime BETWEEN s.begintime_day1 AND s.endtime_day1
      THEN 'VENTILATED_RESP_day1'
      WHEN c.charttime BETWEEN s.begintime_day2 AND s.endtime_day2
      THEN 'VENTILATED_RESP_day2'
      WHEN c.charttime BETWEEN s.begintime_day3 AND s.endtime_day3
      THEN 'VENTILATED_RESP_day3'
    END AS category,
    -1  AS valuenum -- force invalid number
  FROM icustay_days_in_columns s
  JOIN mimic2v26.chartevents c
  ON s.icustay_id=c.icustay_id
  WHERE c.charttime BETWEEN s.begintime_day1 AND s.endtime_day3
  AND c.itemid IN (543, 544, 545, 619, 39, 535, 683, 720, 721, 722, 732)
 ) select * from VentilatedRespParams;
 






----------------------IOEVENTS--------------------------------
-- urine output, volume in ml
select subject_id,  icustay_id,  to_char(CHARTTIME, 'yyyy-mm-dd HH24:MI:SS') CHARTTIME, volume from mimic2v26.ioevents
where itemid in ( 651, 715, 55, 56, 57, 61, 65, 69, 85, 94, 96, 288, 405, 428, 473, 2042, 2068, 2111, 2119, 2130, 1922, 2810, 2859, 3053, 3462, 3519, 3175, 2366, 2463, 2507, 2510, 2592, 2676, 3966, 3987, 4132, 4253, 5927 )
  AND volume IS NOT NULL
  order by subject_id, charttime

--======================================================================


-- resp rate

-- ventilation or cpap

-- urine output



--gcs
   












-- =====================================  
select * from mimic2v26.d_labitems
where lower(loinc_description) like '%lactate%'


select * from mimic2v26.d_labitems
where lower(loinc_description) like '%paco%'

 select * from mimic2v26.d_labitems
where lower(test_name) like '%co%'
and lower(fluid) like '%blood%'

