with population as (
  select sc.subject_id,
    sc.hadm_id,
    id.icustay_id,
    id.gender,
    round(id.icustay_admit_age,3) age,
    id.icustay_intime, 
    round(id.icustay_los / 1400, 3) icustay_los_days,
    round(id.hospital_los / 1400, 3) hospital_los_days,
    id.icustay_expire_flg icu_exp_flg,
    id.hospital_expire_flg hosp_exp_flg,
    extract(day from id.dod - id.icustay_intime) survival_days,
    id.icustay_first_service careservice,
    id.weight_first weight,
    id.height,
    id.sapsi_first saps,
    id.sofa_first sofa
    
  from tbrennan.angus_sepsis_cohort sc
  join mimic2v26.icustay_detail id
    on sc.subject_id = id.subject_id 
    and sc.hadm_id = id.hadm_id
    
  where id.subject_icustay_seq = 1
)
--select * from population; -- icustay_id/subject_id 5156

, bmi as (
  select icustay_id,
    round(weight / power(height/100,2),2) bmi
    
    from population
)
--select * from bmi;

, demo as (
  select p.icustay_id,
       d.admission_type_descr, 
       d.admission_source_descr, 
        case 
          when ethnicity_descr  like '%WHITE%' then 'White' 
          when ethnicity_descr like '%BLACK%' then 'Black'
          when ethnicity_descr like '%HISPANIC%' then 'Hispanic'
          when ethnicity_descr like '%ASIAN%' then 'Asian'
          else 'Other'
        end as Ethnicity
        
  from  population p, 
        mimic2v26.demographic_detail d
    
  where p.hadm_id =  d.hadm_id (+) 
)
--select * from demo;

, comorbid as (

  select --s.subject_id, s.hadm_id, s.icustay_id,
       p.subject_id,
       p.hadm_id,
       p.icustay_id,
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
  from  population p,  -- main table
      mimic2v26.comorbidity_scores e
  where p.hadm_id = e.hadm_id (+)

)
--select * from comorbid;

, therapy as (
  select p.subject_id,
        p.hadm_id,
        p.icustay_id, 
        case when v.seq = 1 then 1 
          else 0 
        end as ventilated,
        case when rc.rrt = 1 then 1 
          else 0 
        end as rrt,
        case when m.dose <> 0 then 1
          else 0
        end as vasopressor  
    from population p
    left join mimic2devel.ventilation v on v.icustay_id = p.icustay_id
    left join tbrennan.rrt_cohort rc on rc.icustay_id = p.icustay_id
    left join mimic2v26.medevents m
         on m.icustay_id = p.icustay_id 
         and m.itemid in (42, 43, 44, 47, 51, 119, 120, 125, 127, 128)
)
--select * from therapy; -- rows 2632

, final_therapy as (
  select distinct subject_id,
      hadm_id,
      icustay_id,
      first_value(rrt) over (partition by icustay_id order by rrt desc) rrt,
      first_value(ventilated) over (partition by icustay_id order by ventilated desc) ventilated,
      first_value(vasopressors) over (partition by icustay_id order by vasopressors desc) vasopressor,
    from therapy
)
select * from final_therapy; -- rows 2632

, therapy_final as (
  select distinct cd.icustay_id, 
      m.itemid,
      m.charttime,
      round(m.dose,2) dose,
      m.doseuom
    from tbrennan.echo_cohort cd 
    join mimic2v26.medevents m
         on cd.icustay_id = m.icustay_id 
         and m.itemid in (42, 43, 44, 47, 51, 119, 120, 125, 127, 128) 
         and m.dose<>0
)
--select count(icustay_id) from pressors; -- 848 rows


, pressor_start as (
  select distinct icustay_id, itemid,
    first_value(charttime) over (partition by icustay_id, itemid order by charttime) start_time
    from pressors
)
--select * from pressor_start;

, pressor_end as (
  select distinct icustay_id, itemid,
    first_value(charttime) over (partition by icustay_id, itemid order by charttime desc) end_time
    from pressors
)
--select * from pressor_end;

, pressor_therapy as (
  select distinct p.icustay_id, 
    p.itemid,
    p.dose,
    ps.start_time,
    pe.end_time,
    extract(day from pe.end_time - ps.start_time)*1440 + 
      extract(hour from pe.end_time - ps.start_time)*60 + 
        extract(minute from pe.end_time - ps.start_time) duration,
    case when ec.echo_time > ps.start_time and 
              ec.echo_time < pe.end_time
        then 1 else 0
        end as echo_on_pressors
    from pressors p 
    join echo_cohort ec on p.icustay_id = ec.icustay_id
    join pressor_start ps on p.icustay_id = ps.icustay_id and p.itemid = ps.itemid
    join pressor_end pe on p.icustay_id = pe.icustay_id and p.itemid = pe.itemid
    order by p.icustay_id, ps.start_time
)
--select count(icustay_id) from pressor_therapy;


