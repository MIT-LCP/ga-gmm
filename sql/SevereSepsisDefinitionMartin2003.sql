create table "MAYAUDLO".SevereSepsisIDMartin2003 as
with organFailurePopulation as (
SELECT   distinct h.hadm_id,
         h.subject_ID
  FROM mimic2v26.admissions h, 
       mimic2v26.ICD9 code
  WHERE code.SUBJECT_ID = h.SUBJECT_ID 
  and (      code.CODE = '518.81' -- Acute respiratory failure
      or code.CODE = '518.82' -- Acute respiratory distress syndrome'
      or code.CODE = '518.85' -- Acute respiratory distress syndrome after shock or trauma
      or code.CODE = '786.09' -- Respiratory insufficiency
      or code.CODE like '799.1%' -- Respiratory arrest
      or code.CODE like '96.7%' -- Ventilator management
      or code.CODE like '458.0%' -- Hypotension, postural
      or code.CODE like '785.5%' -- Shock
      or code.CODE = '785.51' -- Shock, cardiogenic
      or code.CODE = '785.59' -- Shock, circulatory or septic
      or code.CODE like '458.0%' -- Hypotension, postural
      or code.CODE like '458.8%' -- Hypotension, specified type, not elsewhere classified
      or code.CODE like '458.9%' -- Hypotension, arterial, constitutional
      or code.CODE like '796.3%' -- Hypotension, transient
      or code.CODE like '584%' -- Acute renal failure
      or code.CODE like '580%' -- Acute glomerulonephritis
      or code.CODE like '585%' -- Renal shutdown, unspecified
      or code.CODE = '39.95%' -- 
      or code.CODE like '570%' -- Acute hepatic failure or necrosis
      or code.CODE like '572.2%' -- Hepatic encephalopathy
      or code.CODE like '573.3%' -- Hepatitis, septic or unspecified
      or code.CODE like '286.2%' -- Disseminated intravascular coagulation
      or code.CODE like '286.6%' -- Purpura fulminans
      or code.CODE like '286.9%' -- Coagulopathy
      or code.CODE like '287.3%' -- Thrombocytopenia, primary, secondary, or unspecified
      or code.CODE like '287.4%'
      or code.CODE like '287.5%'
      or code.CODE like '276.2%' -- Acidosis, metabolic or lactic
      or code.CODE like '293%' -- Transient organic psychosis
      or code.CODE like '348.1%' -- Anoxic brain injury
      or code.CODE like '348.3%' -- Encephalopathy, acute
      or code.CODE = '780.01' -- Coma
      or code.CODE = '780.09' -- Altered consciousness, unspecified
      or code.CODE = '89.14' -- Electroencephalography
    )
),
infectionPopulation as (      
SELECT   distinct h.hadm_id,
          h.subject_ID
  FROM mimic2v26.admissions h, 
       mimic2v26.ICD9 code
  WHERE code.SUBJECT_ID = h.SUBJECT_ID     
    AND (
    code.CODE like  '038%'  -- septicemia
    or code.CODE like '020.0%'  --septicemic
    or code.CODE like '790.7%'  -- (bacteremia)
    or code.CODE like '117.9%'  -- (disseminated fungal infection), 
    or code.CODE like '112.5%'  -- (disseminated candida infection), 
    or code.CODE = '112.81%' -- (disseminated fungal endocarditis)
    )
)
, organFailurePopulationProc as (
SELECT   distinct h.hadm_id,
          h.subject_ID    
  FROM infectionPopulation h, 
       mimic2v26.procedureevents proc
  WHERE proc.SUBJECT_ID = h.SUBJECT_ID 
  and (  proc.itemid = '101781' --Respiratory Mechanical ventilation
        or proc.itemid = '101782' --Respiratory Mechanical ventilation
        or proc.itemid = '101783' --Respiratory Mechanical ventilation
      or proc.itemid = '100622' -- Hemodialysis
      or proc.itemid = '101174' -- Electroencephalography
    )
)

--  select distinct itemid
--    from mimic2v26.d_codeditems
--    where code like '8914%'
--        or code like '967%'
--        or code like '3995%'
--    and type = 'PROCEDURE'

select *
from organFailurePopulationProc

;
select distinct ip.hadm_id,
        ip.subject_id
  from  organFailurePopulation oFp, 
        --organFailurePopulationProc oFpProc, 
        infectionPopulation ip
  where  oFp.hadm_id = ip.hadm_id
      --or oFpProc.hadm_id = ip.hadm_id


