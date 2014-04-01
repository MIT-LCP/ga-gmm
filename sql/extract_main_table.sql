create table mayaudlo.septicshock_cohort_details as
with demo  as (
select s.*,
       admission_type_descr, admission_source_descr, 
        case 
          when ethnicity_descr  like '%WHITE%' then 'White' 
          when ethnicity_descr like '%BLACK%' then 'Black'
          when ethnicity_descr like '%HISPANIC%' then 'Hispanic'
          when ethnicity_descr like '%ASIAN%' then 'Asian'
          else 'Other'
        end as Ethnicity
        
from  sepshock_angus2001 s,  -- main table
      mimic2v26.demographic_detail d
    
where s.hadm_id =  d.hadm_id (+) 

)

,icustay_details as (

select --s.subject_id, s.hadm_id, s.icustay_id,
      s.*,
       gender, hospital_expire_flg, icustay_expire_flg,  
       icustay_first_careunit first_careunit,
       sapsi_first, 
       trunc(extract( day from (d.icustay_intime - d.dob) )/365 , 2) age,
       trunc(extract( day from s.he_onset - d.icustay_intime )*24 + extract( hour from s.he_onset - d.icustay_intime ) + extract( minute from s.he_onset - d.icustay_intime )/60 , 2) onset_time_hr,
       trunc(extract( day from s.he_offset - s.he_onset )*24*60 + extract( hour from s.he_offset - s.he_onset )*60 + extract( minute from s.he_offset - s.he_onset ) , 2) he_length_min,
       trunc( -1 + extract( day from dod - s.he_offset ) + extract( hour from dod - s.he_offset )/24, 2) time_to_death_day,
       trunc(extract( day from d.icustay_intime - d.hospital_admit_dt ) + extract( hour from d.icustay_intime - d.hospital_admit_dt )/24, 2) pre_los_day
       
from  demo s,  -- main table
      mimic2v26.icustay_detail d
where s.icustay_id =  d.icustay_id (+)

)

, hepfail_  as (
select s.icustay_id,
       min( i.sequence )  as hepfail_sequence
      
from  icustay_details s,  -- main table
      mimic2v26.icd9 i

where s.hadm_id  = i.hadm_id (+)  
  and i.code like '570%'
  group by s.icustay_id
  
)
, hepfail as (

select s.*,
       h.hepfail_sequence
from  icustay_details s,  -- main table
      hepfail_ h
where s.icustay_id = h.icustay_id (+)      

)

,comorbid as (

select --s.subject_id, s.hadm_id, s.icustay_id,
      s.*,
      e.congestive_heart_failure ,
       e.cardiac_arrhythmias,
       e.valvular_disease,
       e.pulmonary_circulation,
       e.peripheral_vascular,
       e.hypertension,
       e.paralysis,
       e.other_neurological,
       e.chronic_pulmonary,
       e.diabetes_uncomplicated,
       e.diabetes_complicated,
       e.hypothyroidism,
       e.renal_failure,
       e.liver_disease,
       e.peptic_ulcer,
       e.aids,
       e.lymphoma,
       e.metastatic_cancer,
       e.solid_tumor,
       e.rheumatoid_arthritis,
       e.coagulopathy,
       e.obesity,
       e.weight_loss,
       e.fluid_electrolyte,
       e.blood_loss_anemia,
       e.deficiency_anemias,
       e.alcohol_abuse,
       e.drug_abuse,
       e.psychoses,
       e.depression
from  hepfail s,  -- main table
      mimic2v26.comorbidity_scores e
where s.hadm_id = e.hadm_id (+)

)


, RRT_ as (

select --s.subject_id, s.hadm_id,  
       s.icustay_id,
       1 as RRT_TEXT
from  comorbid s,  -- main table
      mimic2v26.noteevents n,
      mimic2v26.icustay_detail d
where s.icustay_id  = n.icustay_id
  and d.icustay_id (+) = s.icustay_id
  and charttime between d.icustay_intime and he_offset + interval '1' day
  and category = 'Nursing/Other'
  and (
    lower(text) like '% dialysis %' or
    lower(text) like '% hemodialysis %' or
    lower(text) like '% ihd %' or
    lower(text) like '% crrt %' or
    lower(text) like '% cvvh %' or
    lower(text) like '% cvvhd %' or
    lower(text) like '% esrd %' 
    )
)

,  RRT as (

select s.*,
       r.RRT_TEXT 
from RRT_ r,
     comorbid s
where r.icustay_id (+) = s.icustay_id  

)

select * from RRT


